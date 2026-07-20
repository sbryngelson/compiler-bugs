# amdflang: false `nuw`/`nusw` flags on box-based array addressing → silent miscompiles

Target: gfx90a (MI250X, MI210) — but the miscompiled routine is **host** code. Compiler: amdflang
23.0.0git (therock-afar 23.2.0 / 23.2.1). Clean on the 23.1.0 drop.

**Status: FIXED UPSTREAM, AWAITING AN AFAR DROP.**
Reported: [ROCm/llvm-project#3471](https://github.com/ROCm/llvm-project/issues/3471).
Upstream fix: [llvm/llvm-project#198014](https://github.com/llvm/llvm-project/pull/198014)
(`2315381d7112`, merged 2026-05-20, fixes [llvm#197393](https://github.com/llvm/llvm-project/issues/197393)).
Every 23.2.x drop we have predates it.

## Bug

flang stamps unsigned-no-wrap flags — `nusw nuw` on `array_coor` GEPs and `nuw` on the associated
index `add`/`mul` — **unconditionally**, including for **box-based (descriptor) arrays**. For a
descriptor array those offsets are legitimately negative:

- a non-default / negative lower bound (MFC's ghost-cell arrays start at `-buff_size`),
- a negative-stride section (`s_cb(i+4:i-3:-1)`), whose box base points at the *end* of the section,
- more generally any box base that doesn't point at the first element.

The `nuw` claim is then false ⇒ **poison** ⇒ any correct optimizer may legally produce garbage. The
damage is context-dependent: the flags sit inert in unoptimized IR and only bite when some pass
exploits them.

In MFC this hit `s_compute_weno_coefficients` (WENO7 coefficient tables, setup-time host code with
five reversed slices). The tables come out slightly wrong, the ill-conditioned WENO weights amplify
it, and the golden tests fail with **abs 2.1e-4** on density localized at shock fronts —
deterministic, and a wrong *answer* rather than a crash. It surfaces in GPU builds only because
those compile the host with amdflang (CPU CI uses gfortran).

Regression window: introduced by
[llvm/llvm-project#184573](https://github.com/llvm/llvm-project/pull/184573) (`7e0ef4a203`,
"[Flang] Apply nusw nuw flags on array_coor gep's", 2026-03-13) — one day after the 23.1.0 drop was
cut (03/12), which is exactly why 23.1.0 is clean and 23.2.0 (04/18) is not.

## Root cause

#184573's own guard is incomplete: it protects only `sub` for shifted arrays, leaving the add/mul/GEP
flags unconditional —

```cpp
auto subFlags = isShifted ? mlir::LLVM::IntegerOverflowFlags::nsw
                          : mlir::LLVM::IntegerOverflowFlags::nsw |
                            mlir::LLVM::IntegerOverflowFlags::nuw;
// ... but addMulFlags stays nsw|nuw for every case, and `mul nuw` on index x stride
//     is false for any negative stride regardless of the lower bound.
```

#198014 fixes it where it belongs — no `nuw` on mul/add/GEP when lowering `array_coor` from a box
base — with the same reasoning we arrived at independently ("offsets are going to be negative;
setting nuw ... produces poison values").

There is **no flag to disable the emission** in 23.2.x. `-fwrapv` is accepted but only removes `nsw`
(1132 → 26); the bogus `nuw` survive untouched.

## Evidence

No standalone reproducer: hand-reduction to a single loop does *not* trigger it (see
`artifacts/standalone_repro_attempt.f90`) — the classic signature of poison exploitation, where
whether you get wrong code depends on surrounding context. The proof is therefore a flag census plus
a causality matrix on the real translation unit.

Frontend IR of the same TU, `-O3 -mllvm -opt-bisect-limit=0 -S -emit-llvm`
(`artifacts/pre_23.*.flags-excerpt.ll`):

| | gep `nusw nuw` | `add nuw` | `mul nuw` | `sub nuw` | `add nsw` |
|---|---|---|---|---|---|
| flang 23.1.0 | 0 | 0 | 0 | 0 | 1132 |
| flang 23.2.0 | **491** | **715** | **1136** | **62** | 417 |

Causality — same TU, same final backend lowering (`clang -c -O0` of the optimized `.ll`, relinked
into an otherwise identical binary), full WENO7 golden test as the oracle:

| experiment | result |
|---|---|
| 23.2.0 IR, unoptimized (no `opt`) | **PASS** — flags are inert until exploited |
| 23.2.0 IR → 23.2.0 `opt -passes='default<O3>'` | FAIL (abs 2.1e-4) |
| 23.2.0 IR → **23.1.0** `opt <O3>` | FAIL — the *old* optimizer miscompiles the new IR |
| **23.1.0 IR** → 23.2.0 `opt <O3>` | **PASS** — optimizer exonerated; the frontend is the culprit |
| 23.2.0 IR, strip `getelementptr nusw nuw` → 23.2.0 opt | error collapses 2.1e-4 → 3.2e-9 |
| 23.2.0 IR, strip **all** `nuw` (keep `nsw`) → 23.2.0 opt | **PASS** |

A run-based `-opt-bisect-limit` bisection (`artifacts/run_bisect_evidence.txt`) localizes the first
*value-changing* exploitation to `loop-unroll-full` invocation 704. That pass is innocent — it is
value-exact by construction and merely the first consumer of the poison — but it is what a naive
bisect blames, which cost us a day. Corroborating tells that it was UB rather than a bad transform:
the standalone repro vanished, `-fno-unroll-loops` / `-unroll-count=1` / `-unroll-full-max-count=0`
all failed to help, and `-O1` (which also runs full unroll, 84×) passes anyway.

## Workaround

Rewrite the negative-stride sections element-wise — value-identical, and it removes the false-claim
sites at the source:

```fortran
! before (reversed-stride section: box base at the section end, negative offsets)
y = s_cb(i + 1:i - 2:-1) - s_cb(i:i - 3:-1)

! after (plain indexed accesses: offsets >= 0, so the nuw claims are true)
y(1) = s_cb(i + 1) - s_cb(i)
y(2) = s_cb(i)     - s_cb(i - 1)
y(3) = s_cb(i - 1) - s_cb(i - 2)
y(4) = s_cb(i - 2) - s_cb(i - 3)
```

Verified: WENO7 fails before / passes after on 23.2.0 at full `-O3`. MFC fix:
[MFlowCode/MFC#1660](https://github.com/MFlowCode/MFC/pull/1660).

This is per-pattern, not a cure. The false flags are emitted in **every TU** of a 23.2.x build —
WENO7 was simply the canary with 1e-9 golden tolerances. Until a drop carries #198014, treat
23.2.0/23.2.1 as unsafe for Fortran using descriptor arrays with shifted bounds or negative strides,
and keep Frontier pinned to 23.1.0.

Also of note, and unrelated to this bug: an `-O1` gate on the affected TU silences the failure, but
only by luck of which passes fire — the poison is still there.

## Files

| | |
|---|---|
| `artifacts/m_weno_coefficients.fpp` | the affected routine (fypp source) |
| `artifacts/s_compute_weno_coefficients.expanded.f90` | preprocessed, compilable form |
| `artifacts/pre_23.1.0.flags-excerpt.ll`, `pre_23.2.0.flags-excerpt.ll` | the flag diff that *is* the bug (excerpts of the full frontend IRs) |
| `artifacts/flag_census_and_experiments.txt` | full census + the strip / cross-version legs |
| `artifacts/run_bisect_evidence.txt` | run-based opt-bisect localizing the first exploiting pass |
| `artifacts/standalone_repro_attempt.f90` | failed hand-reduction (context-dependence evidence) |
| `artifacts/compile_command.txt`, `versions.txt` | exact command, drop/commit identities |
