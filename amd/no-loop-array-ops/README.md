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

**Answered 2026-08-03: the bug is still live, on every AMD arch available here, and
`llvm#211287` does not fix it.** #198621 correctly stays open.

### Reproduced on gfx90a, gfx942 and gfx950 (2026-08-03)

Documented flags, `minimal_array_constructor.f90`, N=64, one node per arch:

| toolchain | gfx90a (MI250X) | gfx942 (MI300X) | gfx950 (MI355X) |
|---|---|---|---|
| AFAR 23.1.0 | FAIL: 31 of 64 | FAIL: 31 of 64 | FAIL: 31 of 64 |
| AFAR 23.2.0 | FAIL: 31 of 64 | FAIL: 31 of 64 | FAIL: 31 of 64 |
| AFAR dir `23.2.1` | FAIL: 31 of 64 | FAIL: 31 of 64 | FAIL: 31 of 64 |

**The miscount is identical on all three**, not merely "still fails". The `N_wrong` formula does not
shift with the wave/CU geometry of MI300X or MI355X, because the failure is set by the software
stride collapsing to 1 rather than by anything hardware-specific. So this is a DeviceRTL logic
defect, and it is live on AMD's newest silicon with the current shipping compilers — not a legacy
gfx90a curiosity. That is a much stronger argument for porting
[ROCm#3058](https://github.com/ROCm/llvm-project/pull/3058) upstream than "defense in depth".

Two caveats on that table. The directory named `therock-afar-23.2.1-...` ships **AFAR #23.2.0**
(`amdflang --version` reports `#23.2.0 04/18/26`, git `35849413f758`, identical to the 23.2.0 drop),
so it is two distinct compilers tested three times, not three. And all three drops predate the
2026-06-25 downstream fix, so this says nothing about current `amd-staging`, which should pass.

ROCm 7.2.0 cannot build this reproducer at all: `ld.lld: error: undefined symbol: _FortranAAssign`,
which is [#203890](https://github.com/llvm/llvm-project/issues/203890). On that toolchain the code
does not miscompile, it fails to link.

### Measurement error worth not repeating

An earlier pass at this concluded the reproducer had gone stale and no longer triggered on any arch.
That was wrong: the runs had added **`-O2`**, and the documented command carries no `-O` flag at all.
Every conclusion from that run was void.

**The trigger is the absence of an `-O` flag, not the optimisation level.** Measured A/B, AFAR
23.2.0, gfx90a, MI250X, only `-O` varying:

| flags | result |
|---|---|
| *(none, as documented)* | **FAIL: 31 of 64** |
| `-O0` | PASS |
| `-O1`, `-O2`, `-O3` | PASS |

`-O0` passes, and `-O0` optimises nothing, so "optimisation removes the device temporary" is **not**
the mechanism — an earlier revision of this file said it was, and that was a guess that fit the
`-O2` datum and nothing else. `LIBOMPTARGET_KERNEL_TRACE` shows both builds are `SGN:6` (no-loop) at
`teamsXthrds:(2X32)`, and **both carry a large scratch allocation** (27424 B with no flag, 76200 B at
`-O0`), so the heap temporary is present either way.

What distinguishes a bare invocation from an explicit `-O0` here is **not established**. Whatever it
is, it decides whether the LTO fold of `omp_get_num_threads()` succeeds. Recorded as an open
question rather than filled with another plausible story.

The tell was available and ignored: a bug filed *against* these exact drops was not reproducing *on*
those drops, and all of them predate both the issue (2026-05-19) and the fix (2026-06-25), so they
must contain it. That contradiction should have pointed at the invocation immediately instead of at
a "the reproducer went stale" theory. Run the documented command verbatim before varying it.

The upstream half was determined by reading `origin/main` after #211287 landed, re-checked at
`e7713ee70b87`. **Both ends of the defect are intact**, not just the DeviceRTL.
Upstream `openmp/device/src/Workshare.cpp` still has the defective shape, unchanged:

```cpp
static void DistributeFor(IdentTy *Loc, ..., Ty NumIters, Ty NumThreads,
                          Ty BlockChunk, Ty ThreadChunk,
                          uint8_t OneIterationPerThread) {
  ...
  if (BlockChunk == 0)
    BlockChunk = NumThreads;        // caller's NumThreads, no override
  ...
  if (OneIterationPerThread)
    ASSERT(NumBlocks * NumThreads >= NumIters, "Broken assumption");
```

There is **no `mapping::getMaxTeamThreads()` override when `OneIterationPerThread` is set**, which
is precisely what [ROCm#3058](https://github.com/ROCm/llvm-project/pull/3058) added downstream. The
`__kmpc_distribute_for_static_loop*` entry points in the `OMP_LOOP_ENTRY` macro pass `num_threads`
straight through, so nothing corrects it anywhere in the chain. Any caller that still reaches
`DistributeFor` with a stale `NumThreads` of 1 gets the same skipped-iteration suffix.

What #211287 changes is step 3/4 of the chain above, not step 5: refining
`MayUseNestedParallelism` to 0 lets LTO fold `omp_get_num_threads()` into a hardware register read,
so flang array-expression kernels stop supplying the bad value. The DeviceRTL weakness is untouched.

Note for anyone testing this: in an assertions build the `ASSERT(NumBlocks * NumThreads >=
NumIters)` above fires on the bad path, so `-DLLVM_ENABLE_ASSERTIONS=ON` turns the silent wrong
answer into a diagnosable one. Release builds compile the assert out and simply skip iterations.

The caller side is unchanged too. `llvm/lib/Frontend/OpenMP/OMPIRBuilder.cpp` still supplies
`num_threads` from a runtime call:

```cpp
FunctionCallee RTLNumThreads = OMPBuilder->getOrCreateRuntimeFunction(
    M, omp::RuntimeFunction::OMPRTL_omp_get_num_threads);
Value *NumThreads = OMPBuilder->createRuntimeFunctionCall(RTLNumThreads, {});
RealArgs.push_back(
    Builder.CreateZExtOrTrunc(NumThreads, TripCountTy, "num.threads.cast"));
```

so a hoistable call feeds the stride and nothing downstream sanity-checks it.

**What #211287 does and does not do.** It refines `MayUseNestedParallelism` to 0, which lets LTO fold
`omp_get_num_threads()` into a register read for the kernels it applies to. It does not touch the
DeviceRTL. Whether that closes every path to the bad value upstream has *not* been measured here —
the runs above are AFAR drops, all of which predate it. What is measured is that the bug is live on
gfx90a/gfx942/gfx950 with the shipping AFAR compilers, and what is read from source is that both
halves of the defect remain in `main`.

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
