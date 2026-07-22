# Investigated: not bugs, or not yet established

Recorded so they are not re-derived.

**Private-array promotion cliff above ~16 equations (2026-07-22).** On a WENO5 + HLLC kernel the
private state arrays stop being promoted between NEQ=16 and NEQ=18: scratch appears (296 → 520 B/lane,
+16 B per equation), VGPRs drop 124 → 70 and occupancy *rises* 4 → 7, with `VGPRs Spill: 0` — so it is
not register spilling, the arrays simply live in scratch. Work-normalized throughput drops ~17% across
the transition and stays flat after.

Root cause is `amdgpu-promote-alloca-to-vector-max-regs`, default **32** 32-bit registers:
`[16 x double]` is exactly 32 registers, `[18 x double]` is 36. But raising it is catastrophic —
at NEQ=18, 1121 → 157 Mcell/s; at NEQ=24, 845 → 88 Mcell/s (7x and 9.7x slower). Promotion succeeds
and the values spill anyway, scratch *doubles* to 640 B and occupancy collapses. The default is
protecting the code; the compiler's choice is correct and the ~17% is inherent to the arrays not
fitting a sensible register budget. `-amdgpu-unroll-threshold-private` (to 20000, both pipeline
stages), `-amdgpu-schedule-relaxed-occupancy` and `-amdgpu-schedule-metric-bias=0` are all inert.

**Kernel-environment vs module-global fold asymmetry (2026-07-22).** Forcing
`MayUseNestedParallelism = 0` in `OMPIRBuilder` fixed a small reproducer but not a larger kernel,
while the module-level assume flag fixed both — which looked like a second gap. It is not:
`OpenMPOpt.cpp:3815` unconditionally overwrites the field from its own `NestedParallelism` analysis,
so setting the frontend's initial value is always discarded. Only what the analysis concludes matters,
which is why [llvm#211287](https://github.com/llvm/llvm-project/pull/211287) works.

**Intermittent `ld.lld` crash on a scalar reduction.** Seen once, not reproducible: 0/10 on upstream
flang and 0/10 on AFAR 23.2.1. Not filed.

## Undetermined

**Array-reduction strategy divergence (2026-07-22).** `reduction(+:s)` on `real(8) :: s(N)` in a
`target teams distribute parallel do` lowers three different ways, gfx90a:

| | scratch B/lane | dynamic stack | runtime entries |
|---|---|---|---|
| AFAR 23.2.1 | `8 + 24N` | no | `nvptx_parallel_reduce`, `nvptx_teams_reduce`, `reduction_get_fixed_buffer` |
| ROCm 7.2.0 | `112 + 16N` | **yes** | — |
| upstream `119b31fd3064` | `272 + 40N` | **yes** | `gpu_xteam_reduce_nowait`, `nvptx_parallel_reduce` |

Upstream carries both a large fixed overhead and the steepest per-element cost, but it also reports
*higher* occupancy than AFAR at N=8 (7 vs 5), so it is not clearly worse. The dynamic stack is not a
consequence of the un-inlined outlined region — `-fopenmp-assume-no-nested-parallelism` leaves it in
place. Deciding whether any of this is a bug needs a timing harness, which has not been built. Not
filed.

