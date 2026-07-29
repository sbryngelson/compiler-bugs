# Upstream LLVM defects

Defects that reproduce on **stock upstream LLVM**, not only on a vendor fork. These belong to
<https://github.com/llvm/llvm-project> rather than to HPE/Cray, AMD, or Intel, and are tracked
here separately so they are not mis-filed with a vendor.

A defect lands here only if it has been shown to reproduce on a non-vendor build — in practice
by running the same reproducer through more than one LLVM (the ROCm-shipped `llc`/`opt` are
useful for this, being different major versions from CCE's).

| entry | version(s) | filed | summary |
|---|---|---|---|
| [mir-unquoted-bb-name](mir-unquoted-bb-name) | LLVM 21.1.8, 22.0.0 | **[llvm#212785](https://github.com/llvm/llvm-project/issues/212785)** | `llc` emits MIR it cannot re-parse when a basic-block name contains a comma. Blocks `-stop-before` MIR round-tripping, the normal way to reduce a backend bug to a MIR test |

## Filing checklist

Before posting upstream:

1. Reproduce on a non-vendor LLVM and record the version.
2. Search existing issues — note near-misses explicitly in the report so it is not closed as a
   duplicate (see the `Related but distinct` section of the draft).
3. Keep the reproducer minimal and self-contained; state the exact commands and the exact error.
4. Point at the suspected code site if it is known, but say plainly whether the fix was built or
   tested. An untested patch wastes reviewer time.
