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
| [no-loop-array-ops](amd/no-loop-array-ops) | [llvm#198621](https://github.com/llvm/llvm-project/issues/198621) | [ROCm#3058](https://github.com/ROCm/llvm-project/pull/3058) | fixed downstream; **upstream issue correctly still open**. Reproduced 2026-08-03 on **gfx90a, gfx942 and gfx950** (MI250X / MI300X / MI355X) with AFAR 23.1.0 and 23.2.0: `FAIL: 31 of 64` identically on all three, so it is live on current silicon, not legacy-only. Upstream `DistributeFor` still lacks the `getMaxTeamThreads()` override ROCm#3058 added, and `OMPIRBuilder` still feeds it `omp_get_num_threads()` |
| [openmp-outlined-not-inlined](amd/openmp-outlined-not-inlined) | [llvm#211287](https://github.com/llvm/llvm-project/pull/211287), [llvm#211255](https://github.com/llvm/llvm-project/pull/211255) | [ROCm#3485](https://github.com/ROCm/llvm-project/pull/3485) | **reverted 2026-08-05**: #211287 merged by @shiltian 2026-08-03 (`4905109b00e6`) and #211132 closed, then [llvm#214278](https://github.com/llvm/llvm-project/pull/214278) reverted it (`b9bb539fa3cd`) over a null-pointer GPU fault in UMT; not relanded, so the defect is live again. #211255 is a separate correctness fix, approved by @arsenm and still awaiting a committer. ROCm#3485 (back out the downstream `alwaysinline`) merged 2026-08-04 |
| [flang-firstprivate-array-occupancy](amd/flang-firstprivate-array-occupancy) | [llvm#209539](https://github.com/llvm/llvm-project/pull/209539), [llvm#203890](https://github.com/llvm/llvm-project/issues/203890), [llvm#211543](https://github.com/llvm/llvm-project/pull/211543) | [ROCm#2909](https://github.com/ROCm/llvm-project/issues/2909) | **fixed upstream** by @bhandarkar-pranav's #209539 (`e949b654424b`, 2026-07-24) at the alias-analysis layer; my #203890 and redundant #211543 both closed against it. Only the upstream link failure is verified — the AFAR scratch spill awaits a drop, tracked on ROCm#2909 |
| [flang-rt-device-unresolvable-refs](amd/flang-rt-device-unresolvable-refs) | — | [ROCm#3517](https://github.com/ROCm/llvm-project/issues/3517) | open; device Fortran links only at `-O3` |
| [runtimes-fortran-modules-triple](amd/runtimes-fortran-modules-triple) | [llvm#211137](https://github.com/llvm/llvm-project/pull/211137) | — | **merged** by @Meinersbur 2026-08-03 (`1674a1c6da08`); #211134 closed. Sat approved 11 days until a committer was asked. v2 routes CMake < 3.28 to `execute_process` per review, `try_compile` hunk dropped; rebased off a stale base to fix a phantom FreeBSD failure |
| [flang-reduction-dbg-verifier](amd/flang-reduction-dbg-verifier) | [llvm#211385](https://github.com/llvm/llvm-project/issues/211385), [llvm#211566](https://github.com/llvm/llvm-project/pull/211566) | — | **merged** (@abidh's reland, `3d69ace09ec4`, 2026-07-24); #211385 closed. My #211395 went green then was closed in its favour. Symptom was latent at tip — bad IR persisted but no longer crashed |
| [openmpopt-spmd-assert](amd/openmpopt-spmd-assert) | [llvm#211423](https://github.com/llvm/llvm-project/issues/211423) | — | open; assertions builds only |
| [flang-linear-target-crash](amd/flang-linear-target-crash) | [llvm#211429](https://github.com/llvm/llvm-project/issues/211429) | — | open; **root-caused**, posted 2026-08-04, no patch: `applyWorkshareLoopTarget` never sets `lastiter`, so MLIR's `linear` finalization asserts on it. Device-only, version-independent |
| [flang-allocate-clause-crash](amd/flang-allocate-clause-crash) | [llvm#211430](https://github.com/llvm/llvm-project/issues/211430), fixes [llvm#214012](https://github.com/llvm/llvm-project/pull/214012) (**merged**), [llvm#213980](https://github.com/llvm/llvm-project/pull/213980) (**merged**) | — |  **not offload-specific**; **root-caused, both PRs merged**: `allocate` ungated in `OMP.td` so it is accepted below 5.0, then decomposition fails and lowering reads uninitialized memory (ASLR-dependent: 25/40 vs 0/40). PR gates the clause in `OMP.td`; clang uses the same table and has accepted `allocate` below 5.0 for years, so this is a cross-frontend change, not a flang fix. The 83 clang tests that failed were converted 2026-08-05 (four distinct patterns) and it is now **green on all four platforms**, approved by kparzysz with alexey-bataev confirming the clang side. The earlier local clang pass that cleared it was a stale binary |
| [flang-defaultmap-firstprivate](amd/flang-defaultmap-firstprivate) | [llvm#211433](https://github.com/llvm/llvm-project/issues/211433) | — | open; not implemented |
| [flang-lastprivate-distribute](amd/flang-lastprivate-distribute) | [llvm#211401](https://github.com/llvm/llvm-project/issues/211401) | — | open; `simd` workaround |
| [flang-ompx-attribute](amd/flang-ompx-attribute) | [llvm#211133](https://github.com/llvm/llvm-project/issues/211133) | — | RFC, no engagement |
| [flang-slice-assign-scratch-spill](amd/flang-slice-assign-scratch-spill) | — | — | fixed in AFAR 23.2.0 |
| [declare-target-static-tu](amd/declare-target-static-tu), [declare-target-roulette](amd/declare-target-roulette) | [llvm#203711](https://github.com/llvm/llvm-project/issues/203711) | [ROCm#2890](https://github.com/ROCm/llvm-project/issues/2890) | **not a bug**; closed |

[amd/NOT-BUGS.md](amd/NOT-BUGS.md) records leads that were investigated and found not to be compiler bugs, plus one that is not yet established either way. It also records the AFAR build-time findings: 23.1.0 compiles MFC 3.1x slower than 23.2.1, which link-time levers do and do not work, and why flang device ThinLTO is blocked.

### Cray — CCE Fortran, OpenACC and OpenMP offload (MI250X, Frontier)

| case | compiler | tracking | state |
|---|---|---|---|
| [cce/archive/acc-declare-cce15](cce/archive/acc-declare-cce15) — 12 `!$acc declare` cases | CCE 15.0.1 | OLCFDEV-1416, CAST-31898 | **archived** — reported long ago; status on modern compilers unknown because none self-check |
| [cce/defaultmap-firstprivate](cce/defaultmap-firstprivate) | CCE 19.0.0 | OLCFHELP-26859 | reported |
| [cce/promote-alloca-dropped-store](cce/promote-alloca-dropped-store) | CCE 21.0.2 | filed via OLCF, case ID pending | **open, wrong answers**; a dynamically-indexed store into a **1-based** private array is silently discarded by `AMDGPUPromoteAllocaToVector` — no crash, no diagnostic. 24-line Fortran reproducer; controls isolate the lower bound of 1 as the trigger. Corrupted MFC's viscous flux by ~25% of the term |
| [cce/omp-defaultmap-scalar-override](cce/omp-defaultmap-scalar-override) | CCE 21.0.2 | filed via OLCF, case ID pending | **open, wrong answers**; an explicit `map(to:)` on a scalar is overridden when the same directive carries `defaultmap(...:scalar)`, so `atomic capture` hands 4095 of 4096 iterations a duplicate index. `-h omp` only — the OpenACC equivalent is correct. **Distinct from `defaultmap-firstprivate` above**, which is CCE 19 and the opposite direction |
| [cce/defaultmap-zeroes-resident-arrays](cce/defaultmap-zeroes-resident-arrays) | CCE 21.0.2 | filed via OLCF, case ID pending | **open, wrong answers**; an array made device-resident and pushed with `target update to` reads back as **all zeros** inside a `target` region whenever the directive carries *any* `defaultmap` clause. Each of the three clauses reproduces alone, including on a bare module array under `defaultmap(present:pointer)`. Very likely the same root cause as `omp-defaultmap-scalar-override`. Removing the clause took MFC's OpenMP suite from 566/627 with 60 aborts to 622/627 with zero |
| [cce/defaultmap-overrides-private](cce/defaultmap-overrides-private) | CCE 21.0.2 | filed via OLCF, case ID pending | open; `defaultmap(present:aggregate)` makes an array that is **explicitly listed in `private()`** be looked up in the present table, aborting with `find_in_present_table failed`. Third face of the same defect as [omp-defaultmap-scalar-override](cce/omp-defaultmap-scalar-override) and [defaultmap-zeroes-resident-arrays](cce/defaultmap-zeroes-resident-arrays) — `defaultmap` overriding an explicit specification, here `private` instead of `map` or residency |
| [cce/explicit-shape-dummy-lost-writes](cce/explicit-shape-dummy-lost-writes) | CCE 21.0.2 (also 19.0.0) | filed via OLCF, case ID pending | **open, wrong answers**; device writes through an **explicit-shape** dummy with a runtime extent (`dimension(n_gp)`) never reach the host — every element wrong, no diagnostic. `-h omp` only; the OpenACC arm passes both shapes, which is what makes it reportable. Assumed-shape `dimension(:)` is the workaround. The mapping is provably *not* the difference, and neither is the launch geometry — no mechanism established |
| [cce/private-flat-pointer](cce/private-flat-pointer) | CCE 19.0.0 **and** 21.0.2 | filed via OLCF, case ID pending | **open**; the front end builds a flat pointer from a private frame offset without the aperture, so an object at offset 0 casts to `0xFFFFFFFF` and stores 4 GiB out of bounds. Not a back-end regression — both compilers emit it, and whether a build faults depends only on frame layout. CCE 19 was lucky, not correct |
| [cce/contiguous-mix-dropped-stores](cce/contiguous-mix-dropped-stores) | CCE 19.0.0 | filed via OLCF, case ID pending | **fixed in CCE 20.0.0**; stores to a non-`contiguous` dummy dropped when the same call also passes a `contiguous` one. Host code, no offload. Workaround in MFC [#1679](https://github.com/MFlowCode/MFC/pull/1679) |
| [cce/lld-agpr-mfma-assert](cce/lld-agpr-mfma-assert) | CCE 21.0.0, 21.0.2 | filed via OLCF, case ID pending | **open**; `lld` asserts in `AMDGPU Rewrite AGPR-Copy-MFMA` during device LTO. All sources compile; only the link dies. Both `-h omp` and `-h acc`. `-plugin-opt=O1` still crashes, only `O0` avoids it. Blocks MFC on all of CCE 21.x | Its only workaround (`-mattr=-mai-insts`) disables AGPRs on gfx90a's unified register file: standalone reproducer shows 29x more scratch (36 B -> 1060 B), and MFC's most register-hungry kernel regresses 61%. Same on ROCm 7.0.2 and 7.2.0.
| [cce/lld-infer-address-spaces-cce20](cce/lld-infer-address-spaces-cce20) | CCE 20.0.2 | filed via OLCF, case ID pending | **open**; `lld` heap-corrupts in `Infer address spaces` during device LTO (`malloc_consolidate(): unaligned fastbin chunk`). Reproduced on **stock upstream MFC** via a reverted-patch control. Together with the 21.x bug, no CCE > 19 can link MFC on Frontier |
| [cce/inlinenever-ignored-device](cce/inlinenever-ignored-device) | CCE 21.0.2 | filed via OLCF, case ID pending | **open**, silent no-op; `!DIR$ INLINENEVER` on a routine that is also `!$acc routine seq` is accepted without diagnostic, then emitted with **`alwaysinline`** and inlined anyway. 35-line reproducer, verified from the device image (no `s_leaf` symbol, zero call instructions). Removes the only documented lever for dodging inlining-triggered backend bugs — it is what forced a plugin-flag workaround for [instcombine-phi-addrspace-cast](cce/instcombine-phi-addrspace-cast) instead of a one-line source fix, and it silently disabled 51 existing `cray_noinline` sites in MFC |
| [cce/mir-roundtrip-bb-name](cce/mir-roundtrip-bb-name) | CCE 21.0.2 (LLVM 21.1.8) | filed via OLCF, case ID pending | **open**, minor; `llc` prints MIR block labels its own parser rejects when the Fortran block name contains a comma (`bb.0., bb71:`). Blocks MIR-level reduction |

### Intel — ifx OpenMP target offload (GPU Max 1100, Ponte Vecchio)

| case | compiler | tracking | state |
|---|---|---|---|
| [intel/](intel) — 4 offload bugs | ifx 2025.1.1 | filed via OLCF, case ID pending | reproducers only |

### MFC changes driven by these

Merged: [#1660](https://github.com/MFlowCode/MFC/pull/1660) (reversed-stride WENO7 workaround for
the `nuw` miscompile), [#1588](https://github.com/MFlowCode/MFC/pull/1588) (host-capture viscosity
loss), [#1572](https://github.com/MFlowCode/MFC/pull/1572) (Riemann hot-path decomposition),
[#1668](https://github.com/MFlowCode/MFC/pull/1668)
(`-fopenmp-assume-no-nested-parallelism` on the AMD offload path).

Open: [#1628](https://github.com/MFlowCode/MFC/pull/1628).


## Headline: two CCE 21 defects have upstream fixes that predate CCE's own merge cutoff

CCE 21.0.2 is built on `llvmorg-21.1.8` (its module `help` text states *"merges up to Dec 12,
2025"*). Two of its three back-end defects were already fixed upstream **before** that date:

| defect | upstream fix | landed | vs cutoff |
|---|---|---|---|
| [AGPR-Copy-MFMA assert](cce/lld-agpr-mfma-assert) | [`30007a541493`](https://github.com/llvm/llvm-project/pull/153915) | 2025-08-16 | 4 months before |
| [promote-alloca dropped store](cce/promote-alloca-dropped-store) | [`b965f265388a`](https://github.com/llvm/llvm-project/pull/157682) | 2025-09-10 | 3 months before |
| [InstCombine PHI addrspace cast](cce/instcombine-phi-addrspace-cast) | [`6d033abb7`](https://github.com/llvm/llvm-project/pull/181064) | 2026-02-15 | 2 months after |

Verifiable in one command each, since `llvmorg-21.1.8` is a real tag:

```console
$ git merge-base --is-ancestor 30007a541493 llvmorg-21.1.8   # false -- absent from CCE's base
$ git merge-base --is-ancestor 30007a541493 llvmorg-22.1.0   # true
```

The AGPR one matters most: its absence forces `-mattr=-mai-insts`, which disables AGPRs on
gfx90a's unified register file and costs **29x scratch** and a **61% slowdown** on a real
solver. Three lines of upstream code recover it.

See [cce/](cce) for the full status table, including the five defects that are CCE's own and
have no upstream fix.

## Upstream LLVM

Defects reproducing on stock upstream LLVM rather than a vendor fork — filed with
llvm/llvm-project, not with HPE/AMD/Intel. See [llvm/](llvm).

| entry | version(s) | status | summary |
|---|---|---|---|
| [llvm/mir-unquoted-bb-name](llvm/mir-unquoted-bb-name) | LLVM 21.1.8 and 22.0.0 | **[llvm#212785](https://github.com/llvm/llvm-project/issues/212785)** | `llc` emits MIR it cannot re-parse when a basic-block name contains a comma. 14-line reproducer; blocks MIR-level bug reduction |
| [flang-device-ordered](amd/flang-device-ordered) | [llvm#214257](https://github.com/llvm/llvm-project/issues/214257), fix [llvm#214263](https://github.com/llvm/llvm-project/pull/214263) | — | **wrong results**: `ordered` in a target region orders nothing. Correct on host and in C under clang on the same GPU. Fix emits a dispatch loop on device |
| [devicertl-noloop-numthreads](amd/devicertl-noloop-numthreads) | [llvm#198621](https://github.com/llvm/llvm-project/issues/198621), fix [llvm#214073](https://github.com/llvm/llvm-project/pull/214073) | [ROCm#3058](https://github.com/ROCm/llvm-project/pull/3058) | **wrong results**: SPMD no-loop distribute uses the caller's NumThreads instead of the block size and drops iterations. Reproduced upstream in C by calling the runtime entry directly |
| [mir-bb-name-quoting](llvm/mir-bb-name-quoting) | [llvm#212785](https://github.com/llvm/llvm-project/issues/212785), fix [llvm#214054](https://github.com/llvm/llvm-project/pull/214054) | — | `llc` emits MIR block names it cannot parse back when the name has a comma |
| [flang-unroll-full](llvm/flang-unroll-full) | [llvm#214114](https://github.com/llvm/llvm-project/issues/214114), fix [llvm#214115](https://github.com/llvm/llvm-project/pull/214115) | — | `!$omp unroll full` was unimplemented; adds `omp.unroll_full` plus the two clause rules clang enforces |
| [flang-critical-device](llvm/flang-critical-device) | [llvm#214965](https://github.com/llvm/llvm-project/issues/214965), fix [llvm#215009](https://github.com/llvm/llvm-project/pull/215009) | — | **wrong results**: `critical` in a target region does not serialize the lanes of a wavefront, so the count equals the wavefront count. clang is correct via `CGOpenMPRuntimeGPU`. Fix adds the same turn loop to `createCritical` |
| [flang-declare-target-cross-tu](llvm/flang-declare-target-cross-tu) | [llvm#212333](https://github.com/llvm/llvm-project/issues/212333), fix [llvm#213930](https://github.com/llvm/llvm-project/pull/213930) | — | `declare target` module variable internalized per-TU, so a device routine in another TU reads `undef`; silent wrong answer. Regression from llvm#208188. **My llvm#214586 / llvm#214596 were duplicates**, closed 2026-08-07; kept for the reproducer and two dead-end gates |
| [flang-device-schedule](amd/flang-device-schedule) | [llvm#214303](https://github.com/llvm/llvm-project/issues/214303) | — | `schedule(static,C)` ignored on device; mapping is always `static,1`. Same dropped-arguments line as llvm#214257 |
