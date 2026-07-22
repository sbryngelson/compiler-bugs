# flang/OpenMP: scalar reduction in a target region emits `!dbg` pointing at the wrong subprogram

Target: gfx90a (MI210/MI250X). Compiler: upstream flang 24.0.0git @ `119b31fd3064`.

**Status: OPEN.** Reported: [llvm/llvm-project#211385](https://github.com/llvm/llvm-project/issues/211385).

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
