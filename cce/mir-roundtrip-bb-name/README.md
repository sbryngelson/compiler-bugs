# Cray CCE 21.0.2 (LLVM 21.1.8): `llc` emits MIR its own parser cannot read

> **Severity:** Tooling only — blocks MIR-level bug reduction, no effect on generated code  
> **Fix belongs to:** **upstream LLVM** — reproduces on LLVM 22 as well as CCE 21  
> **Status:** Root-caused and reduced to a 14-line `.ll`. The MIR printer emits block names unquoted.  
> **Upstream:** tracked for filing at [`../../llvm/mir-unquoted-bb-name`](../../llvm/mir-unquoted-bb-name) — filed as [llvm#212785](https://github.com/llvm/llvm-project/issues/212785).

**Status: confirmed. Minor severity — blocks MIR-level debugging, not builds.**

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | n/a — upstream LLVM defect, filed as [llvm#212785](https://github.com/llvm/llvm-project/issues/212785) |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) (context) |
| Found while | reducing [`../lld-agpr-mfma-assert`](../lld-agpr-mfma-assert) |
## Symptom

`llc -stop-before=<pass>` writes MIR that `llc -x mir -start-before=<pass>` then rejects:

```
error: before.mir:91893:8: expected ':'
```

The offending line is a basic-block label:

```
  bb.0., bb71:
```

The IR basic-block name contains a comma, and the MIR printer emits it unquoted, so
`bb.0.<name>:` parses as `bb.0.` followed by junk. `-simplify-mir` does not help.

Fortran front ends readily generate such names; here they come from Cray Fortran compiling
MFC (https://github.com/MFlowCode/MFC) for `amdgcn-amd-amdhsa`.

## Why it matters

It blocks the standard reduce-at-the-MIR-level workflow. Hit while trying to reduce
`../cce21-lld-agpr-mfma-assert/`, which is a *machine*-level bug — MIR is exactly the right
level to minimise it, and this defect forces reduction to stay at the IR level instead.

Workaround: rewrite the labels before re-parsing, which loses the block names:

```bash
sed -E 's/^([[:space:]]*bb\.[0-9]+)[^:]*:/\1:/' before.mir > fixed.mir
```

Note that the normalised MIR then no longer reproduces the AGPR assertion, so this is not a
usable route for that bug — the trigger depends on state not preserved across MIR
serialisation.

## Reproducing

`repro/run.sh <module.bc>` on any Cray-Fortran-derived AMDGPU module with such block names;
`repro/bad_label_excerpt.txt` is the emitted text. A reduced input is in
`../cce21-lld-agpr-mfma-assert/repro/crashing_function.bc`.


## Root cause and minimal reproducer

`bb-comma-name.ll` (14 lines) names two basic blocks the way CCE's Fortran front end does —
`", bb71"` and `"file f.f90, line 12, bb99"`. The MIR printer emits the name after `bb.N.`
**unquoted**:

```
  bb.1., bb71:
    successors: %bb.2(0x80000000)
```

The MIR *parser* then stops at the comma:

```
error: m_CCE21.mir:170:8: expected ':'
```

`llc` cannot read back what `llc` just wrote.

## This is an upstream LLVM defect, not a Cray one

Run `./run.sh`:

| toolchain | emitted label | re-parse |
| --- | --- | --- |
| CCE 21.0.2 (LLVM 21.1.8) | `bb.1., bb71:` | **fails** — `expected ':'` |
| **ROCm 7.2.0 (LLVM 22.0.0)** | `bb.1., bb71:` | **fails** — `expected ':'` |

Byte-identical malformed output from stock LLVM 22. So unlike the other entries here, there is
nothing for HPE to backport and nothing CCE-specific to fix — this should be reported
**upstream to LLVM**. CCE only makes it *likely* to be hit, because its Fortran front end names
blocks with embedded commas (`file <name>, line <n>, bb<k>`); any front end that does so will
trip it.

## Why it matters despite being "tooling only"

It blocks `llc -stop-before` / `-start-before` MIR round-tripping, which is the standard way to
reduce a backend bug to a MIR test case. That is exactly the technique that would otherwise have
been used on [`../lld-agpr-mfma-assert`](../lld-agpr-mfma-assert) — a `SlotIndex` assertion deep
in register allocation, where a MIR-level reduction is the natural next step. It had to be
reduced at the IR level instead.

**Workaround:** quote the name, or rename the blocks before reduction (`opt -metarenamer`, or
strip names with `opt -strip`), at the cost of losing the source correlation that makes the
reduction readable.
