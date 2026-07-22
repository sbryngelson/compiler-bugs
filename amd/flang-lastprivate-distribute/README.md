# flang/OpenMP: `lastprivate` on a `distribute` construct aborts the compiler

Target: gfx90a. Compiler: upstream flang 24.0.0git @ `02c51adb8ff2`; same on amdflang (AFAR 23.2.1).

**Status: OPEN.** Reported: [llvm/llvm-project#211401](https://github.com/llvm/llvm-project/issues/211401).

## Bug

```
error: flang/lib/Lower/OpenMP/DataSharingProcessor.cpp:424: not yet implemented:
  lastprivate clause in constructs other than simd/worksharing-loop/taskloop
LLVM ERROR: aborting
```

A hard compiler abort, not a diagnostic the user can act on.

| directive | result |
|---|---|
| `parallel do lastprivate(t)` | ok |
| `target parallel do lastprivate(t)` | ok |
| `target teams distribute parallel do lastprivate(t)` | **not yet implemented** |
| `target teams distribute lastprivate(t)` | **not yet implemented** |
| `target teams distribute parallel do simd lastprivate(t)` | ok |

It is `distribute` specifically. `insertLastPrivateCompare` handles the wsloop/simd/taskloop ops;
`omp::DistributeOp` falls through to the `TODO`.

## Workaround

Add `simd`. Verified correct on gfx90a, three runs of three — `lastprivate` returns 2000.0 for a
1000-iteration loop writing `a(i)*2`. See `lastprivate_simd_workaround.f90`.

## Why no patch

Correct `lastprivate` on `distribute` means identifying the last logical iteration across teams, not
within one loop nest. That is more than extending the `isa<>` chain and the semantics should be
settled by someone who owns the area.

## Reproducers

- `repro.f90` — the abort.
- `lastprivate_simd_workaround.f90` — runnable, prints the value and the expected value.

## Conformance check

clang accepts the direct C analogue (`#pragma omp target teams distribute parallel for
lastprivate(t)`) with no diagnostics, so the construct is fine and this is a flang gap.

The `simd` workaround returns the correct value both with and without an explicit `map` of the same
variable, so it does not rely on combining `lastprivate(t)` with `map(...:t)`.
