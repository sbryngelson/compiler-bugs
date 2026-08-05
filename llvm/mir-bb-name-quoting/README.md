# MIR: llc emits basic-block names it cannot parse back

| | |
|---|---|
| Issue | [llvm#212785](https://github.com/llvm/llvm-project/issues/212785) |
| PR | [llvm#214054](https://github.com/llvm/llvm-project/pull/214054) |

`MachineBasicBlock::printName` wrote the IR block name after `bb.<N>.` unquoted, and the MIR lexer
read it back with `isIdentifierChar` only. A name containing a comma -- routine in Fortran-generated
IR -- made `llc` unable to parse the MIR `llc` had just written, breaking the `-stop-before` /
`-start-before` round-trip used to reduce backend bugs.

Both sides needed changing: the printer now uses `printLLVMNameWithoutPrefix`, and
`maybeLexMachineBasicBlock` accepts a quoted name via the same `lexStringConstant` /
`unescapeQuotedString` pair `lexName` already used for `%ir-block.`. `PrintBBRef` had the same
printer hole and is fixed too.

Verified round-trip stability, not just absence of an error: print -> parse -> print is byte-stable
apart from `ModuleID`, and names survive exactly, including embedded quote, backslash, tab and
newline (`\22`, `\\`, `\09`, `\0A`).

## Unrelated crash found alongside

`llc -x mir -stop-before=<pass>` segfaults on MIR input with plain block names, on unpatched `llc`,
in `AMDGPUDAGToDAGISel` -- it re-runs ISel on a MachineFunction that already exists. X86 survives the
same command. Not filed, and not related to this PR; `-run-pass=none` is the working idiom.
