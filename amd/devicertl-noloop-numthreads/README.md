# DeviceRTL: wrong NumThreads in the SPMD no-loop distribute path

| | |
|---|---|
| Issue | [llvm#198621](https://github.com/llvm/llvm-project/issues/198621) -- open since 2026-05-19 |
| PR | [llvm#214263 is a different fix; this one is llvm#214073](https://github.com/llvm/llvm-project/pull/214073) |
| Downstream | [ROCm#3058](https://github.com/ROCm/llvm-project/pull/3058) carries the same fix |

In the one-iteration-per-thread path the index is `BId * NumThreads + TId`, so `NumThreads` has to
be the real block size. `DistributeFor` used the caller's value; a larger one strides past each
block and drops the iterations in between.

| NumThreads passed | threads in block | iterations not run |
|---|---|---|
| 256 | 32 | 96 of 128 |
| 256 | 64 | 64 of 128 |
| 128 | 32 | 96 of 128 |
| 64 | 64 | 0 |

## Getting it reproducible upstream

The issue had sat since May partly because it was thought unobservable upstream. It is not
reachable through normal C or C++ codegen: **clang lowers worksharing loops to
`__kmpc_for_static_init_4`, and only flang emits `__kmpc_distribute_for_static_loop_*`**, verified
from the device IR of both frontends. clang's ExecMode also stays 2, never 6, even with the
oversubscription flags -- the no-loop promotion is flang-only (`canPromoteSPMDToNoLoop`).

Calling the runtime entry directly from C works, and that is what the test does. It needs a
host-side stub of the entry, guarded by `#ifndef __AMDGCN__`, so the host fallback copy links while
the device uses the real one.

## A non-bug found the same way

`For()` looked like it had the identical defect -- 96 of 128 iterations dropped. It does not. With
`NumBlocks = 1` the coverage is exactly the thread count, so one-iteration-per-thread is only
meaningful when `actual_threads >= NumIters`; the probe violated that precondition. Under valid
input `For()` is correct even with a deliberately wrong `NumThreads`.

**Probing a runtime entry point directly bypasses the caller's contract and can manufacture a
failure that is not a compiler bug. Check the precondition before believing a hit.**
