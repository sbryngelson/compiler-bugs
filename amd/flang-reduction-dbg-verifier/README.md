# flang/OpenMP: scalar reduction in a target region emits `!dbg` pointing at the wrong subprogram

Target: gfx90a (MI210/MI250X). Compiler: upstream flang 24.0.0git @ `119b31fd3064`.

**Status (2026-07-24): FIXED — @abidh's reland
[#211566](https://github.com/llvm/llvm-project/pull/211566) merged to `main`
(`3d69ace09ec4`, 2026-07-24), and the report
[llvm/llvm-project#211385](https://github.com/llvm/llvm-project/issues/211385) is closed as
completed.** #211566 fixes all six reduction helpers and clears the debug location on both
helper-internal barriers. My narrower PR [#211395](https://github.com/llvm/llvm-project/pull/211395)
went green on all four platforms but was **closed in favour of #211566**, which is the superset. See
"Outcome" at the end.

Confirmed on `119b31fd3064` and `02c51adb8ff2`. On `d1d3891077f6` the bad IR is still emitted but
the end-to-end crash no longer fires — see "The symptom went latent".

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

At `119b31fd3064` / `02c51adb8ff2`:

| flags | result |
|---|---|
| `-O3` | ok |
| `-O0 -g` | ok |
| `-O1 -g` | ok |
| `-O2 -g` | **broken module** |
| `-O3 -g` | **broken module** |
| `-O3 -Rpass-analysis=kernel-resource-usage` | **broken module** |

`-O2` and above with `-g`. (An earlier version of this file and the upstream report said "-O1 and
above"; that was an untested extrapolation and is wrong.) Device-only — the same source at `-O3 -g`
without offload compiles cleanly. The remark flag is not special — it just also runs the verifier. Without
the verifier the invalid debug info is still emitted, only undiagnosed.

**This table no longer holds at `d1d3891077f6`.** See below.

## The symptom went latent (2026-07-23, tip `d1d3891077f6`)

On current tip the reproducer builds **clean, unpatched**, at `-O2 -g`, `-O3 -g` and with the remark
flag. Nothing was fixed: the defective IR is emitted exactly as before. Unpatched, in the pre-link
device module:

| helper | `!dbg` | first location resolves to |
|---|---|---|
| `_omp_reduction_shuffle_and_reduce_func` | 61 | `__omp_offloading_803_6075695_k__l12` |
| `_omp_reduction_inter_warp_copy_func` | 48 | same |

Both scoped to the **kernel's** subprogram, which is the bug. Something downstream stopped folding
the helpers into a position where the verifier sees the mismatch, so the failure is latent rather
than gone. Anything relying on the end-to-end crash as the signal will now silently pass; check the
IR instead.

Practical consequence: do not use "does the reproducer build?" as the regression test on tip. Use
`flang/test/Integration/OpenMP/target-reduction-debug-loc.f90` or the MLIR test in #211566, both of
which check for `!dbg` in the helper bodies directly.

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

There are two ways the caller's location gets in. The builder's location carries over into the
helper at entry, and, in `emitInterWarpCopyFunction`, the two `kmpc_barrier` calls forward `Loc.DL`
explicitly and re-establish it part way through the body. Fixing only the first leaves everything
after the first barrier still scoped to the kernel. See the Fix section.

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

## Prior art

@abidh had already fixed this in [#147950](https://github.com/llvm/llvm-project/pull/147950)
(merged 2025-07-11), covering eight sites with `InsertPointGuard`. It was reverted a few weeks later
by [#150832](https://github.com/llvm/llvm-project/pull/150832) for unexplained clang reduction test
failures, and never relanded. `main` has no `SetCurrentDebugLocation(DebugLoc())` in
`OMPIRBuilder.cpp` today, so the bug is live.

**The failures do not reproduce on current main (2026-07-23).** #147950 ported onto `02c51adb8ff2`
(the only conflicts are the `ArrayRef<bool> IsByRef` signature change) is clean:

| suite | result |
|---|---|
| clang/test/OpenMP | 1573 passed, 0 failed |
| mlir/test/Target/LLVMIR | 404 passed, 0 regressions |
| OpenMPIRBuilder unit tests | 101 passed |

The only failure is the test #147950 itself adds, and it is syntax drift rather than correctness:
`omp.target` now requires `kernel_type`. So the patch looks relandable once that test is updated.

An earlier version of this file guessed the revert came from the added guards *restoring the
insertion point* in functions that previously left it moved. That was wrong, and was written
without running anything. Retracted.

Also worth recording as a method note: the first attempt at the run above reported 5 MLIR failures,
including tests unrelated to OpenMP. That was a stale `mlir-translate` — only `ninja clang` had been
run, so the binary was linked against a different `libLLVMFrontendOpenMP`. Rebuilding every binary
under test before measuring is not optional here.

## Fix

Clear the debug location after switching the insert point into each helper, using
`IRBuilder<>::InsertPointGuard` so the location is restored for the caller. A bare
`SetCurrentDebugLocation(DebugLoc())` is not enough: `restoreIP` does not restore the debug
location, so the cleared location leaks out.

**The landing fix is #211566**, @abidh's reland, which applies this to all six helpers. My #211395
did the same thing for only the two helpers this reproducer exercises
(`emitShuffleAndReduceFunction`, `emitInterWarpCopyFunction`), deliberately narrow to stay clear of
whatever broke #147950. Once #147950 was shown to be relandable that caution was unnecessary, so the
narrow PR was closed. In `emitInterWarpCopyFunction` the guard replaces the manual
`saveIP`/`restoreIP` pair; the guard in `emitShuffleAndReduceFunction` is inert for the insertion
point, since the sole caller already brackets both calls in `saveIP`/`restoreIP`.

The same pattern already exists in-tree for the *target-outlined* function at
`OMPIRBuilder.cpp:9061-9064` (`InsertPointGuard` + `SetCurrentDebugLocation(DebugLoc())`, with the
comment "the debug location may still be pointing to the parent function. Reset it now"). So this is
an established idiom in this file, not a new convention.

**Clearing the location at the top of the helper is not sufficient.** `emitInterWarpCopyFunction`
emits two `kmpc_barrier` calls that forward the caller's location explicitly:

```cpp
createBarrier(LocationDescription(Builder.saveIP(), Loc.DL), ...)
```

`createBarrier` calls `updateToLocation`, which re-establishes that location part way through the
helper, so every instruction after the first barrier is scoped to the kernel again. Both barriers
have to pass `DebugLoc()` instead. On tip that is the difference between 58 `!dbg` in
`_omp_reduction_inter_warp_copy_func` and none:

```
!27 = !DILocation(line: 28, column: 9, scope: !6)
!6  = distinct !DISubprogram(name: "__omp_offloading_..._k__l28", ...)
```

This does **not** reproduce at `02c51adb8ff2` and does at `d1d3891077f6`, which is how it was
missed: the first revision was verified against the older base only, and upstream CI caught it.
Verify against tip, not just whatever the local checkout happens to be at.

An earlier revision of the PR also claimed all six helpers but in fact patched two and carried the
same two lines duplicated four times inside `createReductionFunction`; the four global/list helpers
were never touched. Corrected 2026-07-23.

Verified on gfx90a: `-O2 -g`, `-O3 -g` and `-O3 -Rpass-analysis=kernel-resource-usage` all build,
and the reduction returns the correct value. The regression test fails without the change and passes
with it.

## Outcome (2026-07-24)

**#211566 merged to `main` as `3d69ace09ec4` on 2026-07-24; #211385 closed as completed.**

#211395 reached full green on all four premerge platforms after the barrier fix, then was closed in
favour of #211566. #211566 was verified locally at `d1d3891077f6` before merge — applies clean, and
both
`flang/test/Integration/OpenMP/target-reduction-debug-loc.f90` (mine) and
`mlir/test/Target/LLVMIR/omptarget-debug-reduc-fn-loc.mlir` (his) pass against it:

| suite | result |
|---|---|
| check-flang | 4608 passed, 11 expected failures, 0 failures |
| clang/test/OpenMP | 1573 passed |
| mlir/test/Target/LLVMIR | 407 passed |
| LLVMFrontendTests (unit) | 1281 passed |

Every binary under test was rebuilt first (`flang`, `clang`, `fir-opt`, `bbc`, `mlir-translate`,
`mlir-opt`, `LLVMFrontendTests`) — see the stale-binary note above.

The earlier count of "101" for the OpenMPIRBuilder unit tests was the OpenMPIRBuilder subset;
`LLVMFrontendTests` in full is 1281. Both are clean; the numbers measure different things.

`211566-reland-reduction-debugloc.patch` is the fix as it stands. The old
`211395-reduction-helper-debugloc.patch` was dropped, since that PR is closed.

## Conformance check

The reproducer uses only `reduction(+:s)` with no `map` clause, so there is no question of combining
a data-sharing clause with an explicit map of the same variable. clang accepts the direct C analogue
(`#pragma omp target teams distribute parallel for reduction(+:s)`) with no diagnostics.
