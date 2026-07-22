## Compiler Bug Reproducers

Minimal Fortran reproducers for compiler bugs hit by HPC workloads, mostly from
[MFC](https://github.com/MFlowCode/MFC), across AMD, Cray and Intel toolchains. Each directory has
its own README with the full analysis; this page is only an index.

### AMD — amdflang / flang OpenMP offload (MI250X, MI300X, MI355X)

| case | upstream | downstream | state |
|---|---|---|---|
| [derived-type-mapper-hang](amd/derived-type-mapper-hang) | [llvm#209645](https://github.com/llvm/llvm-project/pull/209645) | [ROCm#3385](https://github.com/ROCm/llvm-project/issues/3385) | **merged**; cherry-pick requested |
| [openmp-module-gpu-triple](amd/openmp-module-gpu-triple) | [llvm#211138](https://github.com/llvm/llvm-project/pull/211138) | — | **merged** |
| [flang-array-coor-nuw-poison](amd/flang-array-coor-nuw-poison) | [llvm#198014](https://github.com/llvm/llvm-project/pull/198014) | [ROCm#3471](https://github.com/ROCm/llvm-project/issues/3471) | fixed upstream and in `amd-staging`; awaiting a drop |
| [no-loop-array-ops](amd/no-loop-array-ops) | [llvm#198621](https://github.com/llvm/llvm-project/issues/198621) | [ROCm#3058](https://github.com/ROCm/llvm-project/pull/3058) | fixed downstream; upstream issue open |
| [openmp-outlined-not-inlined](amd/openmp-outlined-not-inlined) | [llvm#211287](https://github.com/llvm/llvm-project/pull/211287), [llvm#211255](https://github.com/llvm/llvm-project/pull/211255) | [ROCm#3485](https://github.com/ROCm/llvm-project/pull/3485) | PRs open |
| [flang-firstprivate-array-occupancy](amd/flang-firstprivate-array-occupancy) | [llvm#203890](https://github.com/llvm/llvm-project/issues/203890) | [ROCm#2909](https://github.com/ROCm/llvm-project/issues/2909) | open; unbuildable on stock ROCm |
| [runtimes-fortran-modules-triple](amd/runtimes-fortran-modules-triple) | [llvm#211137](https://github.com/llvm/llvm-project/pull/211137) | — | PR open, awaiting review |
| [flang-ompx-attribute](amd/flang-ompx-attribute) | [llvm#211133](https://github.com/llvm/llvm-project/issues/211133) | — | RFC, no engagement |
| [flang-slice-assign-scratch-spill](amd/flang-slice-assign-scratch-spill) | — | — | fixed in AFAR 23.2.0 |
| [declare-target-static-tu](amd/declare-target-static-tu), [declare-target-roulette](amd/declare-target-roulette) | [llvm#203711](https://github.com/llvm/llvm-project/issues/203711) | [ROCm#2890](https://github.com/ROCm/llvm-project/issues/2890) | **not a bug**; closed |

- **derived-type-mapper-hang** — a per-component default mapper is emitted for a *flat* derived
  type; a `target` kernel then invokes it per element, busy-looping the host for minutes.
- **openmp-module-gpu-triple** — `openmp/module` gated `-nogpulib -flto` on `^amdgcn`, missing
  `amdgpu-amd-amdhsa`, which is the spelling the offload cache files use.
- **flang-array-coor-nuw-poison** — false `nuw`/`nusw` on descriptor-array addressing with negative
  bounds or reversed sections; WENO7 golden tests fail by 2.1e-4. Keep Frontier off 23.2.x.
- **no-loop-array-ops** — both oversubscription flags with no explicit `-O` skip a suffix of loop
  iterations in kernels using array expressions.
- **openmp-outlined-not-inlined** — the workshare-loop callback defeats `AAKernelInfo`, so
  `MayUseNestedParallelism` stays 1, the outlined region keeps two callsites and never earns the
  inliner's last-call-to-static bonus. ~2.3x registers, 60% less occupancy vs clang.
- **flang-firstprivate-array-occupancy** — `firstprivate` of an array, even one element, lowers
  through `_FortranAAssign`: ~35 KB/lane of scratch where it links, link error on stock ROCm.
- **runtimes-fortran-modules-triple** — the Fortran intrinsic-module probe ignores the target
  triple, so a GPU-targeted runtime tests the host, succeeds, and fails ~180 diagnostics later.
- **flang-ompx-attribute** — clang accepts `ompx_attribute`, flang rejects it at parse time, so
  Fortran offload cannot set per-kernel launch bounds or occupancy hints at all.
- **flang-slice-assign-scratch-spill** — whole-array slice assignment into a private array spilled
  ~20 KB/lane on AFAR 23.1.0; fixed in 23.2.0.
- **declare-target-\*** — resolved as expected OpenMP semantics: `declare target` SAVE variables
  have an infinite device refcount, so `map(to:)` no-ops. Use `target update to`.

[amd/NOT-BUGS.md](amd/NOT-BUGS.md) records leads investigated and found not to be compiler bugs.

### Cray — CCE Fortran, OpenACC and OpenMP offload (MI250X, Frontier)

| case | compiler | tracking | state |
|---|---|---|---|
| [cce/](cce) — 12 `!$acc declare` cases | CCE 15.0.1 | OLCFDEV-1416, CAST-31898 | reported |
| [cce/defaultmap-firstprivate](cce/defaultmap-firstprivate) | CCE 19.0.0 | OLCFHELP-26859 | reported |

- **cce/** — `!$acc declare link`/`create` on module-scope variables and nested allocatable derived
  types: non-unit lower bounds, multi-level nested structs, `routine seq` across translation units,
  and `default(present)` interactions. Twelve numbered cases plus an archive of fixed ones.
- **defaultmap-firstprivate** — scalars relying on `defaultmap(firstprivate:scalar)` instead of an
  explicit `private()` come out `NaN` on a register-heavy kernel, while naming the identical set in
  `private()` or `firstprivate()` is correct.

### Intel — ifx OpenMP target offload (GPU Max 1100, Ponte Vecchio)

| case | compiler | tracking | state |
|---|---|---|---|
| [intel/](intel) — 4 offload bugs | ifx 2025.1.1 | none filed | reproducers only |

- **bug1** — `matmul()` inside an `!$omp declare target` subroutine gives wrong results.
- **bug2** — an allocatable `declare target` module variable is inaccessible in a `declare target`
  function.
- **bug3** — mapping a nested pointer struct aborts at runtime; a workaround is included.
- **bug4** — an allocatable `declare target` module variable segfaults on the GPU.

### Adopted in MFC

[#1668](https://github.com/MFlowCode/MFC/pull/1668) (`-fopenmp-assume-no-nested-parallelism` on the
AMD offload path), [#1660](https://github.com/MFlowCode/MFC/pull/1660),
[#1628](https://github.com/MFlowCode/MFC/pull/1628),
[#1588](https://github.com/MFlowCode/MFC/pull/1588),
[#1572](https://github.com/MFlowCode/MFC/pull/1572).
