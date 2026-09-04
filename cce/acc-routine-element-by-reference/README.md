# CCE OpenACC: an `!$acc loop` inside an `!$acc routine seq` corrupts array-element arguments to that routine

> **Severity:** **Silent wrong answers** — reads through the argument return garbage, writes through it are lost
> **Fix belongs to:** CCE Fortran front end / OpenACC lowering
> **Status:** Root cause isolated to a single directive; 37-line reproducer in [`minimal/`](minimal); workaround applied in the application

**Wrong answers, no diagnostic, no crash.** An `!$acc routine seq` that contains an
`!$acc loop` mis-passes any **array element** given to it as an actual argument. An
`intent(in)` element arrives as garbage (the result is NaN); an `intent(out)` element is
never written (the array keeps its previous contents). Wrong from `-O2` up, correct at
`-O0`/`-O1`.

**Two ingredients, both required:**

| `!$acc loop` in the routine | actual argument | result |
|---|---|---|
| yes (`loop` or `loop seq`) | array element | **wrong** |
| yes | scalar | right |
| no | array element | right |
| no | scalar | right |

Delete the loop directive — which is a no-op in a `seq` routine anyway, since such a
routine generates no parallelism — and the same program is correct. Pass a scalar and it
is correct. Nothing else matters: not the derived type, not the call depth, not the
number of translation units, not the index expression.

* **Component:** CCE Fortran, OpenACC (`-hacc`), gfx90a
* **Severity:** silent miscompilation — wrong numerical results
* **Affected:** CCE **19.0.0, 20.0.2, 21.0.0, 21.0.2**, identical on all four
  ([`results/run-minimal-version-sweep.txt`](results/run-minimal-version-sweep.txt)).
  Not a regression. The OpenMP-offload build of the same application source is correct,
  as are amdflang and nvfortran.
* **Not yet checked:** the `-homp` spelling of this reproducer; whether `routine gang`
  / `worker` / `vector` behave the same.

CCE accepts the nested `!$acc loop` without a diagnostic and then miscompiles the call
rather than ignoring the directive. **A warning here would have cost the application a
release.**

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
| `results/run-cce19-login-node.txt` | The measured output of the application-shaped reproducer. |
| `minimal/element_out.f90` | **The defect in 37 lines**: one file, one call level, an eight-line callee. `intent(out)` element — the store is dropped. |
| `minimal/element_in.f90` | Same defect, `intent(in)` element — reads garbage, so the symptom is NaN. |
| `minimal/derived_type_in.f90` | The attached `q%vf(1)%sf(k)` field MFC actually uses, in place of the plain module array. Identical outcome. |
| `minimal/control_no_loop.f90` | `element_out.f90` with the one `!$acc loop seq` line deleted. Correct. |
| `minimal/control_scalar_arg.f90` | `element_out.f90` with the directive kept and a scalar actual argument. Correct — this is the workaround. |
| `minimal/run.sh` | Builds all five, checks each against its documented outcome, then sweeps `-O0..-O3`. |
| `results/run-minimal-cce21.txt`, `results/run-minimal-version-sweep.txt` | Measured output of the above. |

## The minimal case

```fortran
subroutine inner(x, y)
  !$acc routine seq
  real(wp), intent(in)  :: x
  real(wp), intent(out) :: y
  integer :: it
  y = x
  !$acc loop seq          ! <=== delete this line and the program is correct
  do it = 1, 8
    y = y + 1.0_wp
  end do
end subroutine
...
!$acc parallel loop
do k = 0, n
  call inner(real(k, wp), b(k))     ! array element as the intent(out) actual arg
end do
```

`b` is a `declare create` module allocatable. Measured, CCE 21.0.2 / ROCm 7.2.0, `-hacc -O2`:

```
element out : bad 300 of 300   got  0.000000E+00   expected  8.000000E+00
element in  : bad 300 of 300   got           NaN   expected  8.000000E+00
dtype in    : bad 300 of 300   got           NaN   expected  8.000000E+00
no loop     : bad   0 of 300   got  8.000000E+00   expected  8.000000E+00
scalar arg  : bad   0 of 300   got  8.000000E+00   expected  8.000000E+00
```

`-O0` and `-O1` are correct; `-O2` and `-O3` are wrong.

### Corrections to the earlier analysis

The first version of this page concluded that the trigger was *"an array element passed by
reference into a `routine seq` that CCE does not inline"*, and that *"a callee small enough
for CCE to inline hides the defect"*. Both were wrong, and the minimization above says why:

* **Inlining is not the mechanism.** `minimal/element_out.f90` is a single file with one
  call level and an eight-line callee, and it fails. Conversely, with the loop directive
  removed, the same call stays correct when the callee is moved to its own translation unit
  **and** when interprocedural optimization is disabled with `-hipa0`. Non-inlining is
  neither necessary nor sufficient.
* **What the original callee graph was really contributing** was the `!$acc loop seq` on
  the Newton iteration inside `reference_curve` — not its size. Making the callee big
  enough to defeat the inliner was a coincidence of how the reproducer was built.
* **The derived type contributes nothing.** An attached `q%vf(i)%sf(k,l,m)` field and a
  plain `declare create` module array fail identically
  (`minimal/derived_type_in.f90` vs `minimal/element_in.f90`). The earlier note that
  *"elements of `enter data` local allocatables passed the same way were correct"* is
  explained by those probes not having a loop directive in the callee.
* **The argument direction picks the symptom**, and that is all it does: `intent(in)`
  elements read garbage (NaN), `intent(out)` element stores are dropped (stale value).

The workaround is unchanged and still correct — it removes the *other* ingredient.

## The application-shaped reproducer

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
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2
./minimal/run.sh 21.0.2      # the 37-line case and its four controls
./build_and_run.sh 21.0.2    # the application-shaped case (CCE 19: cpe/25.03, rocm/6.3.1, cce/19.0.0)
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
running inside MFC on Frontier. They remain true and they narrowed the search:

* Not the callees: every helper evaluated on the device from a fresh kernel with literal or
  local-array arguments matched the host, single-lane and over 100 000 lanes.
* Not function versus subroutine: converting the helpers to subroutines changed nothing.
* Not a race between lanes: the 100 000-lane check had per-lane inputs and zero mismatches.
* Not the index kind: a literal and a device-resident derived-type member fail identically.
* Not the mapping: the module array here is both `declare create` and `enter data create`,
  as in MFC, and a plain store into it from a kernel round-trips.

Added by the minimization, and these are the ones that identify it:

* **Not inlining, and not the number of translation units** — see the corrections above.
* **Not the derived type** — a plain `declare create` array fails the same way.
* **Not `seq` specifically** — a bare `!$acc loop` inside the routine triggers it too.
* **It is the loop directive.** Every configuration that contains an `!$acc loop` inside
  the `!$acc routine seq` *and* passes an array element to it is wrong; every configuration
  missing either one is right.

## Workaround

Copy the element to a scalar before the call and receive the result into a scalar. It is a
register move on every backend and bit-identical in MFC's regression suite. The
application now does this at every device-routine call.
