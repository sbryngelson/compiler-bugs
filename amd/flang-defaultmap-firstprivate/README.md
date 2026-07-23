# flang/OpenMP: `defaultmap(firstprivate:scalar)` is not implemented and aborts the compiler

**Status: OPEN.** Reported: [llvm/llvm-project#211433](https://github.com/llvm/llvm-project/issues/211433).

```
error: flang/lib/Lower/OpenMP/OpenMP.cpp:1715: not yet implemented:
  Firstprivate is currently unsupported defaultmap behaviour
```

Only this implicit-behavior is affected, and it is **not offload-specific**:

| clause | device | host |
|---|---|---|
| `defaultmap(firstprivate:scalar)` | **NYI** | **NYI** |
| `defaultmap(tofrom:scalar)` | ok | ok |
| `defaultmap(to:scalar)` | ok | ok |
| `defaultmap(default:scalar)` | ok | ok |
| `defaultmap(present:allocatable)` | ok | ok |
| no clause | ok | ok |

Reproduces on upstream flang `02c51adb8ff2`, AFAR 23.2.1 and ROCm 7.2.0. clang accepts the direct C
analogue, so the clause is valid.

## Why it matters here

MFC's `src/common/include/omp_macros.fpp` emits `defaultmap(firstprivate:scalar)` on the NVIDIA and
Cray paths. The AMD path (`omp_macros.fpp:184`) omits it, which is the only reason MFC does not hit
this today. See also `cce/defaultmap-firstprivate` — the same clause is miscompiled by CCE 19.

Related: [#211401](https://github.com/llvm/llvm-project/issues/211401), another not-yet-implemented
in the same area.
