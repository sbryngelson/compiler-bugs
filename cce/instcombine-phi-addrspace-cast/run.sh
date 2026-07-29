#!/bin/bash
# Reproduce: CCE 21.0.2 lld/opt assert in InstCombine foldIntegerTypedPHI.
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh
ulimit -c 0            # opt aborts; do not litter the tree with cores
OPT=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/opt
"$OPT" --version | grep -i "LLVM"

echo "=== 1. the bug: one pass, one function ==="
"$OPT" -passes=instcombine phi-addrspace.ll -o /dev/null 2>/tmp/ic1.$$; rc1=$?
echo "rc=$rc1  (134 = assert)"

echo "=== 2. the partial workaround does NOT help this minimal case ==="
# -instcombine-max-num-phis clears the crash on the large application kernel this
# was reduced from, but not here: one PHI is enough to reach the invalid cast.
"$OPT" -passes=instcombine -instcombine-max-num-phis=0 phi-addrspace.ll -o /dev/null 2>/tmp/ic2.$$; rc2=$?
echo "rc=$rc2  (134 = still asserts -- the flag is not a fix for the defect)"

echo "=== 3. other LLVM versions, for triage ==="
for v in 6.3.1 7.2.0; do
    T=/opt/rocm-$v/llvm/bin/opt
    [ -x "$T" ] || continue
    ver=$("$T" --version | grep -oE "LLVM version [0-9.]+" | head -1)
    "$T" -passes=instcombine phi-addrspace.ll -o /dev/null 2>/dev/null
    echo "rocm-$v ($ver) rc=$?"
done

echo
echo "=== verdict ==="
# The defect is CCE's opt asserting in foldIntegerTypedPHI. Both arms must abort:
# if -instcombine-max-num-phis=0 silenced it, the flag would be a usable workaround
# and this entry would need rewriting.
guard_verdict 134 "$rc1" "CCE 21.0.2 opt asserts on -passes=instcombine"
guard_verdict 134 "$rc2" "still asserts with -instcombine-max-num-phis=0"
echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT -- asserts as documented, and the phi-count flag does not avoid it."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        rc=0 would mean fixed; any other rc means it changed shape."
    echo "        Check the assertion text before recording this as a fix:"
    grep -hm1 -E "Assertion|UNREACHABLE" /tmp/ic1.$$ /tmp/ic2.$$ 2>/dev/null | sed "s/^/          /"
fi
rm -f /tmp/ic1.$$ /tmp/ic2.$$
exit "$GUARD_RC"
