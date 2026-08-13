# MIR: llc emits basic-block names it cannot parse back

| | |
|---|---|
| Issue | [llvm#212785](https://github.com/llvm/llvm-project/issues/212785) |
| PR | [llvm#214054](https://github.com/llvm/llvm-project/pull/214054), **merged 2026-08-12** (`2ea42bcc3192`) |

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

## Post-merge review, arsenm 2026-08-12

Merged first, reviewed after -- normal in LLVM, and worth expecting rather than treating as done.
Three comments, follow-up in [llvm#216039](https://github.com/llvm/llvm-project/pull/216039):

* **Missing error test.** The new quoted-name branch calls `ErrorCallback` when `lexStringConstant`
  fails and nothing exercised it. Fair: the path could have been dead or wrong and every test would
  still have passed. New `llvm/test/CodeGen/MIR/Generic/unterminated-quoted-block-name.mir` feeds it
  `bb.0."unterminated`.
* **`-filetype=null` rather than `-o /dev/null`** on the parse-back RUN. Verified it works with
  `-x mir -start-before=greedy` and leaves no output file behind.
* **"Use new triples."** Unresolvable from the tree: `-mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a` is
  what the test already uses and what the rest of `llvm/test/CodeGen` uses (127 files, vs 21 bare
  `amdgcn` and one `amdgcn-unknown-amdhsa`), and a target-id-in-triple form appears **zero** times
  under `llvm/test`. Asked rather than guessed.

**The error test was checked for vacuity before sending.** The diagnostic string
`unable to parse quoted string from opening quote` exists at *two* sites in `MILexer.cpp`, so a
passing test does not prove the new branch at line 349 ran rather than the pre-existing one at 566.
Disabling the new branch and relinking gives `expected ':'` and a FileCheck failure; with it, the
real message. Only then is the test evidence of anything. Same lesson as the unroll metadata test in
`../flang-unroll-full/README.md`: see it fail on the thing it now catches.

A buildbot mail naming this commit (`llvm-clang-x86_64-expensive-checks-win`, build 245) was
infrastructure, not code: `LNK1116 ... error code 1450` is Windows `ERROR_NO_SYSTEM_RESOURCES`, the
other failure was `link.exe` itself hitting an access violation, builds 246 and 247 passed with the
same commit in them, and `LLVMMIRParser` is not even linked into the two binaries that failed.
Blamelists span everyone since the last green build.
