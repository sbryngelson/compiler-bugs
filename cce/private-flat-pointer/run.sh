#!/bin/bash
# Reproduce: ftn builds a flat pointer from a private frame offset without the
# aperture, so an object at frame offset 0 casts to 0xFFFFFFFF and stores 4 GiB
# out of bounds.
#
# No GPU, no ROCm runtime, no MFC -- only CCE's own llc.  Both CCE 19.0.0 and
# 21.0.2 are expected to miscompile this; they differ only in which instruction
# expresses the poisoned select, which is why both forms are checked.
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

ulimit -c 0                      # llc may abort; do not litter the tree with cores
OUT=$(mktemp -d) || exit 1
trap 'rm -rf "$OUT"' EXIT

echo "== environment"
for v in 21.0.2 19.0.0; do guard_llc "$v"; done
echo
echo "== compiling"
for v in 21.0.2 19.0.0; do
    guard_llc "$v" >/dev/null
    for f in repro-p5-null-fold repro-p5-null-dyn; do
        "$GUARD_BIN/llc" -O2 -mcpu=gfx90a "$f.ll" -o "$OUT/${f}_$v.s" 2>"$OUT/err" || {
            echo "  llc failed for $f on $v:"; cat "$OUT/err"; exit 1; }
    done
done
echo "  ok"
echo
echo "== the defect: a private-segment store with voffset = 0xFFFFFFFF"
echo "   (CCE 21 folds it in the SALU as 's_cselect_b32 sN, 0, -1';"
echo "    CCE 19 leaves it in the VALU as 'v_cndmask_b32 vN, -1, ...'."
echo "    Grepping only the SALU form undercounts CCE 19's exposure.)"
echo

for v in 21.0.2 19.0.0; do
    f="$OUT/repro-p5-null-fold_$v.s"
    poison=no
    grep -qE 's_cselect_b32 s[0-9]+, 0, -1|v_cndmask_b32_e32 v[0-9]+, -1,' "$f" && poison=yes
    grep -q 'buffer_store_dword .* offen' "$f" || poison=no
    guard_verdict yes "$poison" "CCE $v  constant-index case emits the wild store"
    grep -nE 's_cselect_b32 s[0-9]+, 0, -1|v_cndmask_b32_e32 v[0-9]+, -1,|buffer_store_dword .* offen' \
        "$f" | sed 's/^/        /'
    echo
done

echo "== reference disassembly committed alongside (for diffing):"
ls repro-p5-null-*_*.s | sed 's/^/     /'

echo
if [ "$GUARD_RC" -eq 0 ]; then
    echo "RESULT: both compilers miscompile the pattern, as documented."
else
    echo "RESULT: *** at least one compiler no longer matches the documented output ***"
    echo "        Check whether this is a fix or a codegen change before assuming a fix."
fi
exit "$GUARD_RC"
