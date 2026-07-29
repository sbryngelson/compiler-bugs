<!-- FILED as https://github.com/llvm/llvm-project/issues/212785 on 2026-07-29. Kept as the submitted text.
     Original draft target:
     Suggested labels: mir, backend:AMDGPU (reproduces on any target), bug
     Review before posting. -->

# Title

`llc` emits MIR it cannot re-parse when a basic block's name contains a comma

# Body

`MachineBasicBlock::printName` writes the IR basic-block name after `bb.<N>.` **unquoted**. If
the name contains a comma, `llc -stop-before=...` produces a `.mir` file that `llc -x mir` then
rejects — `llc` cannot read back what `llc` just wrote.

This breaks the standard `-stop-before` / `-start-before` MIR round-trip that is normally used to
reduce a backend bug to a MIR test case.

## Reproducer

`bb-comma-name.ll` (14 lines) — block names of the shape a Fortran front end typically emits:

```llvm
target triple = "amdgcn-amd-amdhsa"
define amdgpu_kernel void @k(ptr addrspace(1) %o, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %", bb71", label %"file f.f90, line 12, bb99"
", bb71":
  store i32 1, ptr addrspace(1) %o, align 4
  br label %"file f.f90, line 12, bb99"
"file f.f90, line 12, bb99":
  store i32 2, ptr addrspace(1) %o, align 4
  ret void
}
```

```console
$ llc -mcpu=gfx90a -stop-before=greedy bb-comma-name.ll -o out.mir
$ llc -mcpu=gfx90a -x mir -start-before=greedy out.mir -o /dev/null
error: out.mir:170:8: expected ':'
```

## What is emitted

```
  bb.1., bb71:
    successors: %bb.2(0x80000000)
```

The parser stops at the comma, having read `bb.1.` and then expecting `:`.

## Expected

Either quote the name when it contains characters the MIR parser treats as delimiters, or escape
it the way the rest of the printer already does.

## Where

`llvm/lib/CodeGen/MIRPrinter.cpp` calls `MBB.printName(OS, ...)`, and the name is emitted raw.
The same file already uses `printLLVMNameWithoutPrefix(OS, V.getName())` elsewhere for exactly
this purpose, so an escaping helper is available a few hundred lines away — reusing it in
`MachineBasicBlock::printName` looks like the natural fix. A MIR round-trip test with a
comma-containing block name would guard it.

## Versions affected

Reproduces byte-identically on:

- LLVM 22.0.0 (ROCm 7.2.0)
- LLVM 21.1.8 (HPE Cray CCE 21.0.2)

Not target-specific — the AMDGPU triple above is incidental; the printing path is common.

## How it was hit

Cray's Fortran front end names outlined blocks `file <name>, line <n>, bb<k>` and `, bb<k>`, so
every MIR dump from a Fortran offload build is unparseable. This blocked MIR-level reduction of
an unrelated register-allocator assertion, which had to be reduced at IR level instead.

## Related but distinct

[#87817](https://github.com/llvm/llvm-project/issues/87817) — also "MIR that `llc` cannot parse",
but a different cause (concatenated debug-info metadata, `'!20!22'`). Same symptom class,
different root cause; filing separately rather than commenting there.
