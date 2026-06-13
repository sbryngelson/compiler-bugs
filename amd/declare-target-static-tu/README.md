# AMD flang: static `declare target` variable not shared across translation units

Standalone reproducer for an AMD flang (ROCm) OpenMP offload bug.

## Tracking

| Where | Link / ID |
|-------|-----------|
| ROCm/llvm-project | [#2890](https://github.com/ROCm/llvm-project/issues/2890) |
| llvm/llvm-project | [#203711](https://github.com/llvm/llvm-project/issues/203711) |
| OLCF helpdesk | filed |

## Symptom

A `declare target` module variable with static storage (a scalar or fixed-size array, i.e.
not `allocatable`) is not unified across translation units on the device. A `target update
to` / `map(to:)` in one TU updates only that TU's device copy; a `target` region in another
TU reads its own copy, which still holds the initial value.

```
expected:  s_sc = 2   s_ar(1) = 2   a_ar(1) = 2
amdflang:  s_sc = 0   s_ar(1) = 0   a_ar(1) = 2
```

`repro_main` (TU 2) sets all three to 2 and pushes them to the device; the kernel in
`repro_mod` (TU 1) reads them back.

## What's broken

Storage class, not array-ness: a static scalar is stale too, so this is not about array
descriptors or bounds.

Observed:
- Static scalar and static array both stale; allocatable correct.
- Same result at `-flto-partitions=1` and `16`, so it is not LTO partitioning.
- Passing the static variable as a `map(to:)` argument does not help.
- Cray cce and nvfortran are unaffected.

This matches static `declare target` data being a device global resolved by symbol that the
device link does not merge across objects, while allocatable data is reached through the
runtime's host->device mapping table (one global table, hence TU-independent). Either way the
fix is the same: use allocatable.

## Minimal form

Two source files; a single-file build does not reproduce. The irreducible trigger is one
static `declare target` scalar set in TU A and read in a `target` region in TU B. The static
array and the allocatable are here only to show the boundary.

- `repro_mod.f90` — the three variables and the kernel that reads them.
- `repro_main.f90` — sets them on the host, pushes to the device, calls the kernel (separate TU).

## Build and run

Frontier compute node (MI250X, gfx90a):

```bash
sbatch run.sbatch        # or, interactively:
bash build_and_run.sh
```

Flags, as used by the MFC build that hit this:

```
amdflang (ROCm 7.2.0)
compile: -fopenmp --offload-arch=gfx90a -O3 \
         -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription
link:    -fopenmp --offload-arch=gfx90a -flto-partitions=16
run:     OMP_TARGET_OFFLOAD=MANDATORY
```

Verified on `amdflang` ROCm 7.2.0 (LLVM `22.0.0git`) **and** the newest available drop, AFAR
23.2.0 (LLVM `23.0.0git`, dated 2026-04-18) — fails on both.

A sharper companion reproducer — two *identical* arrays disagreeing in one kernel based only on
the push mechanism (`enter data map` vs `update to`) — is in `../declare-target-roulette/`.

## Fix

Avoid reading the `declare target` static from the device at all: capture it host-side and
`firstprivate` the value into the kernel. In MFC this variable was `Re_size`
(`integer, dimension(2)`): #1556 moved the kernel that reads it into a different module from the
`GPU_UPDATE` that sets it, so the kernel saw `Re_size = 0` and viscosity was silently disabled
in `2D_viscous_shock_tube`.

**Note:** making the variable `allocatable` (as the symptom might suggest) is *not* a reliable
fix in the full application — it only moves the bug to other kernels (an *inversion*: static
breaks some solver kernels, allocatable breaks others; the defect is per-kernel codegen, not a
clean static-vs-allocatable rule). The robust fix is the host-capture / `firstprivate` workaround
above. (MFC PR: MFlowCode/MFC#1588.)

## Source

MFC (https://github.com/MFlowCode/MFC). Failed only on the Frontier AMD flang OpenMP offload
build after #1556 split `m_riemann_solvers`; Cray and nvfortran builds were unaffected.
