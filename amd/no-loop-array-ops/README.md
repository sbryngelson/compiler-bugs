# amd-flang-omp-bugs

Minimal reproducers for AMD flang OpenMP target offload bugs found in MFC.
Target hardware: gfx90a (MI250X). Compiler: amdflang 23.1.0–23.2.1 (therock-afar, ROCm 7.12–7.13).

**Status: FIXED upstream.** Landed via [ROCm/llvm-project#3058](https://github.com/ROCm/llvm-project/pull/3058)
(merged into `amd-staging` 2026-06-25), re-landing the patch originally submitted as
[#2602](https://github.com/ROCm/llvm-project/pull/2602). Still open upstream at
[llvm/llvm-project#198621](https://github.com/llvm/llvm-project/issues/198621).

## Bugs reproduced below (now fixed in amd-staging)

### `minimal_array_constructor.f90`

```fortran
!$omp target teams distribute parallel do map(from:out)
do i = 1, N
    out(i,:) = [i, i*2]      ! array constructor → wrong values
end do
```

### `minimal_whole_array_ops.f90`

```fortran
!$omp target teams distribute parallel do map(to:A) map(from:out)
do i = 1, N
    out(i,:) = 2 * A(i,:)    ! whole-array slice op → wrong values
end do
```

Both use only integers, no private clause, no modules. Both fail with:
```
FAIL: 31 of 64
```

### Trigger flags

```sh
amdflang -fopenmp --offload-arch=gfx90a \
  -fopenmp-assume-threads-oversubscription \
  -fopenmp-assume-teams-oversubscription \
  -fopenmp-target-fast \
  -o minimal minimal_array_constructor.f90
```

**All three must be present.** `-O0` through `-O3` without `-fopenmp-target-fast` pass. Either oversubscription flag alone passes. Scalar assignments pass at any N.

### Quantitative signature

```
N_wrong = max(0,  N − (⌈N/32⌉ + 31))
```

| N | N_wrong |
|---|---------|
| ≤ 33 | 0 (PASS) |
| 34 | 1 |
| 64 | 31 |
| 96 | 62 |
| 128 | 93 |
| 256 | 217 |

Wrong cells always contain **zero** (never written). Same cells fail every run — deterministic, not a race condition. First failing iteration is always i=34 for N=64.

---

## Root cause

**Five-step cause chain:**

**1.** `-fopenmp-target-fast` implies both oversubscription flags. Together they cause `canPromoteToNoLoop` (`mlir/lib/Dialect/OpenMP/IR/OpenMPDialect.cpp:2748`) to return `true`, promoting the kernel to `TargetExecMode::no_loop` (exec_mode=6).

**2.** `no_loop` mode causes `OMPIRBuilder.cpp:6150` to emit `one_iteration_per_thread=i8 1` as a **compile-time constant** in the call to `__kmpc_distribute_for_static_loop_4u`, disabling the strided iteration loop in the DeviceRTL.

**3.** Array expression kernels (constructors, slice ops) require device `malloc` for implicit temporaries, linking in the AMD device stdlib. With the stdlib present, LTO cannot prove no nested parallel state changes, so `MayUseNestedParallelism` stays `1` in `KernelEnvironmentTy`. Simple scalar kernels have this folded to `0`.

**4.** With `MayUseNestedParallelism=1`, LTO cannot replace `omp_get_num_threads()` with a hardware register read. The call is preserved but **hoisted to kernel entry** — before `__kmpc_parallel_spmd` has set up the active parallel region (`icv::Level=0`). At that point, `omp_get_num_threads()` returns **1** instead of the actual blocksize (32).

**5.** The no-loop fast path computes:
```
flat_id = workgroup_id × omp_get_num_threads() + thread_id
        = workgroup_id × 1 + thread_id          (stride=1, should be 32)
```
With K=⌈N/32⌉ blocks, coverage is flat_ids `0..(K+30)`. Flat_ids `K+31..N−1` are never assigned — those iterations never execute.

**Why scalar is immune:** `MayUseNestedParallelism=0` allows LTO to replace `omp_get_num_threads()` with `mapping::getMaxTeamThreads()` (hardware register, always correct). Stride is correct, all iterations execute.

### Source locations

| File | Line | Role |
|------|------|------|
| `mlir/lib/Dialect/OpenMP/IR/OpenMPDialect.cpp` | 2748 | `canPromoteToNoLoop` |
| `mlir/lib/Target/LLVMIR/Dialect/OpenMP/OpenMPToLLVMIRTranslation.cpp` | 3879 | Sets `noLoopMode=true` |
| `llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp` | 6150 | Emits `one_iteration_per_thread=i8 1` |
| `llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp` | 8154–8157 | Sets `MayUseNestedParallelism` |
| `openmp/device/src/Workshare.cpp` | ~938 | `DistributeFor` — uses `omp_get_num_threads()` as stride |
| `openmp/device/src/Parallelism.cpp` | 85 | `__kmpc_parallel_spmd` — sets `Level=1` too late |

### Fix (landed)

In `openmp/device/src/Workshare.cpp`, the `DistributeFor` no-loop path now overrides `NumThreads`
with `mapping::getMaxTeamThreads()` when `OneIterationPerThread=1`, before it's used for the
`BlockChunk` default and stride computation:

```cpp
if (OneIterationPerThread)
  NumThreads = static_cast<Ty>(mapping::getMaxTeamThreads());
```

Merged: [ROCm/llvm-project#3058](https://github.com/ROCm/llvm-project/pull/3058) (2026-06-25).
Upstream issue (still open): [llvm/llvm-project#198621](https://github.com/llvm/llvm-project/issues/198621).
Original report: [ROCm/llvm-project#2601](https://github.com/ROCm/llvm-project/issues/2601)

---

## Also in this repo: VLA private bug — FIXED upstream

`full/test15_vla_private.f90` and `full/test15b_vla_runtime.f90` reproduce GPU memory faults from `private` VLA arrays (tracked as [ROCm/llvm-project#2419](https://github.com/ROCm/llvm-project/issues/2419)). The originally-submitted fix ([#2422](https://github.com/ROCm/llvm-project/pull/2422)) and its follow-up ([#2423](https://github.com/ROCm/llvm-project/issues/2423), missing `free()`) were both superseded by a different-approach fix landed directly upstream: [llvm/llvm-project#200841](https://github.com/llvm/llvm-project/pull/200841) (heap-allocates dynamic private arrays with matching dealloc-region cleanup), merged into `llvm/llvm-project` main on 2026-06-05. Verified fixed by building flang from `amd-staging` (commit `09cac6e4`) on an MI210/gfx90a on 2026-06-21: original reproducer now exits 0 with the correct value, and the compiler emits the expected `malloc`/`free` diagnostic instead of an `addrspace(5)` scratch alloca. Real-world impact on MFC: [MFlowCode/MFC#1449](https://github.com/MFlowCode/MFC/issues/1449).

---

## Archived tests

- `full/` — extended test files for the active bugs above
- `old/` — 16 tests that pass on amdflang 23.2.1 (bugs fixed or never present)

## Sharper trigger (2026-07-22, AFAR 23.2.1, gfx90a)

`-fopenmp-target-fast` is **not** required and is not implicated.

| flags | result |
|---|---|
| none | PASS |
| `-fopenmp-target-fast` alone | PASS |
| `-fopenmp-assume-threads-oversubscription` alone | PASS |
| `-fopenmp-assume-teams-oversubscription` alone | PASS |
| both oversubscription flags | **FAIL: 31 of 64** |
| both, plus `-O1` | PASS |
| `-fopenmp-target-fast` + both | **FAIL: 31 of 64** |

The trigger is the oversubscription pair together with no explicit `-O`, which matches the root
cause since `canPromoteToNoLoop` requires both. That also clears the two assumptions target-fast
implies: `-fopenmp-assume-no-thread-state` and `-fopenmp-assume-no-nested-parallelism` pass alone
and together in exactly the configuration where the pair fails.
