# CCE 19 OpenACC: a device-array element passed by reference into a non-inlined `routine seq` is read as garbage and never written

> **Severity:** **Silent wrong answers** — reads through the argument return garbage, writes through it are lost  
> **Fix belongs to:** CCE Fortran front end / OpenACC lowering (address materialization at a device-routine call boundary)  
> **Status:** Reproduced standalone in both directions; workaround applied in the application

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
* **Affected:** CCE **19.0.0** (cpe/25.03, ROCm 6.3.1). The OpenMP-offload build of the same
  application source is correct, as are amdflang and nvfortran.
* **Not yet checked:** CCE 21.0.2; `-homp` on this exact reproducer.

Found in MFC (<https://github.com/MFlowCode/MFC>): every regression test on the new
equation-of-state paths ended in `NaN(s) in timestep output` on the Frontier CCE OpenACC
lanes only. An in-situ check recomputed one kernel's output on the host from the same
fields: device 0.0 in 300 of 300 cells, host 1.4.

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

### Measured — CCE 19.0.0 / ROCm 6.3.1, gfx90a, Frontier login node

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

What is left is the address handed to the callee for an array element when the call is
real. Elements of `enter data` *local* allocatables passed the same way were correct in the
in-application probe, so the affected cases are the `declare create` module array and the
attached pointer field; the reproducer covers the second as inputs and the first as output.

## Workaround

Copy the element to a scalar before the call and receive the result into a scalar. It is a
register move on every backend and bit-identical in MFC's regression suite. The
application now does this at every device-routine call.
