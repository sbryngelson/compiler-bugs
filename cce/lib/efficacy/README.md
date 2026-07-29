# Directive-efficacy harness

Differential tester for "does this compiler directive actually do anything?" — built after
`!DIR$ INLINENEVER` turned out to behave differently on host and device paths.

## Method

For each directive, compile an identical program **with** and **without** it, on the host path
and the device path, and compare *normalized* output:

| host | device | reading |
| --- | --- | --- |
| differs | differs | takes effect on both |
| differs | same | **silently ignored on device** |
| same | differs | device-only effect |
| same | same | no effect in this test shape (may simply be inapplicable) |

```console
$ ./efficacy.sh INLINENEVER INLINEALWAYS NOINLINE NOUNROLL NOFUSION VECTOR
control ok: identical inputs compare identical
DIRECTIVE       HOST      DEVICE    VERDICT
INLINENEVER     differs   differs   takes effect on both
...
```

## Why it took three attempts to make trustworthy

Every one of these produced confident, wrong answers first:

1. **Metadata noise.** Raw IR diffs are dominated by `!123` renumbering and SSA temp names. The
   first run reported almost everything as "changed". `norm.sh` strips metadata refs, SSA
   numbering, and whitespace.
2. **The source path leaks into the IR.** Cray names basic blocks `"file <path>, line N, bbK"`,
   so the *same* source compiled as `base/p.f90` and `test/p.f90` differs. Comparing
   differently-named files silently added ~4 diff lines to every result. Fixed by compiling
   sequentially in one directory under one filename — safe because compilation is deterministic
   (verified: two compiles of the same file give a 0-line diff).
3. **No self-check.** With the first two problems present the harness still looked plausible.
   It now runs a **control first** — identical input compared against itself — and aborts if
   that does not come out identical. A harness that cannot detect its own noise floor is worse
   than no harness, because its output looks like data.

The general rule this encodes: **validate the comparator against a case whose answer you already
know, and let it overturn you.** The corrected `INLINENEVER` result came from exactly that — the
normalizer disagreed with a conclusion I had already written down, and the normalizer was right.

## Extending it

`gen.py` emits the test program; add a shape there if a directive needs a different context
(the loop-level ones need a loop, `IGNORE_TKR` needs a mismatched-type call, and so on). A
`same/same` verdict usually means the shape does not exercise the directive, not that the
directive is dead.
