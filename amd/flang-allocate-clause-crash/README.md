# flang/OpenMP: segfault lowering the `allocate` clause on a worksharing loop

**Status: OPEN, root-caused 2026-08-04. Not an offload bug** — it reproduces on ordinary host
compilation with no `target` construct anywhere; the offload framing in the first version of the
report was wrong.

Reported: [llvm/llvm-project#211430](https://github.com/llvm/llvm-project/issues/211430).

```
flang -fc1 -emit-hlfir -fopenmp -fopenmp-is-target-device \
      -triple amdgcn-amd-amdhsa -o /dev/null repro.f90
  -> Segmentation fault (most of the time)
```

## Root cause (2026-08-04)

Two separate defects, stacked. The version gate explains *when*; the memory error explains *how*.

**1. `allocate` has no minimum-version gate in `OMP.td`.** `allocate` is an OpenMP 5.0 clause, but
58 of the 62 directives that list it declared it as bare `VersionedClause<OMPC_Allocate>`. The
default in `llvm/include/llvm/Frontend/Directive/DirectiveBase.td:155` is `min = 1`:

```
class VersionedClause<Clause c, int min = 1, int max = 0x7FFFFFFF> : Versioned<min, max> {
  Clause clause = c;
}
```

so semantics accepted the clause at *every* version. Only four were correct (`Do`, `TaskGroup`,
`ParallelDo` at 50; `Scope` at 52). Upstream flang defaults to **OpenMP 3.1**
(`newestFullySupported = 31`, `flang/lib/Frontend/CompilerInvocation.cpp:1260`), so an invocation
with no `-fopenmp-version=` lands squarely in the ungated range. Semantics waves the clause
through, `ConstructDecomposition` then correctly refuses to decompose it, and lowering consumes the
empty result.

**2. Consuming the failed decomposition reads uninitialized memory.** In an assertions build this
is caught at `flang/lib/Lower/OpenMP/Decomposer.cpp:85`:

```
Assertion `!decompose.output.empty() && "Construct decomposition failed"' failed.
```

In a release build there is no check and it is undefined behavior. That is the whole of the
reported nondeterminism, and it is **ASLR-dependent** — the clean signature of an uninitialized or
dangling pointer read. Unpatched release build, `repro.f90`, `-fopenmp-version=31`, 40 trials each:

| | segfaults |
|---|---|
| ASLR on (normal) | **25/40** |
| ASLR off (`setarch -R`) | **0/40** |

So the use-after-free / uninitialized-read hypothesis in the issue body is **correct**. An earlier
revision of this entry claimed the opposite — that pinning `-fopenmp-version` made it deterministic
20/20 and refuted the hypothesis. That was measured against an assertions build, where the assert
fires before the UB and so *is* deterministic. Pinning the version does not stabilize the release
build: it is 12/20 at v31 and 12/20 at v45 on a fixed version.

Version matrix, unpatched release build, 20 trials each:

| `-fopenmp-version` | result |
|---|---|
| 31 (the default) | 12/20 segfault |
| 45 | 12/20 segfault |
| 50 | 0/20, compiles |
| 52 | 0/20, compiles |
| 60 | 0/20, compiles |

The clause is genuinely legal at 5.0+, which is why the high versions are clean. Nothing about the
module wrapper, the `target` construct, or the loop body matters except insofar as they route to a
directive whose `allocate` was ungated.

## Fix

Gate the clause. All 58 bare occurrences in `llvm/include/llvm/Frontend/OpenMP/OMP.td` become
`VersionedClause<OMPC_Allocate, 50>`; `Scope` stays at 52. Final state: 0 ungated, 61 at min-50,
1 at min-52. The patch is metadata only — 58 insertions, 58 deletions, one file.

All six probes that hit the decomposition assert now produce a proper diagnostic instead of
crashing:

```
error: ALLOCATE clause is not allowed on TARGET TEAMS DISTRIBUTE PARALLEL DO directive
       in OpenMP v4.5, try -fopenmp-version=50
```

Verified on the assertions build: diagnostic at v31/v45, and 0/20 at v50/v52/v60 where it still
compiles unchanged.

### Regressions (2026-08-04, complete)

Nine lit tests, not the eight predicted. All nine exercise `allocate` through bare
`%openmp_flags`, which is `-fopenmp` with no version, so they ran at the default 3.1 and silently
depended on the missing gate. Fix is a RUN-line flag in each:

| test | flag added |
|---|---|
| `flang/test/Lower/OpenMP/{distribute,parallel,parallel-sections,sections,single,task,taskloop}.f90` | `-fopenmp-version=50` |
| `flang/test/Semantics/OpenMP/{allocators02,allocators03}.f90` | `-fopenmp-version=52` |

The two `allocators` tests were not predicted and are the more interesting pair: both carry an
`! OpenMP Version 5.2` header comment but never passed the flag, so they were asserting 5.2
semantics against a 3.1 invocation. They get 52 rather than 50 to match what they document.
`allocate_do1.f90` was predicted to fail and does not — it already pins a version.

Four of the seven `Lower` tests have two RUN lines (`%flang_fc1` and `bbc`); both need the flag,
which is easy to miss since only the first failure is reported.

Clean after the fix, on the patched build:

| suite | tests | failed |
|---|---|---|
| `flang/test` (full `check-flang`) | 4808 | **0** |
| `mlir/test/Dialect/OpenMP` + `Target/LLVMIR` + `llvm/test/Frontend` | 425 | **0** |
| `clang/test/OpenMP` | 1594 | **0** |

clang is unaffected because it version-checks `allocate` in its own semantic analysis rather than
relying on the table, but it shares `OMP.td`, so it was worth confirming.

**This fixes the reachability, not the memory error.** Defect 2 is still latent: any other clause
or directive combination that makes `ConstructDecomposition` return empty will hit the same
uninitialized read in a release build. The assert is only a debug-build backstop. A complete fix
would also make the failure path emit a diagnostic and bail rather than fall through. Worth saying
so in the PR so it is not mistaken for a full fix.

## History

Filed originally as a target/module/non-deterministic crash. That framing was wrong on two of three
counts — the simplest reproducer has no `target` at all, and the module wrapper is irrelevant. The
nondeterminism was real.

| directive (identical body) | crashes |
|---|---|
| `parallel do private(t) allocate(t)` (`repro_host_no_target.f90`) | 10/10 host |
| `parallel do private(t)` (`control_private_only.f90`) | 0/10 |
| `target teams distribute parallel do private(t) allocate(t)` (`repro.f90`) | 7/10 host, 14/20 device |
| `target teams distribute parallel do private(t)` | 0/20 |
| `private(t) allocate(t)`, bare subroutine (`nocrash_bare_subroutine.f90`) | 0/20 |

The first control published was measured against a module with a *different* loop body, so it
isolated more than the clause; the table above is the corrected version. One captured stack:

```
 #4 llvm::omp::getDirectiveAssociation(llvm::omp::Directive)
 #5 genOMPDispatch(Fortran::lower::AbstractConverter&, ...)
```

Not reproduced on AFAR 23.2.1 or ROCm 7.2.0 (0/10 each) — both predate the affected code.

## Found by

The assertions-build crash hunt (`/work1/.../crashhunt/hunt.sh`), which swept generated and battery
probes across `-fopenmp-version` 31/45/50/52/60 and turned up exactly two distinct assertions: this
one (6 hits) and `lastiter in CanonicalLoopInfo is nullptr` (18 hits, see
`../flang-linear-target-crash/`).
