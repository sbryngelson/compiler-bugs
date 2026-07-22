# flang/OpenMPIRBuilder: device-outlined target regions left un-inlined → ~2.3x registers, 60% less occupancy

Target: gfx90a (MI250X), also reproduced on gfx942/gfx950. Compiler: upstream flang/clang 24.0.0git
(`llvm/llvm-project @ 119b31fd3`, built with `clang;lld;mlir;flang` + `openmp/offload/flang-rt`
runtimes and an `amdgcn-amd-amdhsa` runtime target).

**Status (2026-07-22): OPEN, fix rerouted.** Reported: [llvm/llvm-project#211132](https://github.com/llvm/llvm-project/issues/211132) (open).
The original `alwaysinline` fix [llvm/llvm-project#211136](https://github.com/llvm/llvm-project/pull/211136)
was **closed without merging**. Superseded by two narrower PRs, both open:
[#211255](https://github.com/llvm/llvm-project/pull/211255) — an independent correctness fix, not a
fix for #211132; don't apply the reduced cold-callsite inline threshold in non-callable functions, i.e.
hardware entry points such as GPU kernels, where an out-of-line call is register allocated against the
whole kernel's worst case and so costs the hot path too. Keyed off the existing
`CallingConv::isCallableCC`, so it covers `SPIR_KERNEL` and `PTX_Kernel` as well; an earlier version
added a TTI hook and was rejected in review.
[#211287](https://github.com/llvm/llvm-project/pull/211287) — *fixes* #211132; `AAKernelInfo` resolves
the loop-body callback of the `__kmpc_*_static_loop_*` entries (a direct function operand) instead of
treating it as opaque. Also removes the trigger for
[#198621](https://github.com/llvm/llvm-project/issues/198621).

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211132](https://github.com/llvm/llvm-project/issues/211132) — open |
| Fix PR | [#211287](https://github.com/llvm/llvm-project/pull/211287) — resolve the static-loop callback in `AAKernelInfo` |
| Withdrawn | [#211136](https://github.com/llvm/llvm-project/pull/211136) — always-inline device-outlined regions (closed unmerged) |
| Source | [MFC](https://github.com/MFlowCode/MFC) |

## Bug

flang lowers the body of an OpenMP `target teams distribute parallel do` into a separate AMDGPU
device function, and the inliner then declines to fold it back into the kernel:

```
$ flang -fopenmp --offload-arch=gfx90a -O3 outlined_region.f90 -o /dev/null \
    -Xoffload-linker -mllvm=-pass-remarks-missed=inline
'__omp_offloading_..._kern__l23..omp_par.2' not inlined into '__omp_offloading_..._kern__l23'
    because too costly to inline (cost=1280, threshold=495)
```

The outlined device function is then register-allocated and scheduled *without* the enclosing
kernel's occupancy target. clang's device codegen for the identical algorithm ends up fully
inlined. gfx90a, full driver, `-Rpass-analysis=kernel-resource-usage`:

| toolchain | VGPRs | scratch | occupancy |
|---|---|---|---|
| flang 24.0.0git | 212 | 48 B | 2 |
| clang, C equivalent | 80 | 0 | 6 |

The 48 B is the argument struct used to reach the outlined function. In the final post-link device
IR (`0.5.precodegen`) flang leaves one non-intrinsic call and two allocas in the kernel; clang
leaves none of either.

## Root cause

The inline cost of 1280 comes from `OpenMPIRBuilder::applyWorkshareLoopTarget`, taken
unconditionally on device (`if (Config.isTargetDevice()) return applyWorkshareLoopTarget(...)`). It
outlines the loop body and passes `private()` variables by pointer through a struct to
`__kmpc_distribute_for_static_loop_4u`. clang instead emits
`__kmpc_distribute_static_init_4` / `__kmpc_for_static_init_4` with the loop inline. The pointer
indirection keeps the outlined body above the fixed 495 threshold.

The private arrays *do* stay in scratch, but that is not the cause. Same run, `base` vs
`-mllvm -unroll-threshold=3000`: both give 212/48/2, with the `[16 x double]` allocas going 2 → 0.
Promoting the arrays does not move the resource numbers. With the fix the numbers reach 94/0/5
while the arrays remain unpromoted. Also no-ops: `-unroll-threshold` pre-link and LTO,
`-amdgpu-unroll-threshold-private=5000`, `-inline-threshold=5000` and `=100000`.
`-amdgpu-unroll-threshold-private=100` reaches 100 VGPRs but 312 B scratch — trading registers for
scratch, not a fix.

Note `--offload-device-only -S` is *not* representative: clang shows 64 B scratch there vs 0 after a
real link. The linker-wrapper LTO stage is decisive, so all numbers above are full-driver.

## Reproducer

`outlined_region.f90` and its line-for-line C control `outlined_region.c` — identical arithmetic
and loop structure. The kernel is a small register-heavy blob (`[16]` private arrays + a dependent
FP chain) so nothing folds away, mirroring a finite-volume Riemann kernel.

```
./build.sh    # prints per-kernel resource usage for both, plus the inliner miss
```

No compute node needed — the defect is a compile-time inliner decision, visible from
`-Rpass-analysis=kernel-resource-usage` on a login node.

## Root cause

Two earlier attributions here were wrong and are recorded so they are not repeated: it is **not** that
the body is too costly to inline, and it is **not** the by-pointer `private()` struct — that accounts
for 720 of the cost and is irrelevant to the outcome.

flang's device workshare loop passes the loop body to the runtime as a function pointer
(`__kmpc_for_static_loop_4u`, or `__kmpc_distribute_for_static_loop_4u` with `distribute`). OpenMPOpt's
`AAKernelInfo` treats that callback as opaque and records an unknown parallel region, per a TODO at the
site. So `MayUseNestedParallelism` stays 1 in the kernel environment, where clang — which emits the loop
inline with `__kmpc_for_static_init_4` — gets 0. At 1, `config::mayUseNestedParallelism()` does not
fold, the serialized branch of `__kmpc_parallel_60` stays live carrying its own microtask call, and once
that `always_inline` function lands in the kernel there are **two** calls to the outlined region instead
of one. `isSoleCallToLocalFunction` is then false, so `LastCallToStaticBonus` never applies — 15000 × 11
= 165000 on AMDGPU. Same callee, same module:

| | starting inline cost |
|---|---|
| two callsites | −45 |
| one callsite  | **−165045** |

With one callsite it inlines unconditionally and the threshold is irrelevant. The `cost=1280,
threshold=495` above is a symptom of the missing bonus, not the cause.

Controlled pair, same parallel construct, flang, gfx90a:

| construct | runtime loop entry | MayUseNestedParallelism |
|---|---|---|
| `!$omp target parallel`    | none                       | 0 |
| `!$omp target parallel do` | `__kmpc_for_static_loop_4u` | 1 |

## Fix

[llvm/llvm-project#211287](https://github.com/llvm/llvm-project/pull/211287) resolves the callback (a
direct function operand) and consults its `AAKernelInfo`, as the `__kmpc_parallel_60` handling already
does for its parallel-region operand. Result on gfx90a: 212 / 48 B / 2 → **94 / 0 / 5**, matching what
`alwaysinline` achieved. On gfx942 at NEQ=8/16/24: 196/64/2 → 110/0/4, 214/328/2 → 138/0/3,
196/456/2 → 110/392/4.

The withdrawn `alwaysinline` approach ([#211136](https://github.com/llvm/llvm-project/pull/211136)) is
what [ROCm/llvm-project#3485](https://github.com/ROCm/llvm-project/pull/3485) is backing out downstream:
forcing the body inline grows the kernel past the AMDGPU inliner's basic-block budget, so
`__kmpc_target_init` stops being specialized and SPMD kernels inherit a module-wide worst-case
`amdgpu.max_num_vgpr`. Restricting it to the workshare-loop outline and leaving the parallel outline
alone was tried and gives no benefit at all (212/48/2, unchanged), so the two cases cannot be separated
by construct.

## Workaround (no compiler change)

`-fopenmp-assume-no-nested-parallelism`, or `-fopenmp-assume-no-thread-state` — either alone suffices.
Both set a module-level global that short-circuits the check before the kernel environment is read.
Measured against MFC's own flag set (which already carries both oversubscription flags), within a single
job, checksums bit-identical:

| NEQ | gfx90a | gfx942 |
|---|---|---|
| 8  | 1.21x | 1.85x |
| 16 | 1.34x | 2.72x |
| 24 | 1.08x | 1.32x |

Verified not to trigger [#198621](https://github.com/llvm/llvm-project/issues/198621) on AFAR 23.2.0 or
23.2.1, upstream flang, or amdflang 22 (ROCm 7.2.0) — including in the no-`-O` configuration where the
oversubscription pair does fail. Adopted in MFC's `cmake/MFCTargets.cmake`; MFC's golden-file suite is
unchanged by it (568 passed / 21 failed with and without, identical failing set, all pre-existing
`weno_order=7` cases from the AFAR 23.2.x `nuw` miscompile).

## Found in

[MFC](https://github.com/MFlowCode/MFC), a multiphase compressible-flow solver — the WENO + HLLC
finite-volume update on the AMD GPU offload build.
