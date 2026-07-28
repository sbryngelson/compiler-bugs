#!/bin/bash
# Standalone reproducer: no MFC, no build system, no lld, no GPU, no MPI.
# Needs CCE 21.x's own LLVM (assertions enabled).
#
# Two modules at different reduction depths are checked:
#   crashing_function.bc   495 KB  llvm-extract of the single crashing function
#   reduced-667-line.ll     50 KB  the same crash after llvm-reduce, readable IR
set -u
cd "$(dirname "$0")" || exit 1
. ../../lib/guard.sh

ulimit -c 0                      # llc aborts here by design; do not drop core files

WANT=${1:-21.0.2}
echo "== environment (want CCE $WANT)"
guard_llc "$WANT"; B=$GUARD_BIN

run_llc() {  # $1=module, $2=extra flags -> "assert" | "clean" | "error"
    local log rc; log=$(mktemp)
    # shellcheck disable=SC2086
    "$B/llc" $2 -mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a -filetype=obj \
        -o /dev/null "$1" >"$log" 2>&1
    rc=$?
    if grep -q 'Attempt to compare reserved index' "$log"; then echo assert
    elif [ $rc -ne 0 ]; then echo error
    else echo clean; fi
    rm -f "$log"
}

for m in crashing_function.bc reduced-667-line.ll; do
    [ -f "$m" ] || { echo; echo "  (skipping absent $m)"; continue; }
    echo
    echo "== $m at -O2 (expect the assertion)"
    "$B/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a -filetype=obj -o /dev/null "$m" 2>&1 |
        grep -E "Assertion|Running pass|on function" | head -3 | sed 's/^/     /'
    guard_verdict assert "$(run_llc "$m" '')" "$m at -O2"

    echo "== $m at -O0 (pass not in the pipeline; expect clean)"
    guard_verdict clean "$(run_llc "$m" '-O0')" "$m at -O0"
done

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: reproduced on CCE $WANT, as documented."
    echo "        CCE 19.0.0 and 20.0.2 do not ship this pass and compile it clean;"
    echo "        './run.sh 20.0.2' will therefore report MISMATCH by design."
else
    echo "RESULT: *** did not match the documented behaviour on CCE $WANT ***"
fi
exit "$GUARD_RC"
