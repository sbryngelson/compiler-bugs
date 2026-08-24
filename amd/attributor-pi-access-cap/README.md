# attributor-pi-access-cap

Downstream: [ROCm#4070](https://github.com/ROCm/llvm-project/issues/4070). AFAR 23.2.0/23.2.1 (ROCm/llvm-project `35849413f758`), gfx90a. Found 2026-08-22 in MFC, root-caused 2026-08-24.

## Symptom

Adding 7 small `target` regions to one file of MFC made the device link regenerate untouched kernels with much worse ISA: a previously spill-free WENO kernel gained a 112 B stack frame and 88 spill instructions (scratch 28→140 B), the LF Riemann kernel went from ~130 to ~176 VGPRs (occupancy 3→2 waves), and every kernel in the image gained 512 B of LDS (group segment 2048→2560). Kernels ran 2.4–4.5x slower per dispatch (rocprofv3), application wall +36%. Deterministic from source, independent of `-flto-partitions`, and unreproducible at small scale.

## Root cause

The ROCm-only cap from commit `a2e4ee8fd36f` ("PR1807.attributor-cap-AAPointerInfo.squash"), `attributor-max-pi-accesses` default 512, enforced in `AA::PointerInfo::State::addAccess` (`AttributorAttributes.cpp:945`): once one pointer's access list reaches 512, the whole `AAPointerInfo` is invalidated via `indicatePessimisticFixpoint()`. The cap does not exist upstream.

Each kernel's inlined `__kmpc_target_init`/parallel protocol code contributes about one access to each DeviceRTL state global (`TeamState`, `ThreadStates`, `IsSPMDMode`, `KernelEnvironmentPtr`, `KernelLaunchEnvironmentPtr`, `SharedMemVariableSharingSpace`), so their access lists grow with the number of kernels in the image and cross the cap together at ~512 kernels. An instrumented build (print at the cap site) showed the good image (519 kernels) already pessimistic on five of the six; `SharedMemVariableSharingSpace` (~501–511 accesses good, 516+ bad) is the one that flips. Once it goes pessimistic, store-to-load forwarding through `__kmpc_begin/get_sharing_variables` fails and OpenMPOpt's parallel-region protocol cleanup dies module-wide: the `structArg`/`.reloaded` marshalling allocas reach codegen in 515 of 523 kernels (92 of 519 in the good image), and the then-dead 512 B sharing space is still referenced when `AMDGPULowerModuleLDS` forms per-kernel LDS structs.

Three independent measurements agree on the cliff: cap default 512; minimal triggering kernel-prefix of the bad module in (518, 520]; minimal healing cap value in (509, 636]. The good image sat within one kernel of the cliff, which is why any kernel-adding change flipped it.

## Reproducer

No minimal source reproducer can exist (the trigger is total image kernel count). `fast.internalize.bc.gz` / `slow.internalize.bc.gz` are the merged device-LTO modules (post-internalize) captured from the real MFC link with `-Xoffload-linker --save-temps`; the source trees differ only by 7 added target regions in `src/simulation/m_amr.fpp` (MFC `up/mega`, `e53db278` vs `a7970743`), and the device IR of all other files is bit-identical.

```
opt -passes='lto<O3>' fast.internalize.bc -o out.bc   # 0 structArg allocas remain
opt -passes='lto<O3>' slow.internalize.bc -o out.bc   # 22470 structArg occurrences; [64 x ptr] in 515 kernel .lds structs
```

Both modules also emit `Attributor did not reach a fixpoint after 256 iterations` under `-pass-remarks-missed=openmp-opt`, which is unrelated to the flip (present on both sides) but shows the engine is over budget at this module size.

## Fix and workaround

`aapointerinfo-per-scope-cap.patch` counts the cap per accessing function instead of per object, with a 64x absolute ceiling as memory backstop; `pointer-info-access-cap.ll` is the lit test. Validated at `35849413f758`: bad module `structArg` 22470→0, dead LDS slot removed from all kernel structs, residual capping only on genuinely dense single-function cases (llvm-libc `slab_cache`, Fortran runtime `ShallowCopy`), pipeline time ~2x default.

Production workaround: link with `-Xoffload-linker -mllvm -Xoffload-linker -attributor-max-pi-accesses=16384` (~4x device-link time, good codegen restored).

Full evidence trail (whole-image ISA diffs, per-stage bitcode, threshold bisections, instrumented-compiler censuses): hpcfund `~sbryngelson/work/software/image-codegen-repro/`.
