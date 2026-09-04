# Vendor report — ready to paste into an OLCF ticket

Send to `help@olcf.ornl.gov`; OLCF opens the HPE/Cray case. Everything below is
self-contained: the reproducer is inline, so no attachment or repo access is needed.

---

**Subject:** CCE Fortran: silent wrong answers — an `!$acc loop` inside an `!$acc routine`
corrupts array-element actual arguments (CCE 19.0.0 through 21.0.2, gfx90a)

## Summary

An `!$acc routine` that contains an `!$acc loop` mis-passes any **array element** given to
it as an actual argument. An `intent(in)` element arrives as garbage (result NaN); an
`intent(out)` element is never written (the array keeps its previous contents). There is
no diagnostic and no crash — the program runs and prints wrong numbers.

Wrong at `-O2` and `-O3`; correct at `-O0` and `-O1`.

## Severity

Silent miscompilation producing wrong numerical results in conforming code. This cost the
MFC CFD solver (<https://github.com/MFlowCode/MFC>) an entire release's worth of
regression tests on the Frontier CCE OpenACC lanes: every test on the new equation-of-state
paths ended in `NaN(s) in timestep output`, with no compiler message pointing anywhere near
the cause.

## Environment

```
System            OLCF Frontier (confirmed on both an MI250X compute node and an
                  MI210 login node -- same gfx90a target, identical results)
OS                SUSE Linux Enterprise Server 15 SP7
Compiler          Cray Fortran 21.0.2 (20260604162910_c3fb8a56d0f4e468a9d0387a93105d6911ac9420)
Modules           cpe/26.03, cce/21.0.2, rocm/7.2.0, craype-accel-amd-gfx90a
CRAY_ACCEL_TARGET amd_gfx90a
Target banner     x86-64 : x86-trento : none : amdgcn-gfx90a
Build             ftn -hacc -O2 element_out.f90 -o element_out
```

## Reproducer

```fortran
module m_out
  implicit none
  integer, parameter :: wp = kind(1.0d0)
  real(wp), allocatable :: b(:)
  !$acc declare create(b)
contains
  subroutine inner(x, y)
    !$acc routine seq
    real(wp), intent(in)  :: x
    real(wp), intent(out) :: y
    integer :: it
    y = x
    !$acc loop seq            ! <=== remove this one line and the program is correct
    do it = 1, 8
      y = y + 1.0_wp
    end do
  end subroutine
end module

program element_out
  use m_out
  implicit none
  integer, parameter :: n = 299
  integer :: k, bad
  allocate(b(0:n)); b = 0.0_wp
  !$acc update device(b)
  !$acc parallel loop
  do k = 0, n
    call inner(real(k, wp), b(k))        ! array element as the intent(out) actual arg
  end do
  !$acc update host(b)
  bad = count(b /= [(real(k, wp) + 8.0_wp, k = 0, n)])
  print '(a,i0,a,i0,a,es13.6,a,es13.6)', 'bad ', bad, ' of ', n + 1, &
        '   got ', b(0), '   expected ', 8.0_wp
end program
```

**Expected:** `bad 0 of 300   got  8.000000E+00   expected  8.000000E+00`
**Actual:** `bad 300 of 300   got  0.000000E+00   expected  8.000000E+00`

The callee's store to its `intent(out)` dummy is discarded for every element.

## Two ingredients, both required

| `!$acc loop` inside the routine | actual argument | result |
|---|---|---|
| yes (`loop` or `loop seq`) | array element | **wrong** |
| yes | scalar | correct |
| no | array element | correct |
| no | scalar | correct |

Removing either one gives exact results.

## This is not a case of invalid input

An `!$acc loop` inside a `routine seq` is arguably meaningless, since a `seq` routine
generates no parallelism — so the reproducer above could be dismissed. This one cannot:

```fortran
subroutine inner(x, y)
  !$acc routine vector
  ...
  !$acc loop vector          ! conforming, and still miscompiled
  do it = 1, 8
```

called from an `!$acc parallel loop gang`. That is textbook conforming OpenACC, and it
fails identically. **All four routine levels are affected — `seq`, `vector`, `worker`,
`gang`.**

Either way the compiler is wrong: where the inner directive is meaningless it should be
diagnosed or ignored; where it is meaningful it must work. Today it is silently accepted
and then miscompiled.

## Mechanism — where it goes wrong

`-hlist=a` on the two builds isolates it to three decisions. The only source difference is
the one directive.

**Wrong:**

```
ftn-6430 ACCEL, Line 39   A loop starting at line 39 was partitioned across the
                          threadblocks AND the 256 threads within a threadblock.
ftn-3001 IPA,   Line 40   Leaf "inner"(element_out.f90:18) was inlined.
ftn-6002 SCALAR,Line 40   A loop starting at line 40 was eliminated by optimization.
```

**Correct (same file, directive deleted):**

```
ftn-6430 ACCEL, Line 30   A loop starting at line 30 was partitioned across the
                          thread blocks.                        <- gang only
ftn-3001 IPA,   Line 31   Leaf "inner"(control_no_loop.f90:10) was inlined.
ftn-6430 ACCEL, Line 31   A loop starting at line 31 was partitioned across the
                          256 threads within a threadblock.     <- vector to the callee's loop
```

The sequence:

1. The `!$acc loop` inside the routine changes how the **outer** `parallel loop` is
   partitioned — gang *and* vector, rather than gang only with the vector level given to
   the inlined callee's own loop.
2. `inner` is inlined into that kernel. This also happens **across separate compilations**
   (`Leaf "inner"(mod.f90:18) was inlined`).
3. The inlined `seq` loop is then eliminated — and **the elimination removes the load and
   store through the dummy argument along with the loop.**

This is a deletion, not a bad address. Extracting the device IR from
`.cray.llvm.offloading` shows the kernel reduced to an index computation, a bounds check
and `ret void`:

```llvm
define amdgpu_kernel void @"element_out_$ck_L38_1"(i64 %arg) {
  %r6 = add i32 %r4, %r5                    ; global thread index
  %r9 = icmp ugt i32 %r6, 299               ; bounds check
  br i1 %r9, label %bb63, label %"39utop1"
  ...
  ret void                                  ; no call, no getelementptr, no store
}
```

The out-of-line `inner` is still present and still correct — CCE folded its eight
iterations into `fadd double %r4, 8.0` followed by `store double %r5, ptr %y` — but nothing
calls it. The correct build's kernel contains the address arithmetic and four stores.

Because this happens in `optcg`, before the IR is written to the offload section, it is not
reachable through `CRAY_CCE_LLD_ARGS`.

**Corroborating: `-hipa0` fixes it.** Disabling the inliner removes step 2, and both the
minimal case and the full application reproducer (all five kernels) become correct. That is
not a usable workaround — it disables inlining for the whole compilation — but it confirms
the inlining step is a necessary link.

## Scope

* **Hardware:** reproduced on a Frontier MI250X compute node and on an MI210 login node.
* **Versions:** CCE **19.0.0** (cpe/25.03, rocm/6.3.1), **20.0.2** (cpe/25.09, rocm/6.4.2),
  **21.0.0** and **21.0.2** (cpe/26.03, rocm/7.2.0) — identical on all four. Not a regression.
* **Optimization:** wrong at `-O2` and `-O3`; correct at `-O0` and `-O1`.
* **OpenACC only.** The same shape in OpenMP (`-homp`) is correct: a `declare target`
  routine containing `!$omp simd`, `!$omp loop bind(thread)`, or no inner directive,
  called from `target teams distribute parallel do`, all give exact results.
* **Symptom follows argument direction.** `intent(in)` element → reads garbage (NaN);
  `intent(out)` element → store dropped.

## What it is not — please don't spend time here

These were each ruled out by an explicit control:

* **Not translation-unit count.** CCE inlines the callee across separate compilations, so
  splitting files changes nothing. (Note the inlining step *is* part of the mechanism — see
  above — but it is not something the user can or should have to avoid.)
* **Not a misaddressed argument.** The device IR shows the call, the address arithmetic and
  the store simply absent, rather than a wrong address being used.
* **Not derived types.** An attached `q%vf(i)%sf(k)` pointer field and a plain
  `declare create` module array fail identically.
* **Not the mapping.** A plain store into the same array from the same kernel round-trips
  correctly.
* **Not a race.** Single-lane and 100 000-lane runs with per-lane inputs agree.
* **Not the index expression.** A literal and a device-resident derived-type member fail
  the same way.

## What we are asking for

1. Fix the elimination step. When the inlined loop is removed, the loads and stores through
   the routine's dummy arguments must survive. This is the actual defect and it affects the
   conforming spellings (`routine vector` / `worker` / `gang` containing an `!$acc loop`).
2. Emit a diagnostic where the inner `!$acc loop` is a no-op (`routine seq`) instead of
   silently generating wrong code. A warning alone would have saved the release.

Supporting artifacts (loopmark listings for both builds, extracted device IR for both, and
the `-hipa0` evidence) are in the repository linked below and can be attached to the case on
request.

## Workaround in use

Copy the element into a local scalar before the call and receive the result into a scalar:

```fortran
p = q%vf(1)%sf(k)
call inner(p, tmp)
b(k) = tmp
```

A register move on every backend, and bit-identical in MFC's regression suite.

## Full material

<https://github.com/sbryngelson/compiler-bugs/tree/main/cce/acc-routine-element-by-reference>
— minimal cases, controls that remove one ingredient each, `run.sh` that checks all seven
against documented outcomes, and measured output for all four CCE versions.
