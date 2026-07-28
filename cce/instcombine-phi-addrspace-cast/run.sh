#!/bin/bash
# Reproduce: CCE 21.0.2 lld/opt assert in InstCombine foldIntegerTypedPHI.
set -u
OPT=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/opt
"$OPT" --version | grep -i "LLVM"

echo "=== 1. the bug: one pass, one function ==="
"$OPT" -passes=instcombine phi-addrspace.ll -o /dev/null
echo "rc=$?  (134 = assert)"

echo "=== 2. the partial workaround does NOT help this minimal case ==="
# -instcombine-max-num-phis clears the crash on the large application kernel this
# was reduced from, but not here: one PHI is enough to reach the invalid cast.
"$OPT" -passes=instcombine -instcombine-max-num-phis=0 phi-addrspace.ll -o /dev/null
echo "rc=$?  (134 = still asserts -- the flag is not a fix for the defect)"

echo "=== 3. other LLVM versions, for triage ==="
for v in 6.3.1 7.2.0; do
    T=/opt/rocm-$v/llvm/bin/opt
    [ -x "$T" ] || continue
    ver=$("$T" --version | grep -oE "LLVM version [0-9.]+" | head -1)
    "$T" -passes=instcombine phi-addrspace.ll -o /dev/null 2>/dev/null
    echo "rocm-$v ($ver) rc=$?"
done
