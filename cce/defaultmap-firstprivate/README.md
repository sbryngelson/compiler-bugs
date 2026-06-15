# Cray CCE-19: `defaultmap(firstprivate:scalar)` does not actually firstprivate the scalars

Standalone reproducer for a Cray Fortran (CCE 19) OpenMP target-offload bug.

## Tracking

| Where | Link / ID |
|-------|-----------|
| OLCF Helpdesk | _filing_ |
| Source | MFC [MFlowCode/MFC#1588](https://github.com/MFlowCode/MFC/pull/1588) |

## Symptom

On a register-heavy `target teams distribute parallel do simd collapse(3)` kernel whose
per-cell scalar temporaries are left off the explicit `private()` list and instead ride on
`defaultmap(firstprivate:scalar)`, the kernel produces `NaN`. Listing those exact scalars in an
explicit `private()` **or** `firstprivate()` clause gives the correct answer. Frontier MI250X
(gfx90a), CCE 19.0.0, `OMP_TARGET_OFFLOAD=MANDATORY` (so these are device runs):

```
private(all scalars)                       checksum = 8.040644772571076E+07   correct
defaultmap(firstprivate:scalar), omitted   checksum =                    NaN   WRONG
firstprivate(all scalars)  (explicit)      checksum = 8.040644772571076E+07   correct
```

## Why it's a bug, not a semantic

`defaultmap(firstprivate:scalar)` is *defined* to give the covered scalars the `firstprivate`
attribute. The third line proves the compiler privatizes those exact scalars correctly when the
`firstprivate` clause is written explicitly — so they are legitimately firstprivate-able and the
NaN is not "those scalars can't be private." `defaultmap` simply isn't applying the firstprivate
it promises. `private(all)` (line 1) and `firstprivate(all)` (line 3) agree; only `defaultmap`
(line 2) diverges.

It is not a `simd` issue and not an optimization-level fluke (`results/run.txt`):

```
defaultmap -O3 simd     NaN
defaultmap -O2 simd     NaN
defaultmap -O1 simd     7.9951e7   (finite, but ~0.6% wrong)
defaultmap -O3 nosimd   NaN
defaultmap -O3 simd + firstprivate(re)   NaN   (an added firstprivate clause is not the trigger)
```

## What makes it appear

Register pressure. With only a handful of scalars left to `defaultmap`, CCE privatizes them
correctly; the failure needs enough omitted scalars that they spill. This is exactly how it hid
in MFC: the Riemann kernels left a few scalars off the `private()` list and rode `defaultmap`,
which worked — until an unrelated change (adding `firstprivate(Re_size_loc)`, an array, for an
AMD-flang workaround) raised register pressure enough to push the omitted scalars over the spill
threshold, and the omitted scalars silently went wrong on the Cray build. Completing the
`private()` lists (a semantic no-op on every other compiler) fixed it.

## Minimal form

One file, `cray_defaultmap.f90`, built with cpp knobs (`-D`). The body is a register-heavy
HLLC-style blob (~45 per-cell scalar temporaries through a long dependent arithmetic chain). The
knobs select only how the scalars are privatized:

| build | how the scalars are privatized | result |
|-------|--------------------------------|--------|
| (none)           | `private(<all>)`                         | correct |
| `-DOMIT_SCALARS` | omitted -> `defaultmap(firstprivate:scalar)` | **NaN** |
| `-DEXPLICIT_FP`  | `firstprivate(<all>)` explicitly         | correct |
| `-DNO_SIMD`      | drop the `simd` clause                   | still NaN |
| `-DWITH_FP`      | also add `firstprivate(re)`              | no change |

A light kernel (few omitted scalars) does not reproduce it — the omitted set has to be large
enough to spill.

## Build and run

Frontier (login node has a GPU, or run under `srun`):

```bash
./build_and_run.sh
```

CCE native OpenMP offload uses `-homp` (this `ftn` does not accept the clang-style
`-fopenmp --offload-arch=gfx90a`); `-eZ` runs the C preprocessor for the `-D` knobs. Modules:
`PrgEnv-cray craype-accel-amd-gfx90a cce/19.0.0`.

## Versions

Reproduced on CCE 19.0.0 (the version MFC's Frontier Cray build uses). CCE 20.0.2 / 21.0.0 are
present on Frontier but their `ftn` was not functional with the login `cpe` at the time of
testing, so they were not checked. AMD flang and nvfortran offload builds of the same code are
correct.

## Workaround

List the scalars explicitly in `private()` (or `firstprivate()`); do not rely on
`defaultmap(firstprivate:scalar)` to privatize per-cell scalars in a heavy offload kernel.

## Source

MFC (https://github.com/MFlowCode/MFC). The omitted scalars were per-cell temporaries in the HLL
/ HLLC / LF Riemann kernels (`s_M`, `s_P`, `xi_M`, `xi_P`, and others); the fix in
MFlowCode/MFC#1588 was to complete the `private()` lists.
