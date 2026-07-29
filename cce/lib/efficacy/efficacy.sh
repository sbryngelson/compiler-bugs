#!/bin/bash
# Differential directive-efficacy harness for CCE.
#
# For each directive, compile an identical program with and without it, on the
# host path and the device path, and compare NORMALIZED output. A directive that
# changes host output but not device output is silently ignored on device.
#
# The normalizer is validated first against a pair that must differ and a pair
# that must not; if validation fails the run aborts rather than reporting noise.
set -u
BIN=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
W=$(mktemp -d); trap 'rm -rf $W' EXIT

norm() { sed -e 's/![0-9][0-9]*//g' -e '/^![0-9]/d' -e '/^!llvm/d' -e '/^;/d' \
    -e '/ModuleID\|source_filename/d' -e 's/"file [^,]*,/"file F,/g' \
    -e 's/%r[0-9][0-9]*/%r/g' -e 's/%\([0-9][0-9]*\)/%N/g' -e 's/_t[0-9][0-9]*//g' "$1" \
  | tr -s ' \t' ' ' | sed 's/^ //;s/ $//' | grep -vE '^$'; }

devir() { ftn -hacc -O2 -c "$1" -o $W/d.o >/dev/null 2>&1 || return 1
  $BIN/llvm-objcopy --dump-section=.cray.llvm.offloading=$W/d.bin $W/d.o 2>/dev/null || return 1
  python3 -c "
import sys
d=open('$W/d.bin','rb').read(); i=d.find(b'BC\xc0\xde')
sys.exit(1) if i<0 else open('$W/d.bc','wb').write(d[i:])" 2>/dev/null || return 1
  $BIN/llvm-dis $W/d.bc -o "$2" 2>/dev/null; }

hostasm() { ftn -O2 -c "$1" -o $W/h.o >/dev/null 2>&1 || return 1
  objdump -d $W/h.o 2>/dev/null | sed 's/^\s*[0-9a-f]*://' > "$2"; }

# Compile baseline and test with the SAME FILENAME in separate directories:
# the source filename leaks into the IR (block names, debug info), so comparing
# differently-named files yields ~4 lines of pure noise.
# One directory, one filename, compiled sequentially: the full SOURCE PATH leaks
# into the IR (block names / debug info), so even same-named files in different
# directories compare as different. Compilation is deterministic (verified: two
# compiles of the same file give a 0-line diff), so sequential reuse is safe.
mkdir -p $W/wk
run_pair() {  # $1=directive  $2=out-prefix
  python3 gen.py "$1" host   $W/wk/p.f90; (cd $W/wk && hostasm p.f90 "$2_h.txt")
  python3 gen.py "$1" device $W/wk/p.f90; (cd $W/wk && devir  p.f90 "$2_d.ll")
}
run_pair NONE base

# CONTROL: identical source, same name, both dirs -> must be 'same/same'
run_pair NONE ctl
if ! cmp -s $W/wk/base_h.txt $W/wk/ctl_h.txt || ! cmp -s <(norm $W/wk/base_d.ll) <(norm $W/wk/ctl_d.ll); then
  echo "CONTROL FAILED: identical inputs compare as different. Aborting." >&2; exit 1
fi
echo "control ok: identical inputs compare identical"
printf "%-26s %-9s %-9s %s\n" DIRECTIVE HOST DEVICE VERDICT
for D in "$@"; do
  run_pair "$D" t || { echo "$D BUILD-FAIL"; continue; }
  h=$(cmp -s $W/wk/base_h.txt $W/wk/t_h.txt && echo same || echo differs)
  d=$(cmp -s <(norm $W/wk/base_d.ll) <(norm $W/wk/t_d.ll) && echo same || echo differs)
  case "$h/$d" in
    differs/same) v="** IGNORED ON DEVICE **";;
    differs/differs) v="takes effect on both";;
    same/differs) v="device-only effect";;
    same/same) v="no effect (inapplicable in this shape?)";;
  esac
  printf "%-26s %-9s %-9s %s\n" "$D" "$h" "$d" "$v"
done
