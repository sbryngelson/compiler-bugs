#!/bin/bash
# Reproduce: CCE 20.0.2's lld corrupts the heap in "Infer address spaces" during
# device LTO.  Replays standalone from the committed sim-cce20.bc -- no MFC, no
# build system, no GPU.
#
# NOTE: this must be driven through `lld`, NOT `llc`.  The same module through
# `llc -O2` completes cleanly (full codegen, 453 kernels, pass in the pipeline)
# and proves nothing -- see "llc does not reproduce it" in README.md.
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

ulimit -c 0
echo "== environment"
guard_llc 20.0.2; BIN=$GUARD_BIN
[ -x "$BIN/lld" ] || guard_fatal "CCE 20.0.2's lld is missing at $BIN/lld"
guard_note "lld present"
[ -f sim-cce20.bc ] || guard_fatal "sim-cce20.bc is missing from this directory."
# apparent-size: on Lustre plain `du` reports allocated blocks and badly understates it
guard_note "sim-cce20.bc $(du --apparent-size -h sim-cce20.bc | cut -f1)"

echo
echo "== replaying the device link (expect abort in 'Infer address spaces')"
log=$(mktemp); trap 'rm -f "$log" /tmp/out20.amdgpu' EXIT
"$BIN/lld" -flavor gnu --no-undefined -shared \
    -plugin-opt=mcpu=gfx90a -plugin-opt=-disable-promote-alloca-to-lds \
    -plugin-opt=defaults=cray -plugin-opt=O2 \
    -o /tmp/out20.amdgpu sim-cce20.bc >"$log" 2>&1
rc=$?

grep -E "Running pass|malloc_consolidate|Infer address" "$log" | sed 's/^/     /'
echo

crashed=no
[ "$rc" -ne 0 ] && grep -q 'malloc_consolidate' "$log" && crashed=yes
guard_verdict yes "$crashed" "lld aborts with heap corruption (rc=$rc)"
guard_verdict yes "$(grep -q "Infer address spaces" "$log" && echo yes || echo no)" \
    "the abort names the 'Infer address spaces' pass"

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: reproduced, as documented."
else
    echo "RESULT: *** did not reproduce ***"
    echo "        Before concluding this is fixed, confirm you drove lld and not llc,"
    echo "        and that ftn/lld really are 20.0.2 (see README)."
fi
exit "$GUARD_RC"
