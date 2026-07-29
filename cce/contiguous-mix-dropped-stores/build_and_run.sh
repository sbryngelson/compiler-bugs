#!/bin/bash
# Build the reproducer under four interprocedural-analysis configurations and report.
#
# Login node is fine -- the code is host-only and never launches a kernel. But the
# accelerator target module MUST be loaded: with craype-accel-amd-gfx90a unloaded the
# bug does not appear, even on CCE 19.0.0.
#
#   source /path/to/MFC/mfc.sh load -c f -m g     # CCE 19 + craype-accel-amd-gfx90a
#   ./build_and_run.sh                            # baseline
#   ./build_and_run.sh v1_callee.f90 v1_caller.f90  # the contiguous-everywhere fix
set -u
cd "$(dirname "$0")" || exit 1
FC=${FC:-ftn}
CALLEE=${1:-mod_callee.f90}
CALLER=${2:-mod_caller.f90}
MAIN=${3:-main.f90}

# The accel target is load-bearing here even though nothing launches a kernel:
# with craype-accel-amd-gfx90a unloaded the bug does not appear even on 19.0.0,
# so an unguarded run reports "ghosts OK" and looks like a fixed compiler.
# Skipped when FC is overridden (run_versions.sh drives several CCEs itself).
if [ "$FC" = ftn ]; then
    . ../lib/guard.sh
    guard_ftn "${CCE_VERSION:-19.0.0}"
    guard_accel
    echo
fi

printf 'ftn: %s\n' "$($FC --version 2>&1 | head -1)"
printf 'callee=%s caller=%s main=%s\n\n' "$CALLEE" "$CALLER" "$MAIN"
printf '%-30s %s\n' "callee-ipa / caller-ipa" "result"
printf '%-30s %s\n' "------------------------------" "------"
bad=0; good=0; fail=0
for cfg in "-Oipa0:" ":-Oipa0" ":" "-Oipa0:-Oipa0"; do
    cal="${cfg%%:*}"; oth="${cfg##*:}"
    rm -f ./*.mod ./*.o ./repro
    $FC -em -J. $oth -c mod_state.f90   >/dev/null 2>&1
    $FC -em -J. $cal -c "$CALLEE" -o callee.o >/dev/null 2>&1
    $FC -em -J. $oth -c "$CALLER" -o caller.o >/dev/null 2>&1
    $FC -em -J. $oth -c "$MAIN" -o main.o >/dev/null 2>&1
    $FC -em -J. $oth mod_state.o callee.o caller.o main.o -o repro >/dev/null 2>&1
    if [ -x ./repro ]; then
        line=$(./repro | tail -1 | sed 's/^ *//')
        case "$line" in
            *CORRUPTED*) bad=$((bad+1));;
            *OK*)        good=$((good+1));;
            *)           fail=$((fail+1));;
        esac
    else
        line='(build failed)'; fail=$((fail+1))
    fi
    printf '%-30s %s\n' "${cal:-default} / ${oth:-default}" "$line"
done
rm -f ./*.mod ./*.o ./repro

# ---------------------------------------------------------------------------
# Aggregate verdict.
#
# The four rows differ only in WHERE -Oipa0 is applied. The ghost writes are the
# same in every one, so a correct compiler gives "ghosts OK" four times. Any
# CORRUPTED row means interprocedural analysis dropped stores through the
# contiguous/non-contiguous dummy mismatch -- the row tells you which side
# needed the analysis disabled to hide it.
# ---------------------------------------------------------------------------
echo
if [ "$fail" -gt 0 ] && [ "$((bad+good))" -eq 0 ]; then
    echo "VERDICT: INCONCLUSIVE -- $fail/4 configs did not build or run."
    echo "         Load the env first (and note craype-accel-amd-gfx90a is required"
    echo "         even though nothing launches a kernel)."
    exit 2
elif [ "$bad" -gt 0 ]; then
    echo "VERDICT: BUG PRESENT -- $bad/4 configs corrupted the ghost cells."
    echo "         Same source, same writes; only the -Oipa0 placement differs, so the"
    echo "         difference is interprocedural analysis dropping stores across the"
    echo "         contiguous / non-contiguous dummy mismatch."
    [ "$fail" -gt 0 ] && echo "         ($fail config(s) did not build -- see rows above.)"
    exit 1
else
    echo "VERDICT: FIXED -- all $good runnable configs kept the ghost cells intact."
    [ "$fail" -gt 0 ] && echo "         ($fail config(s) did not build -- coverage is incomplete.)"
    exit 0
fi
