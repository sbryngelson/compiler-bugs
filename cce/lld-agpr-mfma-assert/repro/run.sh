#!/bin/bash
# Standalone reproducer: no MFC, no build system, no lld, no GPU, no MPI.
# Needs CCE 21.0.2's own LLVM (assertions enabled).
B=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
cd "$(dirname "$0")"
echo "== llc on the single crashing function =="
$B/llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a -filetype=obj -o /dev/null crashing_function.bc 2>&1 |
    grep -E "Assertion|Running pass|on function" | head -3
echo
echo "== same module at -O0 (pass not in the pipeline) =="
$B/llc -O0 -mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a -filetype=obj -o /dev/null crashing_function.bc 2>&1 |
    grep -E "Assertion" | head -1 || echo "  no crash at -O0"
