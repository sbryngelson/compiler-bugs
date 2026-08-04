# flang/OpenMP: segfault in `OpenMPIRBuilder::createParallel` for `linear()` on a device target construct

**Status: OPEN, root-caused 2026-08-04, no patch.** Reported:
[llvm/llvm-project#211429](https://github.com/llvm/llvm-project/issues/211429); root cause posted
[as a comment](https://github.com/llvm/llvm-project/issues/211429#issuecomment-5181030424).

No fix is proposed because the choice is a design call for whoever owns that code: either give
`applyWorkshareLoopTarget` a lastiter slot, or reject `linear` on a device workshare loop until it
has one. Unrelated to [#213980](https://github.com/llvm/llvm-project/pull/213980) — this one is
version-independent.

```
flang -fc1 -emit-llvm -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -O3 -o /dev/null repro.f90
  -> Segmentation fault
```

Deterministic, 20/20 at `02c51adb8ff2`. Isolated with an identical module and body:

| clause | body | crashes |
|---|---|---|
| `linear(j)` | `j = j + 1; ...` (`repro.f90`) | 10/10 |
| *(none)* | same | 0/10 |
| `linear(j)` | `j` never modified (`repro_readonly_j.f90`) | **10/10** |
| `private(j)` | `j = j + 1; ...` (`control_private_j.f90`) | 0/10 |

The read-only row matters: the crash does not depend on assigning to the `linear` variable, so it is
not an argument about whether that assignment is conforming. `-emit-hlfir` is clean 20/20, so it is in the outlining
path rather than the frontend:

```
 #4 llvm::CodeExtractorAnalysisCache::findSideEffectInfoForBlock(llvm::BasicBlock&)
 #5 llvm::CodeExtractorAnalysisCache::CodeExtractorAnalysisCache(llvm::Function&)
 #6 llvm::OpenMPIRBuilder::createParallel(...)
```

Legal clause: `OMP.td` lists `OMPC_Linear` in `allowedClauses` for
`OMP_TargetTeamsDistributeParallelDoSimd`.

Not reproduced on amdflang AFAR 23.2.1 (LLVM 23) or ROCm 7.2.0 (LLVM 22) — possibly a 24-cycle
regression, not bisected.


## Corrected scope (2026-07-22)

`simd` is not required, and it is device-only:

| directive | host | device |
|---|---|---|
| `parallel do linear(j)` | 0/10 | 0/10 |
| `parallel do simd linear(j)` | 0/10 | 0/10 |
| `target teams distribute parallel do linear(j)` (`repro_no_simd.f90`) | 0/10 | **10/10** |
| `target teams distribute parallel do simd linear(j)` (`repro.f90`) | 0/10 | **10/10** |

Also independent of the module wrapper — a bare subroutine crashes 10/10 — and reproduced on a
pristine build of `02c51adb8ff2`.


## Root cause (2026-08-04)

An assertions build names it immediately. The stack above was a release-build symptom; the actual
failure is a null `LastIter`:

```
mlir/lib/Target/LLVMIR/Dialect/OpenMP/OpenMPToLLVMIRTranslation.cpp:4681:
  Assertion `loopInfo->getLastIter() && "`lastiter` in CanonicalLoopInfo is nullptr"' failed.
```

at the linear finalization site:

```cpp
// Emit finalization and in-place rewrites for linear vars.
if (!wsloopOp.getLinearVars().empty()) {
  llvm::OpenMPIRBuilder::InsertPointTy oldIP = builder.saveIP();
  assert(loopInfo->getLastIter() && "`lastiter` in CanonicalLoopInfo is nullptr");
```

`linear` finalization needs `lastiter` to know which iteration's value to copy out. Only the three
static-init paths allocate that slot — `OMPIRBuilder.cpp:5925`, `:6098`, `:6642`, each a
`CreateAlloca(..., "p.lastiter")` followed by `CLI->setLastIter(PLastIter)`. But on device,
`applyWorkshareLoop` never reaches them:

```cpp
// OMPIRBuilder.cpp:6497
if (Config.isTargetDevice())
  return applyWorkshareLoopTarget(DL, CLI, AllocaIP, LoopType, NoLoop);
```

and `applyWorkshareLoopTarget` contains no `setLastIter` at all — it hands the loop to
`__kmpc_*_static_loop_*` wholesale, so there is no lastiter slot to set. `LastIter` stays null and
the MLIR translation asserts on it.

That accounts for the whole scope table exactly: device-only (the early return is
`isTargetDevice()`-gated), `simd`-independent, module-independent, and independent of whether the
`linear` variable is assigned — none of those touch the dispatch.

**Version-independent**, unlike the `allocate` crash in `../flang-allocate-clause-crash/`. Same
assertion, `rc=134`, at every version:

| `-fopenmp-version` | 31 | 45 | 50 | 52 | 60 |
|---|---|---|---|---|---|
| result | assert | assert | assert | assert | assert |

So the `OMP.td` version-gate fix does not touch this one; `linear` is legal on these directives and
correctly gated already. A fix has to either give `applyWorkshareLoopTarget` a lastiter slot or
reject/diagnose `linear` on a device workshare loop until it does.

## Found by

18 hits in the assertions-build crash hunt (`/work1/.../crashhunt/hunt.sh`) — the larger of the two
distinct assertions it surfaced.
