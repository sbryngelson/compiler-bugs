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

Confirmed against the specification, not just by cross-checking clang.

- OpenMP 5.2 [§11.6 distribute](https://www.openmp.org/spec-html/5.2/openmpse67.html) lists the
  allowed clauses as "allocate, collapse, dist_schedule, firstprivate, lastprivate, order, private".
  The only restrictions are that a list item may not be in both `firstprivate` and `lastprivate`,
  and that the conditional modifier must not be specified. The reproducer violates neither.
- OpenMP 5.0 [§2.13 combined/composite constructs](https://www.openmp.org/spec-html/5.0/openmpse22.html):
  "The effect of the lastprivate clause is as if it is applied ... to the distribute construct if it
  is among the constituent constructs."
- LLVM's own `OMP.td` lists `OMPC_LastPrivate` in `allowedClauses` for `OMP_Distribute`,
  `OMP_DistributeParallelDo` and `OMP_TargetTeamsDistributeParallelDo` — tables shared by clang and
  flang, so flang accepts the clause in semantics and then aborts in lowering.
- clang accepts the direct C analogue with no diagnostics.

The `simd` workaround returns the correct value both with and without an explicit `map` of the same
variable, so it does not rely on combining `lastprivate(t)` with `map(...:t)`.

## Scope: not offload-specific

The same NYI fires on host compilation with no offload flags:

| directive | device | host |
|---|---|---|
| `target teams distribute parallel do lastprivate(t)` | NYI | **NYI** |
| `target teams distribute parallel do private(t)` | ok | ok |

So it is `lastprivate` on `distribute` in general.
