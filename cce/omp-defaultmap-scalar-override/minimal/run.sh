#!/bin/bash
# Minimal reproducer: defaultmap privatises a scalar the program explicitly map()s.
#
# `count` is map(tofrom:) -- shared -- and each !$omp atomic capture must hand out a
# distinct value. Under defaultmap CCE 21 gives every thread a private copy, so all
# 4096 threads capture the same number. Scored on the duplicate count, plus the IR
# evidence: the atomicrmw target address space.
#
#   source <MFC>/mfc.sh load -c f -m g     # CCE 21.0.2
#   ./run.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../../lib/guard.sh
WANT=${1:-21.0.2}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"; guard_accel
BIN=/opt/cray/pe/cce/$WANT/cce-clang/x86_64/bin
export OMP_TARGET_OFFLOAD=MANDATORY

run() { ftn -homp -O3 -eZ "$@" priv_atomic.f90 -o _b >/dev/null 2>&1 || { echo BUILD_FAIL; return; }
        ./_b 2>&1 | grep -oE 'duplicates = [0-9]+' | grep -oE '[0-9]+'; }
# address space of the atomic: 1 = global (correct), 5 = thread-private (the defect)
asp() { ftn -homp -O3 -eZ "$@" -c priv_atomic.f90 -o _o.o >/dev/null 2>&1 || { echo '?'; return; }
        "$BIN/llvm-objcopy" --dump-section=.cray.llvm.offloading=_off.bin _o.o 2>/dev/null
        python3 -c "
d=open('_off.bin','rb').read(); i=d.find(b'BC\xc0\xde')
open('_d.bc','wb').write(d[i:]) if i>=0 else None" 2>/dev/null
        "$BIN/llvm-dis" _d.bc -o _d.ll 2>/dev/null
        grep -m1 -oE 'atomicrmw add ptr addrspace\([0-9]+\)' _d.ll \
          | grep -oE '[0-9]+' | tail -1; }   # NB: the line ends in ')', so anchoring on $ finds nothing

echo
d_dup=$(run);           d_as=$(asp)
e_dup=$(run -DEXPLICIT); e_as=$(asp -DEXPLICIT)
printf '  %-30s duplicates=%-6s atomicrmw addrspace=%s\n' 'defaultmap'               "$d_dup" "$d_as"
printf '  %-30s duplicates=%-6s atomicrmw addrspace=%s\n' 'explicit (no defaultmap)' "$e_dup" "$e_as"
rm -f _b _o.o _off.bin _d.bc _d.ll ./*.i

echo
guard_verdict 0 "${e_dup:-?}" "control: without defaultmap every capture is unique"
guard_verdict 1 "${e_as:-?}"  "control: atomic targets global memory (addrspace 1)"
guard_verdict 4095 "${d_dup:-?}" "defaultmap: all threads capture one value"
guard_verdict 5 "${d_as:-?}"  "defaultmap: atomic retargeted to thread-private (addrspace 5)"
echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT (as documented) -- defaultmap overrode the explicit"
    echo "        map(tofrom:count) and privatised the counter. The emitted code is"
    echo "        self-evidently wrong: a syncscope(\"agent\") atomicrmw on addrspace(5),"
    echo "        thread-private memory that nothing else can ever contend for."
else
    echo "RESULT: *** deviation from the documented behaviour ***"
    echo "        Check the two controls first; if either moved, the comparison is void."
fi
exit "$GUARD_RC"
