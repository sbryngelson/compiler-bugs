# flang/OpenMP: scalar reduction in a target region emits `!dbg` pointing at the wrong subprogram

Target: gfx90a (MI210/MI250X). Compiler: upstream flang 24.0.0git @ `119b31fd3064`.

**Status: FIX POSTED.** Reported: [llvm/llvm-project#211385](https://github.com/llvm/llvm-project/issues/211385).
Fix: [llvm/llvm-project#211395](https://github.com/llvm/llvm-project/pull/211395).
Confirmed on tip `02c51adb8ff2` as well as `119b31fd3064`.

## Bug

A scalar `reduction` in a `target` region makes flang emit a `!dbg` whose scope is the enclosing
kernel's `DISubprogram` rather than the outlined function's own. The module then fails LLVM
verification during the device LTO link:

```
!dbg attachment points at wrong subprogram for function
!99 = distinct !DISubprogram(name: "__omp_offloading_..._k__l7..omp_par.5", ...)
ptr @__omp_offloading_..._k__l7..omp_par.5
  %132 = bitcast double %79 to i64, !dbg !148
!148 = !DILocation(line: 7, column: 9, scope: !29)
!29 = distinct !DISubprogram(name: "__omp_offloading_..._k__l7", ...)
LLVM ERROR: Broken module found, compilation aborted!
```

The instruction is in `..omp_par.5` (`!99`); its location's scope is `!29`, the kernel.

## When it fires

| flags | result |
|---|---|
| `-O3` | ok |
| `-O0 -g` | ok |
| `-O2 -g` | **broken module** |
| `-O3 -g` | **broken module** |
| `-O3 -Rpass-analysis=kernel-resource-usage` | **broken module** |

`-g` at `-O1`+ is enough. The remark flag is not special — it just also runs the verifier. Without
the verifier the invalid debug info is still emitted, only undiagnosed.

## Scope

From a sweep of 16 offload patterns, only **scalar** reductions trip it: `reduction(+:s)` on a
scalar and `reduction(min:)/(max:)` on scalars. An **array** reduction does not, nor do `collapse`,
`atomic capture`, `declare target` variables, derived-type or allocatable mapping, `where`,
assumed-shape arrays, or `teams distribute` without `parallel do`.

amdflang from AFAR 23.2.1 (LLVM 23) builds the same source cleanly with both `-g` and the remark
flag, so this is either upstream-specific or already fixed downstream.

Not confirmed on current tip: tested at `119b31fd3064`, and no commits touch
`flang/lib/Lower/OpenMP`, `flang/lib/Optimizer` or `llvm/lib/Frontend/OpenMP` between that and
`02c51adb8ff2` — weak evidence, not a check.

## Related

[#72676](https://github.com/llvm/llvm-project/issues/72676) was the same verifier message for flang
OpenMP on the **host** (`threadprivate` + `single`), fixed 2024. This is the device-offload path.

## Reproducer

`reduction_dbg_verifier.f90` — build per the comment at the top of the file.

## Root cause

The device reduction helpers emitted by `OpenMPIRBuilder` (`_omp_reduction_shuffle_and_reduce_func`,
`_omp_reduction_inter_warp_copy_func`, and the four global/list copy and reduce helpers) are created
with **no debug info of their own**, but the builder's current debug location is left set while
their bodies are emitted. Their instructions therefore carry `DILocation`s scoped to the enclosing
kernel's subprogram.

`Verifier`'s subprogram check only applies to a function that *has* a `DISubprogram`, so the helpers
are never flagged themselves. The mismatch becomes visible only when the inliner folds a helper into
a function that does have one — which is why the pre-link IR is clean at every `-O` level and the
failure appears during the device LTO link.

## How it was narrowed

1. Pre-link IR verifies clean at `-O0/-O1/-O2/-O3`; `opt -passes='openmp-opt'` alone is clean too.
2. Reduced to an `opt`-only reproducer, no flang needed:
   `opt -passes='lto<O3>' out.img.0.2.internalize.bc` (from `ld.lld --save-temps`).
3. `-opt-bisect-limit` binary search over 464 points → first break at 301, `inline` on the outlined
   region, right after `inline` on `__kmpc_gpu_xteam_reduce_nowait`.
4. Dumping that module with `-disable-verify` shows 167 instructions in the outlined function scoped
   to the kernel's subprogram.
5. Walking the *pre*-inline module for functions with no `!dbg` attachment that nevertheless carry
   `DebugLoc`s finds exactly the two helpers this reduction uses, with 54 and 5 locations, all
   scoped to the kernel.

## Fix

Clear the debug location after switching the insert point into each helper. Applied to all six
helpers that follow the pattern, not only the two this reproducer exercises.

Verified on gfx90a: `-O2 -g`, `-O3 -g` and `-O3 -Rpass-analysis=kernel-resource-usage` all build,
and the reduction returns the correct value. The added regression test fails without the change.
