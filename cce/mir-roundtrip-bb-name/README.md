# Cray CCE 21.0.2 (LLVM 21.1.8): `llc` emits MIR its own parser cannot read

**Status: confirmed. Minor severity — blocks MIR-level debugging, not builds.**

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed |
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
