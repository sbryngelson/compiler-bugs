## Compiler Bug Reproducers

Minimal reproducers for Fortran compiler bugs encountered in HPC workloads on OLCF Frontier.

---

### `cce/` — Cray CCE 15.0.1 Fortran + OpenACC

Module-scope variables and nested allocatable derived types under `!$acc declare` (link/create).
12 reproducers + archived cases. Bug reports: **OLCFDEV-1416, CAST-31898**. See `cce/README.md`.

---

### `amd/no-loop-array-ops/` — amdflang: wrong results with `-fopenmp-target-fast` + array expressions

Array constructor and whole-array slice ops inside `!$omp target` kernels produce wrong results
when `-fopenmp-target-fast` and both oversubscription flags are present.
Root cause: `no_loop` exec mode hoists `omp_get_num_threads()` before the parallel region is set up,
yielding stride=1 instead of 32 — threads K+31..N-1 are never assigned.
Upstream issue: [ROCm/llvm-project#2601](https://github.com/ROCm/llvm-project/issues/2601).

---

### `amd/declare-target-static-tu/` — amdflang: static `declare target` variable stale across translation units

A static (non-allocatable) `!$omp declare target` module variable is not unified across TUs on the
device. A `map(to:)` in TU A updates only TU A's device copy; a kernel in TU B reads its own
still-zero copy. Allocatable variables are unaffected.
Bug reports: [ROCm/llvm-project#2890](https://github.com/ROCm/llvm-project/issues/2890),
[llvm/llvm-project#203711](https://github.com/llvm/llvm-project/issues/203711). Also filed with OLCF helpdesk.

---

### `amd/declare-target-roulette/` — amdflang: identical `declare target` arrays disagree in one kernel

A sharper form of the same defect. Two *identical* static `!$omp declare target` arrays, both
host-set to 2, read by the *same* kernel with the *same* code, return *different* values (`0` vs
`2`) — differing only in how each was pushed (`enter data map` vs `update to`). Shows that
declare-target read correctness depends on an incidental, semantics-preserving choice rather than
program semantics. Same bug reports
([ROCm/llvm-project#2890](https://github.com/ROCm/llvm-project/issues/2890),
[llvm/llvm-project#203711](https://github.com/llvm/llvm-project/issues/203711)).

---

### `amd/flang-firstprivate-array-occupancy/` — amdflang: `firstprivate` of a small array spills to scratch

A `firstprivate` clause on a small fixed-size integer array (8 bytes) on a register-heavy
`target teams distribute parallel do` kernel spills ~35 KB/work-item to scratch, pins AGPRs at the
hardware maximum, and drops occupancy to one wave per SIMD — a 30-50x slowdown. The same two
integers passed as scalars, or as a plain `private` array seeded from those scalars, cost nothing.
Isolation (constant-indexed firstprivate array still spills; dynamically-indexed *private* array
does not) shows the trigger is `firstprivate` of an array, not the indexing. The copy-in is lowered
through the Fortran array-assignment runtime (`_FortranAAssign`) rather than a value copy:
undefined device symbol on ROCm 7.2.0, a scratch-spilling blob on afar 23.1.0 and 23.2.0.
Upstream issue: [ROCm/llvm-project#2909](https://github.com/ROCm/llvm-project/issues/2909).

---

### `intel/` — ifx: Intel GPU (PVC) OpenMP target offload bugs

Four reproducers for `ifx` on Intel PVC (Aurora). See `intel/README.md` for details.
