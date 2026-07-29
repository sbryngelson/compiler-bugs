# Cray CCE-19: `defaultmap(firstprivate:scalar)` does not actually firstprivate the scalars

> **Severity:** Abort  
> **Fix belongs to:** CCE — filed as OLCFHELP-26859  
> **Status:** CCE 19/20-era. Superseded in practice by the CCE 21 `defaultmap` defects, which share the theme of `defaultmap` overriding an explicit clause.

Standalone reproducer for a Cray Fortran (CCE 19) OpenMP target-offload bug.

## Tracking

| Where | Link / ID |
|-------|-----------|
| OLCF Helpdesk | OLCFHELP-26859 |
| Source | MFC [#1588](https://github.com/MFlowCode/MFC/pull/1588), [#1572](https://github.com/MFlowCode/MFC/pull/1572) |
| Related | [`../omp-defaultmap-scalar-override`](../omp-defaultmap-scalar-override) — **a different defect**, same clause: this entry is CCE 19 failing to firstprivate scalars that `defaultmap` covers; that one is CCE 21 firstprivating a scalar that was *explicitly* `map`-ed. Do not merge the two. |

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

## Verdict and exit codes

`build_and_run.sh` compares every variant's checksum against the reference
`8.040644772571076E+07` (relative tolerance 1e-6; NaN counts as wrong) and prints a
`VERDICT:` line:

| exit | verdict | meaning |
| --- | --- | --- |
| 0 | BUG PRESENT | `defaultmap(firstprivate:scalar)` is wrong while `private(all)` and `firstprivate(all)` are both correct — the documented state |
| 1 | FIXED | all three spellings agree — a deviation from the documented state |
| 2 | INCONCLUSIVE | a variant failed to build, or a control came out wrong |

The two controls are the point of the test. `private(all)` and `firstprivate(all)` name the
**same scalars** that `defaultmap(firstprivate:scalar)` is supposed to cover, so all three
must agree. When the controls are correct and only `defaultmap` is wrong, the environment is
fine and the compiler is not — which is why a wrong control reports INCONCLUSIVE (exit 2)
rather than a bug.

Measured on CCE 19.0.0, one MI250X GCD, `OMP_TARGET_OFFLOAD=MANDATORY`:

```
  private(all) simd                  checksum =  8.040644772571076E+07   correct
  defaultmap(fp:scalar) simd         checksum =                    NaN   WRONG
  firstprivate(all) simd             checksum =  8.040644772571076E+07   correct
  ... -O2 / -O1 / nosimd / +fp(re)                                       WRONG (4/4)
VERDICT: BUG PRESENT (as documented) -- wrong in 4/4 robustness configs too.  # exit 0
```

`-O1` is worth noting: it gives a finite but ~0.6% wrong answer instead of NaN. Anyone
checking only for NaN would call `-O1` clean, which is exactly the silent-wrong-answer
failure mode this repo exists to catch.

Exit codes follow the repo-wide convention: **0 means reality matched this document**
(the defect is still present), nonzero means something changed and needs a human.
See `../README.md`.

## Root cause: the scalars are promoted to workgroup-shared LDS

Established by comparing the emitted **device IR** of the `defaultmap` and explicit
`firstprivate` builds. Two steps, in order:

**1. It is not a data-mapping bug.** With `CRAY_ACC_DEBUG=2`, the two builds produce
**byte-identical** runtime mapping traces (34 lines each, diff empty after address
normalisation) — yet one returns the correct checksum and the other NaN. Whatever the host
runtime does, it does the same thing in both cases. The defect is in generated device code.

**2. The scalars land in `addrspace(3)` — LDS, shared per workgroup.**

| build | LDS globals (`^@... addrspace(3)`) |
| --- | --- |
| explicit `firstprivate(...)` | **0** |
| `defaultmap(firstprivate:scalar)` | **47** |

The 47 objects are named after the very scalars the clause is supposed to firstprivatise:

```llvm
@"$$_rho_l_t115_AMD_LDS_46"    = internal addrspace(3) externally_initialized global double poison, align 32
@"$$_pres_r_t112_AMD_LDS_43"   = internal addrspace(3) externally_initialized global double poison, align 32
@"$$_xi_m_t76_AMD_LDS_10"      = internal addrspace(3) externally_initialized global double poison, align 32
@"$$_vel_k_star_t67_AMD_LDS_1" = internal addrspace(3) externally_initialized global double poison, align 32
...
```

and every thread stores its own computed value to the same address:

```llvm
store double %r28, ptr addrspace(3) @"$$_rho_l_t115_AMD_LDS_46", align 8
store double %r39, ptr addrspace(3) @"$$_rho_r_t114_AMD_LDS_45", align 8
```

So instead of one copy **per thread**, there is one copy **per workgroup**, and the whole
workgroup races on it. Last writer wins; downstream arithmetic sees another thread's
intermediate values, and the checksum degrades to NaN. There are only **5** barriers in the
module against 47 shared scalars — not remotely enough synchronisation even if sharing had
been intended, which confirms this is not a deliberate optimisation with a missing fence.

This also explains the `-O1` behaviour noted above: at `-O1` the races are less densely
interleaved, so the answer comes out finite but ~0.6% wrong rather than NaN. Same defect,
quieter symptom — which is the dangerous case.

**The vendor-facing statement:** CCE applies its LDS-promotion path to scalars covered by
`defaultmap(firstprivate:scalar)`, giving them workgroup extent where the clause requires
per-thread extent. The explicit `firstprivate(...)` spelling of the same scalars produces no
LDS at all and is correct, so the promotion decision is specific to the `defaultmap` path.

### Not the same bug as `omp-defaultmap-scalar-override`

Tempting to unify the two `defaultmap` defects; the IR says no. That one privatises a scalar
that should be shared — the **opposite** direction. Measured, not assumed:

| entry | CCE | what `defaultmap` does | result |
| --- | --- | --- | --- |
| this one | 19.0.0 | private scalar → **workgroup-shared LDS** | race → NaN |
| [`../omp-defaultmap-scalar-override`](../omp-defaultmap-scalar-override) | 21.0.2 | mapped scalar → **thread-private** | no contention → duplicates |

Both are `defaultmap` assigning the wrong data-sharing attribute, in opposite directions.
Report them as two defects.
