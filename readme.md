## Compiler Bug Reproducers

Minimal reproducers for Fortran compiler bugs encountered in HPC workloads on OLCF Frontier.

---

### `test-bug1/` – `test-bug12/` — Cray CCE 15.0.1 Fortran + OpenACC

Module-scope global arrays and derived types under `!$acc declare`. Some pass, some fail.
Bug reports: **OLCFDEV-1416, CAST-31898**.

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

### `intel/` — ifx: Intel GPU (PVC) OpenMP target offload bugs

Four reproducers for `ifx` on Intel PVC (Aurora). See `intel/README.md` for details.
