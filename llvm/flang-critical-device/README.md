# flang/OpenMP: `critical` does not serialize lanes in target offload

| | |
|---|---|
| Issue | [llvm#214965](https://github.com/llvm/llvm-project/issues/214965) |
| Fix | none yet; a first attempt is described below and did not work |

A `critical` region inside a target region does not serialize the lanes of a wavefront in flang, so
a conforming program silently gets wrong results. The C equivalent is correct on the same GPU.

`ctl.f90` and `crit.c` run the same shape three ways -- unprotected, `atomic`, `critical` -- so the
controls sit next to the failure.

| threads | wavefronts | flang `critical` | clang `critical` |
|---|---|---|---|
| 64 | 1 | 1 | 64 |
| 128 | 2 | 2 | 128 |
| 256 | 4 | 4 | 256 |

The count is the number of wavefronts. Reproduces on upstream flang 24.0.0git and on amdflang from
AFAR 22.2.0, 23.1.0, 23.2.0 and 23.2.1; C is correct on all of them.

Controls, all in the same construct on the same mapped variable:

* `atomic update` gives the full count, so the variable really is shared and written back.
* `OMP_TARGET_OFFLOAD=DISABLED` on the same binary gives the full count.
* `manser.f90` wraps the same `critical` in a hand-written lane-serialization loop and gets the
  full count. That is confirmation by construction, not correlation.

## Cause

`setCriticalLock` (`openmp/device/src/Synchronization.cpp`) acquires the lock only on the lowest
active lane of a wavefront. That is sound only if one lane per wavefront reaches it.
`CGOpenMPRuntimeGPU::emitCriticalRegion` guarantees it for clang by wrapping the region in a loop
over `__kmpc_get_hardware_num_threads_in_block()` with `__kmpc_syncwarp` between turns.
`OpenMPIRBuilder::createCritical`, which flang reaches via `convertOmpCritical`, has no device path
and emits the region directly, so every active lane enters at once.

## A fix that does not work

Adding the clang-shaped turn loop to `OpenMPIRBuilder::createCritical` under
`Config.isTargetDevice()` fixes one wavefront and not more:

| threads | with the naive turn loop |
|---|---|
| 64 | 64, correct |
| 128 | 68, expected 128 |
| 256 | 202, expected 256 |

`__kmpc_syncwarp` synchronizes a wavefront, not a block, so once there is more than one wavefront
the turn counters drift apart and updates are lost again. A correct fix needs block-wide
synchronization, or a different structure than a straight port of the clang loop. Two further
notes: `BasicBlock::splitBasicBlock` cannot be used here because OMPIRBuilder has not terminated
the insertion block yet -- use the `splitBB` helper -- and clang does not normally route `critical`
through `createCritical`, so a change there could double-wrap under
`-fopenmp-enable-irbuilder`.

Root cause analysis and the reduced cases were produced with Claude and reviewed.
