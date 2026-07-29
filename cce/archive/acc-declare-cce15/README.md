# `!$acc declare` cases from CCE 15.0.1 (archived — status unknown)

> **Vintage:** CCE 15.0.1, circa 2023  
> **Reported as:** `OLCFDEV-1416`, `CAST-31898`  
> **Status:** **Unknown on any modern compiler.** Archived to keep them separate from the
> CCE 19→21 port defects, which are actively tracked in the parent directory.

Twelve reproducers exercising `!$acc declare create` / `declare link` on allocatable arrays and
nested derived types. They predate the CCE 19→21 port work by several years and are **not** part
of it.

## Why they are archived rather than tracked

They were re-run on **CCE 21.0.2 on 2026-07-29** and the result was inconclusive — because of a
defect in the reproducers, not the compiler:

| outcome | count |
| --- | --- |
| build and run, producing output | 11 |
| build failure (`test-bug7`, multi-TU module ordering) | 1 |
| run but produce **no output at all** (`test-bug6`, `9`, `11`, `12`) | 4 |

**None of the twelve self-check.** Each prints values and relies on a human comparing them
against an expectation that is not recorded anywhere in the directory. So the re-run establishes
only that they still compile and execute. It cannot say whether the original defects are fixed,
and the four silent ones are suspicious but uninterpretable without a reference result.

## What they would need to be useful again

A pass/fail criterion per case — the expected values, or a self-checking harness of the kind the
current entries use:

```
v_write nbad=0 of 64  PASS
```

Every actively-tracked entry in the parent directory self-verifies, specifically so that a
re-run on a new compiler answers the question by itself. These do not, which is why they are
archived rather than carried forward: an unscoreable reproducer is close to no reproducer, and
leaving them in the main list would imply a status nobody has established.

## Contents

`test-bug1` .. `test-bug12`, each with `test.f90` and `compile.sh`. The per-case descriptions
(which declare clause, which offload construct, what shape of data) are in the table retained in
the parent [`../../README.md`](../../README.md).
