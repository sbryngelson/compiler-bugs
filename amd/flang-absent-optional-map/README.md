# amdflang: absent OPTIONAL array referenced in a target region → garbage device allocation (AFAR 24.3.0 regression)

Target: gfx90a (MI210). Compiler: AFAR 24.3.0 (`therock-afar-24.3.0-multiarch-10.1.0-592954c`,
ROCm/llvm-project `3ba19712e9fb`), compared against AFAR 23.2.1.

**Status: OPEN.** Reported downstream as [ROCm#4615](https://github.com/ROCm/llvm-project/issues/4615)
(2026-09-24). Same family as upstream [llvm#154798](https://github.com/llvm/llvm-project/issues/154798)
(open since 2025-08, the `present()` form); the assumed-shape variant is posted there too. No fix yet.
Worked around in MFC by always passing the arrays: [MFC#1920](https://github.com/MFlowCode/MFC/pull/1920).

## Bug

An absent optional assumed-shape array that is referenced inside a `target` region, even behind a
runtime flag that keeps the reference from executing, gets implicitly mapped using the absent
argument's descriptor. On 24.3.0 that produces a garbage map size and the launch fails before the
kernel runs:

```
PluginInterface error: Failure to allocate device memory: "out of resources" failed to allocate from memory manager
omptarget error: Failed to process data before launching the kernel.
omptarget fatal error 1: failure of target construct while offloading is mandatory
```

The failing request is never recorded by `rocprofv3 --memory-allocation-trace` (everything that
succeeded before it totals ~40 MB on the MFC case), and it still fails with
`LIBOMPTARGET_MEMORY_MANAGER_THRESHOLD=0` ("failed to allocate from device allocator"), so it is one
oversized request, not pool exhaustion.

## Reproducers

`make run` builds all three with 24.3.0; `make run AFAR_ROOT=<23.2.1 root>` for the comparison.

| file | shape of the reference | 23.2.1 | 24.3.0 |
|---|---|---|---|
| `repro.f90` | 1-D, behind a `declare target` logical | `sum = 100.` | allocation failure |
| `repro_mfc_shape.f90` | 5-D with explicit lower bounds, as in MFC | `sum = 100.` | allocation failure |
| `repro_present.f90` | 2-D, behind `present(b)` (the llvm#154798 pattern) | `HSA_STATUS_ERROR_MEMORY_APERTURE_VIOLATION` | allocation failure |

The first two give the same results at `-O0`, `-O2` and `-O3` (the third was only run at `-O2`). So the `present()` form was already broken on 23.2.1 (a
different symptom), while the flag-guarded form is a new 24.3.0 regression.

## Where it bit

MFC `s_ibm_correct_state` (`src/simulation/m_ibm.fpp`): `pb_in`/`mv_in` are optional and absent unless
QBMM with non-polytropic bubbles is on, and the ghost-point `GPU_PARALLEL_LOOP` references them. Every
immersed-boundary case failed on 24.3.0: 71 of 723 tests, all with the error above, no golden-file
mismatches. 23.2.1 ran them.

An audit of MFC for the same pattern (optional dummies referenced inside `GPU_PARALLEL_LOOP` regions)
found one more: the `down_sample` path in `simulation/m_start_up.fpp` called
`s_populate_variables_buffers` without `pb_in`/`mv_in`/`q_T_sf`, which reach the GPU loop in
`s_populate_bc_direction`. That one segfaults in libomptarget with a null dereference at the first
save on **both** 23.2.1 and 24.3.0, so it is the older `present()`-family behaviour rather than the
24.3.0 regression. No MFC test sets `down_sample`, which is why it went unnoticed; it was checked on a
48³ IGR case. `s_mpi_sendrecv_variables_buffers` also has optional arrays in GPU loops but only
launches those loops behind host-side `present()` checks, so it is safe. `pre_process` and
`post_process` are not built with offload.

Both call sites are fixed in MFC#1920 by passing `pb_ts(1)%sf`, `mv_ts(1)%sf` and `q_T_sf`, which
always exist (zero-size or unallocated when unused), as the time stepper already did. With that and
the flang-rt patch from [flang-rt-device-unresolvable-refs](../flang-rt-device-unresolvable-refs),
MFC's full suite passes on 24.3.0 (723 passed, 0 failed).

## Workaround

Don't leave an optional array absent if a target region references it; pass a zero-size array
instead.
