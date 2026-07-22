## Compiler Bug Reproducers

Minimal reproducers for Fortran compiler bugs hit by HPC workloads on OLCF Frontier, mostly from
[MFC](https://github.com/MFlowCode/MFC). Each directory has its own README with the full analysis;
this page is only an index.

### Status (2026-07-22)

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
| [cce/](cce) | — | OLCFDEV-1416, CAST-31898 | CCE 15/19 OpenACC + `defaultmap`; see `cce/README.md` |
| [intel/](intel) | — | — | ifx PVC offload; see `intel/README.md` |

[amd/NOT-BUGS.md](amd/NOT-BUGS.md) records leads that were investigated and turned out not to be
compiler bugs, so they are not re-derived.

### One line each

- **derived-type-mapper-hang** — flang emits a per-component default mapper for a *flat* derived
  type; a `target` kernel then invokes it per element, busy-looping the host for minutes.
- **openmp-module-gpu-triple** — `openmp/module` gated `-nogpulib -flto` on `^amdgcn`, missing
  `amdgpu-amd-amdhsa`, which is the spelling the offload cache files use.
- **flang-array-coor-nuw-poison** — false `nuw`/`nusw` on descriptor-array addressing with negative
  bounds or reversed sections; WENO7 golden tests fail by 2.1e-4. Keep Frontier off 23.2.x.
- **no-loop-array-ops** — both oversubscription flags with no explicit `-O` skip a suffix of loop
  iterations in kernels using array expressions.
- **openmp-outlined-not-inlined** — flang's workshare-loop callback defeats `AAKernelInfo`, so
  `MayUseNestedParallelism` stays 1, the outlined region keeps two callsites and never earns the
  inliner's last-call-to-static bonus. ~2.3x registers, 60% less occupancy vs clang.
- **flang-firstprivate-array-occupancy** — `firstprivate` of an array, even one element, lowers
  through `_FortranAAssign`: ~35 KB/lane of scratch where it links, and a link error on stock ROCm.
- **runtimes-fortran-modules-triple** — the Fortran intrinsic-module probe ignores the target
  triple, so a GPU-targeted runtime tests the host, succeeds, and fails ~180 diagnostics later.
- **flang-ompx-attribute** — clang accepts `ompx_attribute`, flang rejects it at parse time, so
  Fortran offload cannot set per-kernel launch bounds or occupancy hints at all.
- **flang-slice-assign-scratch-spill** — whole-array slice assignment into a private array spilled
  ~20 KB/lane on AFAR 23.1.0; fixed in 23.2.0.
- **declare-target-\*** — resolved as expected OpenMP semantics, not bugs: `declare target` SAVE
  variables have an infinite device refcount, so `map(to:)` no-ops. Use `target update to`.

### Adopted in MFC

[#1668](https://github.com/MFlowCode/MFC/pull/1668) (`-fopenmp-assume-no-nested-parallelism` on the
AMD offload path), [#1628](https://github.com/MFlowCode/MFC/pull/1628),
[#1660](https://github.com/MFlowCode/MFC/pull/1660).
