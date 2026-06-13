# AMD flang: declare-target read correctness depends on an incidental push choice ("roulette")

Minimal standalone reproducer (4 files, ~40 lines) for an AMD flang (ROCm) OpenMP-offload bug.

## Symptom

Two **identical** static `declare target` module integer arrays, both host-set to `2`, read by
the **same** `target` kernel with the **same** code, return **different** values on the device.
The only difference between them is *how each was pushed to the device*:

```
array pushed via enter-data-map: 0   STALE
array pushed via update-to     : 2   ok
```

Both `!$omp target enter data map(to: x)` and `!$omp target update to(x)` are supposed to make
the device copy hold the host value (`2`). One of them leaves the kernel reading a stale/zero
copy. Correctness depends on a semantics-preserving incidental choice — there is no source-level
reason the two arrays should differ.

The disagreement is itself proof of device execution: a host fallback would print `2`/`2`.

## Why this matters ("roulette")

This is the minimal, *deterministic* form of a broader fragility: on AMD flang, whether a
cross-translation-unit `declare target` read returns the live device copy or a stale one is
decided by incidental codegen/runtime factors, not by program semantics. In a large application
the same defect shows up as a per-*kernel* roulette — the identical read is correct in one kernel
and stale in another, with the same push mechanism — which is far harder to reduce. This 4-file
case isolates one clean, reproducible instance of the same class.

## Layout (3 translation units — the staleness needs the decl/push/read split)

| File         | Role                                                                 |
|--------------|----------------------------------------------------------------------|
| `state.f90`  | declares `rs_map` + `rs_upd`, both static `declare target`           |
| `push.f90`   | host-sets both to 2; pushes `rs_map` via `enter data map`, `rs_upd` via `update to` (different TU) |
| `read.f90`   | one kernel reads both with identical code (different TU)             |
| `main.f90`   | driver; exits 2 if the two disagree                                  |

## Build & run (Frontier MI250X / gfx90a)

```bash
FC=amdflang
CF="-fopenmp --offload-arch=gfx90a -O3 -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription"
for s in state push read main; do $FC $CF -c $s.f90 -o $s.o; done
$FC -fopenmp --offload-arch=gfx90a -flto-partitions=16 state.o push.o read.o main.o -o prog
OMP_TARGET_OFFLOAD=MANDATORY ./prog
```

Compiler: `amdflang` (ROCm 7.2.0), LLVM `22.0.0git`, `roc-7.2.0` branch. Verified to still
reproduce on the newest available drop, AFAR 23.2.0 (LLVM `23.0.0git`, dated 2026-04-18).

## Filed upstream

- AMD ROCm: https://github.com/ROCm/llvm-project/issues/2890
- LLVM:     https://github.com/llvm/llvm-project/issues/203711

## Relation to the other reproducer

`../declare-target-static-tu` shows the basic cross-TU stale read (static stale,
allocatable fine). This one is sharper: it shows two *identical* arrays disagreeing in one
kernel, isolating that correctness hinges on an incidental factor. Found in MFC
(https://github.com/MFlowCode/MFC), where the same defect silently disabled viscosity on the
AMD-flang GPU build.
