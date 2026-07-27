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
cd "$(dirname "$0")"
FC=${FC:-ftn}
CALLEE=${1:-mod_callee.f90}
CALLER=${2:-mod_caller.f90}
MAIN=${3:-main.f90}

printf 'ftn: %s\n' "$($FC --version 2>&1 | head -1)"
printf 'callee=%s caller=%s main=%s\n\n' "$CALLEE" "$CALLER" "$MAIN"
printf '%-30s %s\n' "callee-ipa / caller-ipa" "result"
printf '%-30s %s\n' "------------------------------" "------"
for cfg in "-Oipa0:" ":-Oipa0" ":" "-Oipa0:-Oipa0"; do
    cal="${cfg%%:*}"; oth="${cfg##*:}"
    rm -f ./*.mod ./*.o ./repro
    $FC -em -J. $oth -c mod_state.f90   >/dev/null 2>&1
    $FC -em -J. $cal -c "$CALLEE" -o callee.o >/dev/null 2>&1
    $FC -em -J. $oth -c "$CALLER" -o caller.o >/dev/null 2>&1
    $FC -em -J. $oth -c "$MAIN" -o main.o >/dev/null 2>&1
    $FC -em -J. $oth mod_state.o callee.o caller.o main.o -o repro >/dev/null 2>&1
    printf '%-30s %s\n' "${cal:-default} / ${oth:-default}" \
        "$([ -x ./repro ] && ./repro | tail -1 | sed 's/^ *//' || echo '(build failed)')"
done
rm -f ./*.mod ./*.o ./repro
