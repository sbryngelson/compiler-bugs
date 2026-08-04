#!/usr/bin/env python3
"""Metamorphic OpenMP offload probes, sentinel-initialised.

Same idea as gen_meta.py: compute the same result two ways inside one target
region and let the program compare them. No external oracle.

The difference, and the whole point of this rewrite: gen_meta.py initialised
BOTH result arrays to 0.0d0. If the compiler drops an iteration, neither r1 nor
r2 is written, they are both still 0, and they compare equal. That harness was
structurally blind to skipped iterations -- which is llvm#198621, the exact bug
class it was built to find. 150/150 "passed" and proved nothing about it.

Here r1 and r2 start at DIFFERENT sentinels, so an unwritten element cannot
compare equal. Written-ness is also checked directly, so a skipped iteration is
reported as such rather than as a value mismatch.

Each relation declares how many columns it actually writes; checking columns a
relation never touches would flag sentinels that are supposed to still be there.
"""
import os, itertools

OUT = os.path.dirname(os.path.abspath(__file__)) + "/src2"
os.makedirs(OUT, exist_ok=True)

S1 = "-1.0d30"
S2 = "-2.0d30"

# (name, form A, form B, columns written)
RELS = [
    ("arr_vs_loop",
     "r1(i,1:4) = a(i)*c(1:4)",
     "do jj=1,4\n           r2(i,jj) = a(i)*c(jj)\n         end do", 4),
    ("ctor_vs_loop",
     "r1(i,1:4) = [a(i), a(i), a(i), a(i)]",
     "do jj=1,4\n           r2(i,jj) = a(i)\n         end do", 4),
    ("where_vs_if",
     "where (c(1:4) > 0.5d0) r1(i,1:4) = a(i)",
     "do jj=1,4\n           if (c(jj) > 0.5d0) r2(i,jj) = a(i)\n         end do", 4),
    ("sum_vs_loop",
     "r1(i,1) = sum(c(1:4))*a(i)",
     "r2(i,1) = 0.0d0\n         do jj=1,4\n           r2(i,1) = r2(i,1) + c(jj)*a(i)\n         end do", 1),
    ("slice_vs_elem",
     "r1(i,1:4) = c(1:4) + a(i)",
     "do jj=1,4\n           r2(i,jj) = c(jj) + a(i)\n         end do", 4),
    # matmul/transpose and reshape exercise different lowering paths than plain
    # elementwise slices; both go through _FortranA* runtime entry points on
    # device, which is where the no-loop miscount bit.
    ("dot_vs_loop",
     "r1(i,1) = dot_product(c(1:4), c(1:4))*a(i)",
     "r2(i,1) = 0.0d0\n         do jj=1,4\n           r2(i,1) = r2(i,1) + c(jj)*c(jj)*a(i)\n         end do", 1),
    ("maxval_vs_loop",
     "r1(i,1) = maxval(c(1:4))*a(i)",
     "r2(i,1) = c(1)*a(i)\n         do jj=2,4\n           if (c(jj)*a(i) > r2(i,1)) r2(i,1) = c(jj)*a(i)\n         end do", 1),
]

CONSTRUCTS = [
    ("ttdpd", "target teams distribute parallel do"),
    ("tpd",   "target parallel do"),
    ("ttd",   "target teams distribute"),
]

# Sizes straddle wave (32/64) and team boundaries. The known no-loop miscount is
# zero below ~33 at wave 32, so a single N hides it.
NS = [31, 32, 33, 63, 64, 65, 127, 128, 129, 257, 1023, 1025]

n = 0
for (rn, fa, fb, ncol), (kn, con), N in itertools.product(RELS, CONSTRUCTS, NS):
    name = f"m2_{rn}_{kn}_n{N}"
    src = f"""! metamorphic (sentinel-init): {rn} under {con}, N={N}
! r1/r2 start at DIFFERENT sentinels so a skipped iteration cannot pass.
program {name}
  implicit none
  integer, parameter :: n = {N}
  integer, parameter :: nc = {ncol}
  real(8), parameter :: s1 = {S1}, s2 = {S2}
  real(8) :: a(n), c(4), r1(n,4), r2(n,4)
  integer :: i, jj, nbad, nunwr, firstbad, firstunwr
  do i = 1, n
     a(i) = real(i,8)
  end do
  c = 1.0d0
  r1 = s1
  r2 = s2
  !$omp {con} map(to:a,c) map(tofrom:r1,r2) private(jj)
  do i = 1, n
         {fa}
         {fb}
  end do
  nbad = 0; nunwr = 0; firstbad = -1; firstunwr = -1
  do i = 1, n
     do jj = 1, nc
        if (r1(i,jj) == s1 .or. r2(i,jj) == s2) then
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
  end if
end program
"""
    open(f"{OUT}/{name}.f90", "w").write(src)
    n += 1

print(f"generated {n} sentinel probes "
      f"({len(RELS)} relations x {len(CONSTRUCTS)} constructs x {len(NS)} sizes)")
