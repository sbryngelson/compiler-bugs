#!/usr/bin/env python3
"""Metamorphic OpenMP offload probes, round 3: realistic kernel shapes.

Round 2 (gen_meta2.py) validated the sentinel design and re-found llvm#198621
exactly, but its relations were all single-level loops over elementwise slices.
This round targets the lowering features a finite-volume solver actually uses --
collapse, reductions, private/firstprivate arrays, nested parallel, simd,
allocatables, derived types, atomics -- because that is where remaining codegen
bugs would bite.

Design rules carried over:
  * Two spellings of the same computation inside ONE target region; the program
    compares them itself. No external oracle.
  * r1 and r2 start at DIFFERENT sentinels, so a dropped iteration cannot pass
    unnoticed. Round 1 initialised both to zero and was structurally blind to
    exactly that.
  * Report unwritten and mismatch separately: skipped iterations and wrong
    arithmetic are different bugs.

Conformance notes (these matter -- non-conforming probes produce fake bugs):
  * every array in a map clause has explicit shape, never assumed-size
  * collapse() loops are perfectly nested with loop-invariant bounds
  * reduction variables are initialised before the region and not also private
  * atomic update operates on a scalar with a conforming operator form
"""
import os

OUT = os.path.dirname(os.path.abspath(__file__)) + "/src3"
os.makedirs(OUT, exist_ok=True)

S1, S2 = "-1.0d30", "-2.0d30"
NS = [33, 64, 65, 127, 128, 257]

PROBES = []


def add(name, body, decls="", extra="", check="scalar", nx=None):
    PROBES.append((name, body, decls, extra, check, nx))


# --- collapse: index linearisation in lowering -------------------------------
for cl in (2, 3):
    idx = "i,j" if cl == 2 else "i,j,k"
    loops_a = ("do i = 1, n\n     do j = 1, 4\n" if cl == 2 else
               "do i = 1, n\n     do j = 1, 4\n       do k = 1, 2\n")
    ends_a = "     end do\n  end do" if cl == 2 else "       end do\n     end do\n  end do"
    expr = "real(i,8)*10.0d0 + real(j,8)" + ("" if cl == 2 else " + real(k,8)*0.5d0")
    tgt = "r1(i,j)" if cl == 2 else "r1(i,j)"
    acc = ("" if cl == 2 else "")
    # form A: collapse(cl). form B: plain nest, same arithmetic.
    add(f"collapse{cl}",
        f"""  !$omp target teams distribute parallel do collapse({cl}) map(to:a) map(tofrom:r1)
  {loops_a}       r1(i,j) = {expr}
{ends_a}
  !$omp end target teams distribute parallel do
  !$omp target teams distribute parallel do private(j,k) map(to:a) map(tofrom:r2)
  do i = 1, n
     do j = 1, 4
       {'do k = 1, 2' if cl==3 else ''}
        r2(i,j) = {expr}
       {'end do' if cl==3 else ''}
     end do
  end do
  !$omp end target teams distribute parallel do""",
        decls="  integer :: j, k\n", check="grid")

# --- reductions --------------------------------------------------------------
for op, ini, seq in (("+", "0.0d0", "s2 = s2 + a(i)"),
                     ("max", "-1.0d30", "if (a(i) > s2) s2 = a(i)"),
                     ("min", "1.0d30", "if (a(i) < s2) s2 = a(i)")):
    tag = {"+": "sum", "max": "max", "min": "min"}[op]
    add(f"reduce_{tag}",
        f"""  s1 = {ini}
  !$omp target teams distribute parallel do reduction({op}:s1) map(to:a) map(tofrom:s1)
  do i = 1, n
     {'s1 = s1 + a(i)' if op=='+' else ('if (a(i) > s1) s1 = a(i)' if op=='max' else 'if (a(i) < s1) s1 = a(i)')}
  end do
  !$omp end target teams distribute parallel do
  s2 = {ini}
  do i = 1, n
     {seq}
  end do""",
        decls="  real(8) :: s1, s2\n", check="reduce")

# --- private / firstprivate arrays inside the kernel -------------------------
add("private_array",
    """  !$omp target teams distribute parallel do private(t,jj) map(to:a) map(tofrom:r1)
  do i = 1, n
     do jj = 1, 4
        t(jj) = a(i) * real(jj,8)
     end do
     r1(i,1) = t(1) + t(2) + t(3) + t(4)
  end do
  !$omp end target teams distribute parallel do
  !$omp target teams distribute parallel do map(to:a) map(tofrom:r2)
  do i = 1, n
     r2(i,1) = a(i)*1.0d0 + a(i)*2.0d0 + a(i)*3.0d0 + a(i)*4.0d0
  end do
  !$omp end target teams distribute parallel do""",
    decls="  real(8) :: t(4)\n", check="col1")

add("firstprivate_array",
    """  fp = 2.0d0
  !$omp target teams distribute parallel do firstprivate(fp) map(to:a) map(tofrom:r1)
  do i = 1, n
     r1(i,1) = a(i) * (fp(1) + fp(2) + fp(3) + fp(4))
  end do
  !$omp end target teams distribute parallel do
  !$omp target teams distribute parallel do map(to:a) map(tofrom:r2)
  do i = 1, n
     r2(i,1) = a(i) * 8.0d0
  end do
  !$omp end target teams distribute parallel do""",
    decls="  real(8) :: fp(4)\n", check="col1")

# --- nested parallel inside teams (the MayUseNestedParallelism path) ---------
add("teams_then_parallel",
    """  !$omp target teams distribute map(to:a) map(tofrom:r1)
  do i = 1, n
     !$omp parallel do
     do jj = 1, 4
        r1(i,jj) = a(i) * real(jj,8)
     end do
  end do
  !$omp end target teams distribute
  !$omp target teams distribute parallel do private(jj) map(to:a) map(tofrom:r2)
  do i = 1, n
     do jj = 1, 4
        r2(i,jj) = a(i) * real(jj,8)
     end do
  end do
  !$omp end target teams distribute parallel do""",
    check="grid4")

# --- simd -------------------------------------------------------------------
add("simd_vs_plain",
    """  !$omp target teams distribute parallel do simd map(to:a) map(tofrom:r1)
  do i = 1, n
     r1(i,1) = a(i)*a(i) + 1.0d0
  end do
  !$omp end target teams distribute parallel do simd
  !$omp target teams distribute parallel do map(to:a) map(tofrom:r2)
  do i = 1, n
     r2(i,1) = a(i)*a(i) + 1.0d0
  end do
  !$omp end target teams distribute parallel do""",
    check="col1")

# --- allocatable ------------------------------------------------------------
add("allocatable",
    """  allocate(a2(n))
  a2 = a
  !$omp target teams distribute parallel do map(to:a2) map(tofrom:r1)
  do i = 1, n
     r1(i,1) = a2(i) * 3.0d0
  end do
  !$omp end target teams distribute parallel do
  !$omp target teams distribute parallel do map(to:a) map(tofrom:r2)
  do i = 1, n
     r2(i,1) = a(i) * 3.0d0
  end do
  !$omp end target teams distribute parallel do
  deallocate(a2)""",
    decls="  real(8), allocatable :: a2(:)\n", check="col1")

# --- atomic -----------------------------------------------------------------
add("atomic_vs_reduction",
    """  s1 = 0.0d0
  !$omp target teams distribute parallel do map(to:a) map(tofrom:s1)
  do i = 1, n
     !$omp atomic update
     s1 = s1 + a(i)
  end do
  !$omp end target teams distribute parallel do
  s2 = 0.0d0
  do i = 1, n
     s2 = s2 + a(i)
  end do""",
    decls="  real(8) :: s1, s2\n", check="reduce")

# --- complex arithmetic -----------------------------------------------------
add("complex_mul",
    """  !$omp target teams distribute parallel do private(zc) map(to:a) map(tofrom:r1)
  do i = 1, n
     zc = cmplx(a(i), 1.0d0, kind=8) * cmplx(2.0d0, 3.0d0, kind=8)
     r1(i,1) = real(zc) + aimag(zc)
  end do
  !$omp end target teams distribute parallel do
  !$omp target teams distribute parallel do map(to:a) map(tofrom:r2)
  do i = 1, n
     r2(i,1) = (a(i)*2.0d0 - 3.0d0) + (a(i)*3.0d0 + 2.0d0)
  end do
  !$omp end target teams distribute parallel do""",
    decls="  complex(8) :: zc\n", extra="private(zc)", check="col1")

CHECK = {
    "col1":   ("1", "1"),
    "grid":   ("4", "1"),
    "grid4":  ("4", "1"),
}

n = 0
for (name, body, decls, extra, check, _nx) in PROBES:
    for N in NS:
        pname = f"m3_{name}_n{N}"
        if check == "reduce":
            verify = """  if (abs(s1-s2) <= 1.0d-9*max(1.0d0,abs(s2))) then
     print *, "PASS"
  else
     print '(A,I6,A,ES14.6,A,ES14.6)', "FAIL n=", n, " dev=", s1, " host=", s2
  end if"""
            arrays = ""
        else:
            ncol = "4" if check in ("grid", "grid4") else "1"
            verify = f"""  nbad = 0; nunwr = 0; firstbad = -1; firstunwr = -1
  do i = 1, n
     do jj = 1, {ncol}
        if (r1(i,jj) == s1v .or. r2(i,jj) == s2v) then
           nunwr = nunwr + 1
           if (firstunwr < 0) firstunwr = i
        else if (abs(r1(i,jj)-r2(i,jj)) > 1.0d-12) then
           nbad = nbad + 1
           if (firstbad < 0) firstbad = i
        end if
     end do
  end do
  if (nbad == 0 .and. nunwr == 0) then
     print *, "PASS"
  else
     print '(A,I6,A,I7,A,I7,A,I6,A,I6)', "FAIL n=", n, &
        " unwritten=", nunwr, " mismatch=", nbad, &
        " first_unwr=", firstunwr, " first_bad=", firstbad
  end if"""
            arrays = f"""  real(8), parameter :: s1v = {S1}, s2v = {S2}
  real(8) :: r1(n,4), r2(n,4)
"""
        src = f"""! metamorphic round 3: {name}, N={N}
program m3_{name}_n{N}
  implicit none
  integer, parameter :: n = {N}
  real(8) :: a(n)
{arrays}{decls}  integer :: i, jj, nbad, nunwr, firstbad, firstunwr
  do i = 1, n
     a(i) = real(i,8)
  end do
{'  r1 = s1v' + chr(10) + '  r2 = s2v' if arrays else ''}
{body}
{verify}
end program
"""
        open(f"{OUT}/{pname}.f90", "w").write(src)
        n += 1

print(f"generated {n} round-3 probes ({len(PROBES)} shapes x {len(NS)} sizes)")
