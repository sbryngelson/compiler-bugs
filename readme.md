## Compiler Bug Reproducers

Minimal reproducers for Fortran compiler bugs encountered in HPC workloads on OLCF Frontier.

---

### `cce/` — Cray CCE 15.0.1 Fortran + OpenACC

Module-scope variables and nested allocatable derived types under `!$acc declare` (link/create).
12 reproducers + archived cases. Bug reports: **OLCFDEV-1416, CAST-31898**. See `cce/README.md`.

---

### `cce/defaultmap-firstprivate/` — CCE-19: `defaultmap(firstprivate:scalar)` doesn't firstprivate

On a register-heavy `target teams distribute parallel do simd` offload kernel, per-cell scalars left
off `private()` that rely on `defaultmap(firstprivate:scalar)` come out as `NaN` — yet listing the
same scalars in an explicit `private()` **or** `firstprivate()` clause is correct. Since defaultmap
is *defined* to make them firstprivate, the divergence from an explicit firstprivate of the identical
set is a compiler bug, not a semantic. Independent of `simd` and optimization level; needs enough
omitted scalars to spill (which is how it hid in MFC until an added `firstprivate` raised register
pressure). CCE 19.0.0. See `cce/defaultmap-firstprivate/README.md`.

---

### `amd/no-loop-array-ops/` — amdflang: wrong results with `-fopenmp-target-fast` + array expressions — **FIXED**

Array constructor and whole-array slice ops inside `!$omp target` kernels produce wrong results
when `-fopenmp-target-fast` and both oversubscription flags are present.
Root cause: `no_loop` exec mode hoists `omp_get_num_threads()` before the parallel region is set up,
yielding stride=1 instead of 32 — threads K+31..N-1 are never assigned.
Fixed upstream: [ROCm/llvm-project#3058](https://github.com/ROCm/llvm-project/pull/3058) (merged into
`amd-staging` 2026-06-25, re-landing [#2602](https://github.com/ROCm/llvm-project/pull/2602)).
Reported in [ROCm/llvm-project#2601](https://github.com/ROCm/llvm-project/issues/2601) and
[llvm/llvm-project#198621](https://github.com/llvm/llvm-project/issues/198621) (upstream, still open).

---

### `amd/declare-target-static-tu/` — amdflang: static `declare target` variable stale across translation units — **NOT A BUG**

A static (non-allocatable) `!$omp declare target` module variable appeared not to be unified
across TUs on the device. Diagnosed by AMD as expected OpenMP semantics: a `declare target` SAVE
variable has an infinite device reference count, so `map(to:)` / `target enter data map(to:)`
no-ops on the presence check — it never re-copies. `target update to` (or `map(always,to:)`) is
the correct way to push a new value. Confirmed and closed as working-as-intended; CCE/nvfortran
happened to copy on `map(to:)` here too, which is what made the AMD behavior look like a bug.
Reports (closed, not planned): [ROCm/llvm-project#2890](https://github.com/ROCm/llvm-project/issues/2890),
[llvm/llvm-project#203711](https://github.com/llvm/llvm-project/issues/203711).

---

### `amd/declare-target-roulette/` — amdflang: identical `declare target` arrays disagree in one kernel — **NOT A BUG**

A sharper form of the same case above: two *identical* static `!$omp declare target` arrays,
both host-set to 2, read by the *same* kernel, return *different* values (`0` vs `2`) — because
one was pushed with `enter data map(to:)` (no-op due to infinite refcount) and the other with
`update to` (always copies). Same root cause and same resolution as
`declare-target-static-tu/` — use `target update to` / `map(always,to:)` for `declare target`
SAVE variables. Same reports
([ROCm/llvm-project#2890](https://github.com/ROCm/llvm-project/issues/2890),
[llvm/llvm-project#203711](https://github.com/llvm/llvm-project/issues/203711)).

---

### `amd/flang-firstprivate-array-occupancy/` — amdflang: `firstprivate` of a small array spills to scratch — **OPEN**

A `firstprivate` clause on a small fixed-size integer array (8 bytes) on a register-heavy
`target teams distribute parallel do` kernel spills ~20-35 KB/work-item to scratch, pins AGPRs at
the hardware maximum, and drops occupancy to one wave per SIMD — a 30-50x slowdown. The same two
integers passed as scalars, or as a plain `private` array seeded from those scalars, cost nothing.
Isolation (constant-indexed firstprivate array still spills; dynamically-indexed *private* array
does not) shows the trigger is `firstprivate` of an array, not the indexing. The copy-in is lowered
through the Fortran array-assignment runtime (`_FortranAAssign`) rather than a value copy:
undefined device symbol on ROCm 7.2.0, a scratch-spilling blob on afar 23.1.0/23.2.0 and the
2026-06-12 ROCm nightly. AMD's first attempted fix
([llvm/llvm-project#204466](https://github.com/llvm/llvm-project/pull/204466)) only gates
*implicit* firstprivate promotion and was verified **not** to fix this *explicit*
`firstprivate(array)` case; AMD is now routing it to their internal team.
Bug reports (open): [ROCm/llvm-project#2909](https://github.com/ROCm/llvm-project/issues/2909),
[llvm/llvm-project#203890](https://github.com/llvm/llvm-project/issues/203890).

---

### `intel/` — ifx: Intel GPU (PVC) OpenMP target offload bugs

Four reproducers for `ifx` on Intel PVC (Aurora). See `intel/README.md` for details.
