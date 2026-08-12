# flang/OpenMP: `critical` does not serialize lanes in target offload

| | |
|---|---|
| Issue | [llvm#214965](https://github.com/llvm/llvm-project/issues/214965) |
| Fix | [llvm#215009](https://github.com/llvm/llvm-project/pull/215009), open |

A `critical` region inside a target region does not serialize the lanes of a wavefront in flang, so
a conforming program silently gets wrong results. The C equivalent is correct on the same GPU.

`ctl.f90` and `crit.c` run the same shape three ways -- unprotected, `atomic`, `critical` -- so the
controls sit next to the failure.

| threads | wavefronts | flang `critical` | clang `critical` |
|---|---|---|---|
| 64 | 1 | 1 | 64 |
| 128 | 2 | 2 | 128 |
| 256 | 4 | 4 | 256 |
| 512 | 8 | 8 | 512 |
| 1024 | 16 | 16 | 1024 |

The count is the number of wavefronts. Reproduces on upstream flang 24.0.0git and on amdflang from
AFAR 22.2.0, 23.1.0, 23.2.0 and 23.2.1; C is correct on all of them.

Controls, all in the same construct on the same mapped variable:

* `atomic update` gives the full count, so the variable really is shared and written back.
* `OMP_TARGET_OFFLOAD=DISABLED` on the same binary gives the full count.
* `manser.f90` wraps the same `critical` in a hand-written lane-serialization loop and gets the
  full count. That is confirmation by construction, not correlation.

## Cause

`setCriticalLock` (`openmp/device/src/Synchronization.cpp:109`, the AMDGPU section) acquires the
lock only on the lowest active lane of a wavefront, so the other lanes fall through with no lock at
all. That is sound only if one lane per wavefront reaches it. The NVPTX section at line 178 is a
different implementation, `setCriticalLock(Lock) { setLock(Lock); }`, a plain per-thread CAS spin
lock with no lane election, so the wrong-answer mechanism described here is AMDGPU-specific.
`CGOpenMPRuntimeGPU::emitCriticalRegion` guarantees it for clang by wrapping the region in a loop
over `__kmpc_get_hardware_num_threads_in_block()` with `__kmpc_syncwarp` between turns.
`OpenMPIRBuilder::createCritical`, which flang reaches via `convertOmpCritical`, has no device path
and emits the region directly, so every active lane enters at once.

## Fix

`critical-fix-v3.patch`. `OpenMPIRBuilder::createCritical` gains a device path,
taken when `Config.IsGPU` is set, that wraps the region in the same turn loop
clang emits in `CGOpenMPRuntimeGPU::emitCriticalRegion`:

```
mask = __kmpc_warp_active_thread_mask();
for (i = 0; i < __kmpc_get_hardware_num_threads_in_block(); ++i) {
  if (__kmpc_get_hardware_thread_id_in_block() == i)
    <__kmpc_critical / body / __kmpc_end_critical>
  __kmpc_syncwarp(mask);
}
```

Result on MI250X, all thread counts now match clang and the `atomic` control:

| threads | before | after |
|---|---|---|
| 64 | 1 | 64 |
| 128 | 2 | 128 |
| 256 | 4 | 256 |
| 512 | 8 | 512 |
| 1024 | 16 | 1024 |

Before: 3 runs each on unpatched flang. After: 10 runs each, all identical. Measured on gfx90a
only; the change also affects NVPTX and SPIR-V, which are untested here. The 512 and 1024 "before"
numbers were originally extrapolated from the wavefront pattern and published in the PR that way;
they were measured afterwards and did match, but do not do that again.

Regression suites green: `LLVMFrontendTests` (1281), and
`mlir/test/Target/LLVMIR`, `mlir/test/Dialect/OpenMP`,
`flang/test/Lower/OpenMP`, `flang/test/Integration/OpenMP`,
`clang/test/OpenMP` (2547 total). New test:
`mlir/test/Target/LLVMIR/omptarget-critical-device.mlir`.

## Two wrong turns on the way

**v1 passed an all-ones mask to `__kmpc_syncwarp`.** clang passes
`__kmpc_warp_active_thread_mask()`. All-ones makes reconvergence wait on lanes
that are not executing. This is what broke the second wavefront: 128 threads
gave 68.

**v2 fixed the mask but left `__kmpc_critical` outside the loop.**
`createCritical` builds the entry and exit calls at the current insertion point
before the region is emitted. `EmitOMPInlinedRegion` relocates only the *exit*
call, via `emitCommonDirectiveExit`; `emitCommonDirectiveEntry` returns
immediately when `Conditional` is false and never moves the entry call. So the
lock was acquired once, before the loop, and released on every turn. The
symptom was partial serialization that got worse with more wavefronts: 256 gave
205, 512 gave 272. The fix is one `moveBefore` into the region block.

## Notes for anyone touching this

* `BasicBlock::splitBasicBlock` cannot be used here, OMPIRBuilder has not
  terminated the insertion block yet; use the `splitBB` helper.
* Guard on `Config.IsGPU`, not `Config.isTargetDevice()`. flang sets it from
  `Triple::isGPU()` (`CompilerInvocation.cpp:1372`), which is
  `isSPIROrSPIRV() || isNVPTX() || isAMDGPU()`, and that matches the targets
  clang gives `CGOpenMPRuntimeGPU` to in `CodeGenModule.cpp:685` (nvptx,
  nvptx64, amdgpu, spirv64). The doc comment on `OpenMPIRBuilderConfig::IsGPU`
  still says AMDGPU and NVPTX only and is out of date -- do not quote it, read
  the code. The getters assert when the optional is unset, which the
  OMPIRBuilder unit tests do not populate, so read
  `Config.IsGPU.value_or(false)`.
* `ninja bin/flang` does not rebuild `mlir-translate`. An MLIR lit run against
  the stale binary reported green for a test that was actually failing, and
  reported the device path as not taken when it was. The same trap recurred with
  `mlir-opt`: 28 then 1 spurious failures until it was rebuilt too.
  `libLLVMFrontendOpenMP` feeds flang, clang, mlir-translate, mlir-opt, bbc,
  fir-opt and tco, so rebuild every tool the suite invokes, not just the obvious
  one.
* Verify the patch is present in the source before building, and that no other
  `ninja` is running in the same build directory. A measurement taken against a
  racing build showed the unpatched numbers and briefly looked like a
  regression.

Root cause analysis, the reduced cases and the fix were produced with Claude and
reviewed.
