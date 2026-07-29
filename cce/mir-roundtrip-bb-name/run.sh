#!/bin/bash
# MIR printer emits an unquoted basic-block name; if the name contains a comma
# the MIR parser then rejects llc's own output.
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh
n_tested=0; n_bad=0
for t in "/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin:CCE21.0.2" "/opt/rocm-7.2.0/llvm/bin:LLVM22" "/opt/rocm-7.0.2/llvm/bin:LLVM20"; do
  b="${t%%:*}"; n="${t##*:}"; [ -x "$b/llc" ] || continue
  "$b/llc" -mcpu=gfx90a -stop-before=greedy bb-comma-name.ll -o /tmp/m_$n.mir 2>/dev/null
  bad=$(grep -m1 -oE "^  bb\.[0-9]+\..*," /tmp/m_$n.mir)
  "$b/llc" -mcpu=gfx90a -x mir -start-before=greedy /tmp/m_$n.mir -o /dev/null 2>/tmp/e_$n.log
  rc=$?
  printf "%-11s emitted: %-18s re-parse rc=%s  %s\n" "$n" "${bad:-<none>}" "$rc" \
    "$(grep -m1 -oE 'error:.*' /tmp/e_$n.log | cut -c1-40)"
  n_tested=$((n_tested+1))
  # The defect: llc emitted an unquoted name containing a comma AND then failed to
  # re-parse its own output. Both halves are required -- a re-parse failure with no
  # comma in the name would be some other bug.
  [ -n "$bad" ] && [ "$rc" -ne 0 ] && n_bad=$((n_bad+1))
done

echo
echo "=== verdict ==="
if [ "$n_tested" -eq 0 ]; then
    echo "RESULT: INCONCLUSIVE -- no llc found at any of the probed paths."
    exit 2
fi
guard_verdict "$n_tested" "$n_bad" "toolchains that emit an unparseable comma name"
echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: BUG PRESENT -- all $n_tested toolchain(s) fail to re-parse their own MIR."
    echo "        This is upstream LLVM, not CCE-specific: filed as llvm/llvm-project#212785."
else
    echo "RESULT: PARTIAL/FIXED -- $n_bad of $n_tested toolchain(s) still affected."
    echo "        A toolchain that round-trips cleanly has the fix; note its version"
    echo "        in README.md rather than deleting this reproducer."
fi
exit "$GUARD_RC"
