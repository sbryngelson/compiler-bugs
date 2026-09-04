# CCE OpenACC: an `acc loop seq` inside a `routine seq` makes an array-element actual argument read as garbage and never be written

> **Severity:** **Silent wrong answers** — reads through the argument return garbage, writes through it are lost  
> **Fix belongs to:** CCE optimizer (`-O2`; `-O0` and `-O1` are correct)  
> **Status:** **Bisected to one line.** `!$acc loop seq` inside an `!$acc routine seq`, plus an array element as the routine's actual argument; either alone is fine. Workaround applied in the application

**Wrong answers, no diagnostic, no crash.** Inside an `!$acc parallel loop`, a call to an
`!$acc routine seq` subroutine whose actual argument is an **element of a device-resident
array** — an attached derived-type field `q%vf(i)%sf(k,l,m)` or a `declare create` module
array `blkmod(k,l,m)` — passes a wrong address when the callee is not inlined. An
`intent(in)` element arrives as garbage (the output is NaN); an `intent(out)` element is
never written (the array keeps its previous contents). The same call with the values
copied to scalars first, and the result received into a scalar, is exact. Whether the
field index is a literal or a member of a device-resident derived type makes no difference.

A callee small enough for CCE to inline at device link time hides the defect entirely,
which is how the application carried the pattern for one release before a deeper callee
graph exposed it.

* **Component:** CCE Fortran, OpenACC (`-hacc`), gfx90a
* **Severity:** silent miscompilation — wrong numerical results
* **Affected:** CCE **19.0.0** (cpe/25.03, ROCm 6.3.1), **20.x** and **21.0.2** — identical
  signature on all three. The OpenMP-offload build of the same application source is correct,
  as are amdflang and nvfortran.
* **Not yet checked:** `-homp` on this exact reproducer.

Found in MFC (<https://github.com/MFlowCode/MFC>): every regression test on the new
equation-of-state paths ended in `NaN(s) in timestep output` on the Frontier CCE OpenACC
lanes only. An in-situ check recomputed one kernel's output on the host from the same
fields: device 0.0 in 300 of 300 cells, host 1.4.

## The one-line trigger

`min/loopseq_bug.f90` (37 lines, one module, one routine, no derived types):

```fortran
subroutine inner(x, y)
  !$acc routine seq
  real(wp), intent(in)  :: x
  real(wp), intent(out) :: y
  integer :: it
  y = x
  !$acc loop seq          ! <-- delete this one line and the result is correct
  do it = 1, 8
    y = y + 1.0_wp
  end do
end subroutine
...
!$acc parallel loop
do k = 0, n
  call inner(real(k, wp), b(k))     ! array element as the intent(out) actual argument
end do
```

`bad 300 of 300, got 0.0, expected 8.0`: the store to `y` is discarded entirely.

The bisection ladder from the full reproducer above (each row removes one thing from an
otherwise failing program):

| removed | still fails? |
|---|---|
| derived type `q%vf(i)%sf` / pointer components | yes |
| `collapse(3)`, 3-D arrays | yes |
| the state-dependent branch, `select case`, `exp()` | yes |
| module allocatables → parameters | yes |
| 3-level call chain → 2 → 1 | yes |
| the `!$acc loop seq` directive | **no — passes** |
| the whole iteration loop | **no — passes** |

And the controls: an array element as the actual argument of a routine *without* a loop passes;
a routine with the loop called with a scalar, whose value is then stored, passes (this is the
workaround). So the element argument alone is not the defect, and neither is the directive
alone.

* `-O2` wrong; `-O0` and `-O1` correct. Independent of `acc_model=auto_async_none` /
  `no_fast_addr`; plain `-hacc -O2` is enough.
* Not a regression: CCE 19.0.0, 20.0.0, 20.0.2, 21.0.0, 21.0.2 all fail (18.0.1 does not build
  the accelerator target here). ROCm 6.4.2 and 7.13.0 both.
* `!$acc loop` inside a `routine seq` is dubious OpenACC to begin with: a `seq` routine
  generates no parallelism, so the directive should be a no-op. The defect is that CCE accepts
  it without a diagnostic and then drops the store instead of ignoring the directive.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | not yet filed |
| MFC issue | [MFlowCode/MFC#1815](https://github.com/MFlowCode/MFC/issues/1815) |
| MFC fix | [MFlowCode/MFC#1811](https://github.com/MFlowCode/MFC/pull/1811), commit `1ee119b9`: scalars in, scalar out at every device-routine call; rule recorded in `.claude/rules/common-pitfalls.md` |
| Related | [`../explicit-shape-dummy-lost-writes`](../explicit-shape-dummy-lost-writes) — also a wrong address handed across a routine boundary, there through a 0-byte map under OpenMP |

## Files

| file | what it is |
|---|---|
| `m_eos.f90` | The callee graph, mirrored from MFC: `bulk_modulus → coefficients → reference_curve` (a device-resident flag, a `select case`, a Newton loop, `exp`, `**`) so CCE does not inline it. Reads `declare create` module arrays by index. |
| `m_rhs.f90` | Five kernels, one per argument kind, all calling the same `bulk_modulus` on the same data: field elements in with array-element out (index from a device-resident type / literal), field elements in with scalar out, scalars in with array-element out, scalars in and out. |
| `main.f90` | Maps everything exactly as MFC does (`enter data copyin` of the derived type, its component array, each element and each pointed-to field; `declare create` **and** `enter data create` for the module array), checks that a plain kernel store round-trips, then runs the five kernels against a host reference. Self-checking, NaN-safe. |
| `build_and_run.sh` | Guarded build with MFC's flags, three separate compilations, then the run. |
| `results/run-cce19-login-node.txt` | The measured output quoted below. |
| `min/loopseq_bug.f90` | **The minimal case.** One routine, one loop directive, one array-element argument. |

## The kernel of it

```fortran
!$acc parallel loop collapse(3) private(k, l, m)
do m = 0, 0; do l = 0, 0; do k = 0, n
  ! wrong: element in, element out (bulk_modulus is a real call here)
  call bulk_modulus(q%vf(eqn%e)%sf(k, l, m), q%vf(eqn%adv)%sf(k, l, m), q%vf(eqn%cont)%sf(k, l, m), 1, blkmod(k, l, m))
end do; end do; end do

!$acc parallel loop collapse(3) private(k, l, m, p, a, ar, b)
do m = 0, 0; do l = 0, 0; do k = 0, n
  ! right: the same call on scalars
  p = q%vf(eqn%e)%sf(k, l, m); a = q%vf(eqn%adv)%sf(k, l, m); ar = q%vf(eqn%cont)%sf(k, l, m)
  call bulk_modulus(p, a, ar, 1, b)
  blkmod(k, l, m) = b
end do; end do; end do
```

`bulk_modulus` is `!$acc routine seq`, lives in another file, and calls two more
`routine seq` subroutines with `intent(out)` scalars. Nothing about it is unusual; the
same routine is exact when called from the host.

## Reproduce

```
module reset
module load cpe/25.03 rocm/6.3.1 craype-accel-amd-gfx90a
module swap cce cce/19.0.0
./build_and_run.sh
```

### Measured — CCE 19.0.0 / ROCm 6.3.1, gfx90a, Frontier login node (CCE 20 and 21.0.2: same output)

```
sanity store:      bad     0 of   300                       <- a plain kernel store round-trips
element, type index:  bad   300 of   300  0.000000E+00  2.438493E+00
element, const index: bad   300 of   300  0.000000E+00  2.438493E+00
elements in, scalar out: (NaN)                              <- the inputs arrive as garbage
scalars in, element out: bad   300 of   300  0.000000E+00  2.438493E+00
scalar:               bad     0 of   300  2.438493E+00  2.438493E+00   <- the control
```

The two numbers on each line are the device's `blkmod(0)` and the host reference. Outputs
written through an element argument stay at the 0.0 they were initialized to; inputs read
through one give NaN.

The build prints `ftn-7255` for `main.f90` line 28: that is the **host** reference loop that
calls `bulk_modulus` (an `acc routine`) to compute `ref`; CCE notes the routine's
directive is ignored on the host. Harmless, and not part of what is being measured.

## What the mechanism is *not*

Each of these was tested on the application before the reproducer existed, by probes
running inside MFC on Frontier:

* Not the callees: every helper evaluated on the device from a fresh kernel with literal or
  local-array arguments matched the host, single-lane and over 100 000 lanes.
* Not function versus subroutine: converting the helpers to subroutines changed nothing.
* Not a race between lanes: the 100 000-lane check had per-lane inputs and zero mismatches.
* Not the index kind: a literal and a device-resident derived-type member fail identically.
* Not the mapping: the module array here is both `declare create` and `enter data create`,
  as in MFC, and a plain store into it from a kernel round-trips.

The bisection above supersedes the address-materialization reading: the element argument is
necessary but not sufficient, and the `loop seq` directive inside the routine is the other half.

## Workaround

Copy the element to a scalar before the call and receive the result into a scalar. It is a
register move on every backend and bit-identical in MFC's regression suite. The
application now does this at every device-routine call.
