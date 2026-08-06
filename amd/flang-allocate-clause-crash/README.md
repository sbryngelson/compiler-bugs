# flang/OpenMP: segfault lowering the `allocate` clause on a worksharing loop

**Status: OPEN, root-caused and patch posted 2026-08-04. Not an offload bug** — it reproduces on
ordinary host compilation with no `target` construct anywhere; the offload framing in the first
version of the report was wrong.

| | |
|---|---|
| Issue | [llvm#211430](https://github.com/llvm/llvm-project/issues/211430) — root cause posted [as a comment](https://github.com/llvm/llvm-project/issues/211430#issuecomment-5181030223) |
| Crash fix PR | [llvm#214012](https://github.com/llvm/llvm-project/pull/214012) — `Diagnose failed construct decomposition instead of falling through`. **MERGED 2026-08-04.** Stops the segfault for *any* directive/clause pair that decomposes empty |
| Diagnostic PR | [llvm#213980](https://github.com/llvm/llvm-project/pull/213980) — gated in `OMP.td` for both frontends. Briefly reworked into flang semantics on 2026-08-04 to dodge the clang fallout; kparzysz rejected that and asked for the table fix, so the 83 clang tests were converted instead. Approved by kparzysz, direction confirmed by alexey-bataev, **green on all four platforms 2026-08-05**. Open, awaiting a committer |

The PR deliberately does **not** carry a `Fixes` keyword and the issue comment says explicitly not
to close #211430 on it: the gate removes reachability, the uninitialized read is untouched. See
"Fix" below.

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
| ~~`clang/test/OpenMP`~~ | ~~1594~~ | ~~0~~ **INVALID, see below** |

### The clang result was bogus and the approach is wrong (2026-08-04)

**Premerge CI failed on all four platforms: 85 `Clang :: OpenMP/*` tests.** The local
`clang/test/OpenMP` 1594/0 above is worthless — `bin/clang-24` in that build tree is dated
2026-07-23, twelve days before the patch. Only flang targets were rebuilt, so clang was never
relinked and the suite ran against a binary compiled from the *unpatched* `OMP.td`. A green result
from a stale binary, taken as evidence.

Worse, I then wrote a mechanism to explain it — "clang version-checks `allocate` in its own
semantic analysis rather than relying on the table" — which is false. `ParseOpenMP.cpp:3229` calls
the same table:

```cpp
!isAllowedClauseForDirective(DKind, CKind, getLangOpts().OpenMP)
```

so clang is fully affected. **Check the binary's mtime before trusting a suite that passed.**

Substantively, this means the change is not a flang metadata fix at all. clang has accepted
`allocate` below 5.0 for years and its tests encode that deliberately — e.g.
`clang/test/OpenMP/distribute_simd_ast_print.cpp` runs at `-fopenmp-version=45` with CHECK lines
asserting the clause round-trips. 269 clang OpenMP tests use `allocate(`. Gating the clause is
spec-correct but is a cross-frontend behaviour change needing clang OpenMP owners' consent, not a
drive-by.

(Two `Flang ::` tests also failed in CI, `Fir/dispatch.f90` and `Lower/array.f90`. Neither is an
OpenMP test — `Fir/dispatch.f90` does not contain the string at all — and neither is touched by the
patch, so they are unrelated to it.)

**The better fix for #211430 is defect 2, not defect 1.** Making `buildConstructQueue` diagnose and
bail instead of falling through the failed decomposition fixes the crash for *every* clause and
directive combination that decomposes empty, needs no version-table change, and does not perturb
clang:

```cpp
ConstructDecomposition decompose(modOp, semaCtx, eval, compound, clauses);
assert(!decompose.output.empty() && "Construct decomposition failed");   // <- release builds fall through
```

The version gate remains defensible as a separate cleanup, but on its own merits and with the clang
test churn owned up front — not as a crash fix.

**Those three numbers were measured at `d1d3891` (2026-07-23), not at the PR's base.** `OMP.td`
drifted upstream in between (16/5 lines, the unrelated `default`/`update` clause split); the nine
test files did not. Re-derived on `e7713ee70b87` the transformation is identical — 58 ungated and 4
gated before, 0/61/1 after — and `llvm-tblgen --gen-directive-impl` on the two versions of the file
differs by exactly 58 hunks, each `1 <= Version` becoming `50 <= Version`, which is the whole
intended effect and nothing else. Behavioural re-verification at the new base is premerge CI's job;
as of 2026-08-04 the four Build-and-Test checks are still pending, `code_formatter`,
`Check LLVM_ABI annotations` and the mergeability checks are green.

A local rebuild at the new base was attempted and abandoned: the configure omitted `-G Ninja` so
CMake emitted Makefiles, `ninja` then died on a missing `build.ninja`, and the wrapper still
reported success because the captured exit status was a trailing `echo`'s. Premerge CI covers
Linux/AArch64/Windows/macOS anyway, which is strictly more than the single local config, so it is
the better check rather than a fallback.

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

## The crash fix that actually shipped (llvm#214012, 2026-08-04)

Rather than gate the clause, harden the consumer. `buildConstructQueue` now emits a located
diagnostic and exits instead of falling through an empty decomposition:

```cpp
if (decompose.output.empty()) {
  // ...resolve `source` to a FileLineColLoc via semaCtx.allCookedSources()...
  fir::emitFatalError(loc,
      llvm::Twine("OpenMP construct decomposition failed: a clause on '") +
          llvm::omp::getOpenMPDirectiveName(compound, llvm::omp::FallbackVersion) +
          "' cannot be applied to any of its leaf constructs",
      /*genCrashDiag=*/false);
}
```

`fir::emitFatalError` is the idiom for this in `flang/lib/Lower` — there is no `_err_en_US`
precedent there, since lowering runs after semantics has finished reporting. `genCrashDiag=false`
means it exits non-zero with the message and no backtrace, so it does not present as a compiler
crash.

The first version used `modOp.getLoc()` and printed `loc(".../repro.f90":0:0)`, which is useless.
Resolving the directive's own `parser::CharBlock` through
`semaCtx.allCookedSources().GetProvenanceRange()` and `allSources().GetSourcePosition()` gives the
real position — the same path `AbstractConverter::genLocation` takes, but reachable without a
converter, which `buildConstructQueue` does not have.

Result on `repro.f90` at the default 3.1, 40 trials:

| | before | after |
|---|---|---|
| segfaults | 25/40 | **0/40** |
| clean exit-1 with diagnostic | 0/40 | **40/40** |

```
error: loc("repro.f90":6:11): OpenMP construct decomposition failed: a clause on
       'target teams distribute parallel do' cannot be applied to any of its leaf constructs
```

`check-flang` 4808/0 locally; premerge Linux and AArch64 green.

This covers every directive/clause pair that decomposes empty, not just `allocate`, so #211430
stops segfaulting regardless of how the gating question resolves. What #213980 would add on top is
the *correct* diagnostic naming the clause and version, rather than this generic one.

## Gating #213980, resolved 2026-08-05

kparzysz: fix it in `OMP.td` so it covers both frontends, and either gate everywhere or drop the
`50` everywhere. alexey-bataev settled the clang half — "Clang default is 5.2, IIRC, so it should
not cause big troubles" — so gating won. 58 instances changed, 3 already gated, 61 total, none left
ungated.

That makes 83 `clang/test/OpenMP` tests fail, in four shapes, not the two the PR first claimed:

| | files | change |
|---|---|---|
| annotation only | 32 | add `omp45-error N {{unexpected OpenMP clause 'allocate' ...}}` |
| annotation + warning | 35 | plus 49 `expected-warning` instances narrowed to `ge50-warning` |
| bare `-verify` | 5 | convert to prefixed `-verify`, then as above |
| `-ast-print` / codegen | 11 | version-guard the pragma, split FileCheck lines by prefix |

Result: 1550 passed, 0 failed locally, then green on Linux, Linux AArch64, Windows and macOS.

**Precedent.** [llvm#151154](https://github.com/llvm/llvm-project/pull/151154) gated `if` on
`do simd` the same way (`VersionedClause<OMPC_If>` -> `<OMPC_If, 50>`) and landed as *one line plus
two tests*, because `OMP_DoSimd` is a separate record from `OMP_ForSimd` and never reaches clang.
`allocate` sits on shared directives, which is the whole reason this one is 94 files. Worth citing
when a reviewer asks why the diff is so much bigger than the obvious precedent.

`ge50` was **not** invented here: it already exists in 12 clang tests alongside `lt50` and `ge60`,
with occurrence counts. Verify that kind of claim against pristine `HEAD`, not the working tree —
the first grep matched the edits under review and would have "confirmed" an invention.

### Four things that cost time

**Annotating cannot work when a RUN line has no `-verify`.** The `-ast-print` tests carry
`-emit-pch` runs without it, so a new error is fatal there no matter what is annotated. Those need
the clause removed from the pre-5.0 source path, not a diagnostic expectation.

**Do not expand a CHECK line that is already version-specific.** These files carry `OMP45`/`OMP50`/
`OMP51`/`OMP52` lines as four alternatives for one output line. A splitter that treats each as
generic turns 4 lines into 16. Expand only bare `CHECK`; on an existing `OMP45` line just strip the
clause.

**`#ifndef HEADER` breaks naive depth tracking.** Every one of these tests opens with it, so a
"is this pragma at depth 0" test finds nothing. Seven sites were silently skipped until the guard
was special-cased.

**Line numbers captured before an edit pass are worthless after it.** A hardcoded site list built
from a post-CHECK-insertion dump rejected 7 of 16 sites on the reverted files. The assertion in the
wrapper is the only reason it failed loudly instead of editing the wrong lines. Prefer
content-matching over line numbers for anything applied more than once.

**Verification note:** the binary was confirmed newer than the patched source (12:11:16 vs
11:13:52) before any of these numbers were taken — the check whose absence invalidated the clang
run above. An earlier build of this same fix was silently killed at 530/586 by a session restart,
and a later one failed because the cluster updated its libstdc++ headers mid-session
(`c++config.h` 128855 -> 129531 bytes), invalidating all ten precompiled headers; deleting the
`.pch` files fixed it.


## Why the gate moved out of OMP.td (2026-08-04)

`OMP.td` is shared with clang: `ParseOpenMP.cpp` calls the same
`isAllowedClauseForDirective(D, C, getLangOpts().OpenMP)`. Gating `allocate` there broke **83**
`Clang :: OpenMP` tests, measured on a clang actually rebuilt from the gated table:

| suite | with the OMP.td gate |
|---|---|
| `clang/test/OpenMP` | 1594 tests, **83 failed** |
| `flang/test` | 4808 tests, 9 failed |

Of the 83, **72 are `_messages` sema tests** and only 10 `ast_print`, 1 codegen. The sema ones are
the blocker: each runs the *same source* at 4.5 and at 5.0+, so a bare `expected-error` for the
version rejection would be wrong on the 5.0+ runs. Fixing them properly means converting them to
prefixed `-verify=omp45,omp50` expectations. Only 11 of 83 already have a dedicated pre-5.0
check-prefix. 167 lines contain `allocate(`, but just 16 CHECK lines expect it, so the work is the
verify conversion, not CHECK churn.

Gating per language is not expressible today: `languages` is a field on `Directive`
(`DirectiveBase.td:263`), not on `Clause` or `VersionedClause`, and
`isAllowedClauseForDirective` takes no language argument.

So the restriction now lives in flang's `CheckAllowedClause`
(`flang/lib/Semantics/check-omp-structure.cpp`) as a small clause-minimum-version table. clang is
untouched by construction. Same diagnostic, same nine flang test updates, and
`clang/test/OpenMP` is back to 1594/0.

**Three stale-binary near-misses in this round**, all caught by checking mtimes before trusting a
result:

* The original 1594/0 that cleared the OMP.td version ran against a `clang-24` twelve days old,
  because only flang targets had been rebuilt.
* A `check-flang` run showed 0 failures because the nine test files in the source tree still
  carried the `-fopenmp-version=` fixes from the earlier experiment. Reverting them showed the
  real 9.
* Copying the edited `check-omp-structure.cpp` from a worktree on current `main` into the local
  tree (11 days older) failed to build with `no type named 'ClauseSet' in namespace 'llvm::omp'` --
  the same worktree-drift trap already recorded in `../openmp-outlined-not-inlined/README.md`.
  Apply the hunk at the local base instead of copying the file.
