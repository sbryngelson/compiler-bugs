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
| [flang-firstprivate-array-occupancy](amd/flang-firstprivate-array-occupancy) | [llvm#203890](https://github.com/llvm/llvm-project/issues/203890), [llvm#211543](https://github.com/llvm/llvm-project/pull/211543) | [ROCm#2909](https://github.com/ROCm/llvm-project/issues/2909) | fix PR open, v3 after two review rounds matches only the canonical copy-in shape; upstream link failure fixed, downstream unverified |
| [flang-rt-device-unresolvable-refs](amd/flang-rt-device-unresolvable-refs) | — | [ROCm#3517](https://github.com/ROCm/llvm-project/issues/3517) | open; device Fortran links only at `-O3` |
| [runtimes-fortran-modules-triple](amd/runtimes-fortran-modules-triple) | [llvm#211137](https://github.com/llvm/llvm-project/pull/211137) | — | PR open; v2 routes CMake < 3.28 to `execute_process` per review, `try_compile` hunk dropped; rebased off a stale base to fix a phantom FreeBSD failure |
| [flang-reduction-dbg-verifier](amd/flang-reduction-dbg-verifier) | [llvm#211385](https://github.com/llvm/llvm-project/issues/211385), [llvm#211566](https://github.com/llvm/llvm-project/pull/211566) | — | fix is @abidh's reland #211566, verified locally; my #211395 went green then was closed in its favour. Symptom is latent at tip — the bad IR persists but no longer crashes |
| [openmpopt-spmd-assert](amd/openmpopt-spmd-assert) | [llvm#211423](https://github.com/llvm/llvm-project/issues/211423) | — | open; assertions builds only |
| [flang-linear-target-crash](amd/flang-linear-target-crash) | [llvm#211429](https://github.com/llvm/llvm-project/issues/211429) | — | open; device-only segfault |
| [flang-allocate-clause-crash](amd/flang-allocate-clause-crash) | [llvm#211430](https://github.com/llvm/llvm-project/issues/211430) | — | open; **not offload-specific** |
| [flang-defaultmap-firstprivate](amd/flang-defaultmap-firstprivate) | [llvm#211433](https://github.com/llvm/llvm-project/issues/211433) | — | open; not implemented |
| [flang-lastprivate-distribute](amd/flang-lastprivate-distribute) | [llvm#211401](https://github.com/llvm/llvm-project/issues/211401) | — | open; `simd` workaround |
| [flang-ompx-attribute](amd/flang-ompx-attribute) | [llvm#211133](https://github.com/llvm/llvm-project/issues/211133) | — | RFC, no engagement |
| [flang-slice-assign-scratch-spill](amd/flang-slice-assign-scratch-spill) | — | — | fixed in AFAR 23.2.0 |
| [declare-target-static-tu](amd/declare-target-static-tu), [declare-target-roulette](amd/declare-target-roulette) | [llvm#203711](https://github.com/llvm/llvm-project/issues/203711) | [ROCm#2890](https://github.com/ROCm/llvm-project/issues/2890) | **not a bug**; closed |

[amd/NOT-BUGS.md](amd/NOT-BUGS.md) records leads that were investigated and found not to be compiler bugs, plus one that is not yet established either way. It also records the AFAR build-time findings: 23.1.0 compiles MFC 3.1x slower than 23.2.1, which link-time levers do and do not work, and why flang device ThinLTO is blocked.

### Cray — CCE Fortran, OpenACC and OpenMP offload (MI250X, Frontier)

| case | compiler | tracking | state |
|---|---|---|---|
| [cce/](cce) — 12 `!$acc declare` cases | CCE 15.0.1 | OLCFDEV-1416, CAST-31898 | reported |
| [cce/defaultmap-firstprivate](cce/defaultmap-firstprivate) | CCE 19.0.0 | OLCFHELP-26859 | reported |

### Intel — ifx OpenMP target offload (GPU Max 1100, Ponte Vecchio)

| case | compiler | tracking | state |
|---|---|---|---|
| [intel/](intel) — 4 offload bugs | ifx 2025.1.1 | none filed | reproducers only |

### MFC changes driven by these

Merged: [#1660](https://github.com/MFlowCode/MFC/pull/1660) (reversed-stride WENO7 workaround for
the `nuw` miscompile), [#1588](https://github.com/MFlowCode/MFC/pull/1588) (host-capture viscosity
loss), [#1572](https://github.com/MFlowCode/MFC/pull/1572) (Riemann hot-path decomposition),
[#1668](https://github.com/MFlowCode/MFC/pull/1668)
(`-fopenmp-assume-no-nested-parallelism` on the AMD offload path).

Open: [#1628](https://github.com/MFlowCode/MFC/pull/1628).
