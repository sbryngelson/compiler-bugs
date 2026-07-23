# flang/OpenMP: segfault in `OpenMPIRBuilder::createParallel` for `linear()` on a target/simd construct

**Status: OPEN.** Reported: [llvm/llvm-project#211429](https://github.com/llvm/llvm-project/issues/211429).

```
flang -fc1 -emit-llvm -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -O3 -o /dev/null repro.f90
  -> Segmentation fault
```

Deterministic, 20/20 at `02c51adb8ff2`. `-emit-hlfir` is clean 20/20, so it is in the outlining
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
