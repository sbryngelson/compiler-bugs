# flang/OpenMPIRBuilder: device-outlined target regions left un-inlined → ~2.3x registers, 60% less occupancy

Target: gfx90a (MI250X), also reproduced on gfx942/gfx950. Compiler: upstream flang/clang 24.0.0git
(`llvm/llvm-project @ 119b31fd3`, built with `clang;lld;mlir;flang` + `openmp/offload/flang-rt`
runtimes and an `amdgcn-amd-amdhsa` runtime target).

**Status: FIX POSTED.** Reported: [llvm/llvm-project#211132](https://github.com/llvm/llvm-project/issues/211132).
Fix: [llvm/llvm-project#211136](https://github.com/llvm/llvm-project/pull/211136).

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211132](https://github.com/llvm/llvm-project/issues/211132) — open |
| Fix PR | [#211136](https://github.com/llvm/llvm-project/pull/211136) — always-inline device-outlined regions |
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

## Fix

[llvm/llvm-project#211136](https://github.com/llvm/llvm-project/pull/211136) marks OpenMP outlined
regions `alwaysinline` on target devices in `OpenMPIRBuilder::finalize()`, behind hidden
`-openmp-ir-builder-device-always-inline-outlined` (default on). The function is still emitted, so
generic-execution-mode runtime entry points that take its address keep working. Result: 94 VGPR /
0 scratch / occupancy 5, and up to 1.32x throughput on a WENO5 + HLLC finite-volume kernel (best of
50, 1M cells, MI250X), output numerically identical:

| NEQ | before | after | gain |
|---|---|---|---|
| 8  | 2507.4 | 2520.4 | 1.01x |
| 16 | 1045.4 | 1381.7 | 1.32x |
| 24 |  720.6 |  793.3 | 1.10x |

`alwaysinline` is blunt (it inlines unconditionally on device, including generic mode and nested
parallelism). Two structural alternatives noted in the report if a maintainer prefers: teach the
inliner / AMDGPU TTI that leaving a device function outlined carries an occupancy cost so the trade
is *evaluated* rather than compared against a fixed threshold; or stop routing `private()` through a
by-pointer struct in `applyWorkshareLoopTarget`, which is what inflates the body to 1280 and would
additionally let SROA promote the arrays pre-link.

## Found in

[MFC](https://github.com/MFlowCode/MFC), a multiphase compressible-flow solver — the WENO + HLLC
finite-volume update on the AMD GPU offload build.
