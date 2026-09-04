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

* **Not inlining, and not translation-unit count.** The reproducer is one file, one call
  level, an eight-line callee. With the loop directive removed, the same call stays correct
  when the callee is moved to its own translation unit *and* under `-hipa0`.
* **Not derived types.** An attached `q%vf(i)%sf(k)` pointer field and a plain
  `declare create` module array fail identically.
* **Not the mapping.** A plain store into the same array from the same kernel round-trips
  correctly.
* **Not a race.** Single-lane and 100 000-lane runs with per-lane inputs agree.
* **Not the index expression.** A literal and a device-resident derived-type member fail
  the same way.

## What we are asking for

1. Fix the miscompilation for the conforming cases (`routine vector` / `worker` / `gang`
   containing an `!$acc loop`).
2. Emit a diagnostic where the inner `!$acc loop` is a no-op (`routine seq`) instead of
   silently generating wrong code. A warning alone would have saved the release.

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
