# Cray CCE-19: `defaultmap(firstprivate:scalar)` does not actually firstprivate the scalars

Standalone reproducer for a Cray Fortran (CCE 19) OpenMP target-offload bug.

## Tracking

| Where | Link / ID |
|-------|-----------|
| OLCF Helpdesk | OLCFHELP-26859 |
| Source | MFC [#1588](https://github.com/MFlowCode/MFC/pull/1588), [#1572](https://github.com/MFlowCode/MFC/pull/1572) |

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
correctly; the failure needs the omitted scalars to spill. The dangerous part: that threshold can
be crossed by a small, *semantics-preserving* change anywhere else in the kernel — with no
diagnostic, and correct results on every other compiler.

This is not a synthetic corner case — it has silently broken production code (MFC) **twice**, each
time from an unrelated change that nudged register allocation:

- **MFC [#1588](https://github.com/MFlowCode/MFC/pull/1588)** — adding `firstprivate(Re_size_loc)`
  (an AMD-flang viscous workaround) raised register pressure enough that the HLL Riemann kernel's
  omitted scalars spilled and went silently wrong. Fix: complete the `private()` lists.

- **MFC [#1572](https://github.com/MFlowCode/MFC/pull/1572)** — a hot-path refactor that extracted
  arithmetic into device helpers (which CCE *correctly inlines* — verified) shifted register
  allocation just past the threshold. With only **four** scalars (`s_M, s_P, xi_M, xi_P`) riding
  `defaultmap`, the HLL kernel produced gross errors on golden regression tests — relative errors up
  to **4.6E+14** (a conserved variable that should be `3.5e-13` came out `-162`), ~5.8% on others —
  on Cray CCE-19 GPU-OMP **only**; AMD flang and NVHPC builds were green. Fix: add those four scalars
  to `private()`.

So four omitted scalars is enough, the trigger can be almost any change that touches register
allocation, and the only symptom is wrong numbers. Completing the `private()` list (a semantic no-op
on every other compiler) is the workaround in both cases.

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

Frontier (login node has a GPU, or run the binaries under `srun`). Load a working CCE-19
GPU-offload environment first — the bare `module load`s miss cpe / pkg-config paths and `ftn`
fails with `libopenacc not found`, so use MFC's loader, which sets them up:

```bash
source /path/to/MFlowCode-MFC/mfc.sh load -c f -m g   # CCE 19 + craype-accel-amd-gfx90a
./build_and_run.sh
```

Built with `ftn -fopenmp -O3`. crayftn takes the gfx90a target from the
`craype-accel-amd-gfx90a` module (loaded by `-m g`), not from `--offload-arch`; `-eZ` runs the
C preprocessor for the `-D` knobs.

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
