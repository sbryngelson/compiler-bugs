#!/bin/bash
# Sweep every CCE on the system, baseline vs fix, at default IPA.
#
# Each CCE needs its matching cpe and a compatible rocm, and the rocm lib dir must be on
# LD_LIBRARY_PATH or the binary won't start (libamdhip64.so.6). That is why a bare
# `module swap cce` appears to work but leaves ftn dispatching the old version.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
W=$(mktemp -d); cp "$D"/*.f90 "$W/"
probe () { # $1=cpe  $2=cce-swap (may be empty)  $3=rocm
  ( module reset >/dev/null 2>&1
    module load cpe/$1 >/dev/null 2>&1
    module load rocm/$3 >/dev/null 2>&1
    module load craype-accel-amd-gfx90a >/dev/null 2>&1
    [ -n "$2" ] && module swap cce cce/$2 >/dev/null 2>&1
    export LD_LIBRARY_PATH="${ROCM_PATH:-/opt/rocm-$3}/lib:${CRAY_LD_LIBRARY_PATH:-}:${LD_LIBRARY_PATH:-}"
    v=$(ftn --version 2>&1 | grep -oP 'Version \K[0-9.]+')
    cd "$W" || exit 1
    out=""
    for pair in "baseline:mod_callee.f90:mod_caller.f90" "v1fix:v1_callee.f90:v1_caller.f90"; do
      lbl="${pair%%:*}"; rest="${pair#*:}"; cal="${rest%%:*}"; car="${rest##*:}"
      rm -f ./*.mod ./*.o ./repro
      ftn -em -J. -c mod_state.f90 >/dev/null 2>&1
      ftn -em -J. -c "$cal" -o callee.o >/dev/null 2>&1
      ftn -em -J. -c "$car" -o caller.o >/dev/null 2>&1
      ftn -em -J. -c main.f90 >/dev/null 2>&1
      ftn -em -J. mod_state.o callee.o caller.o main.o -o repro >/dev/null 2>&1
      res=$(./repro 2>&1 | tail -1 | sed 's/^ *RESULT: //')
      out="$out  $lbl=[${res:-NO OUTPUT}]"
    done
    printf 'cce/%-8s rocm/%-6s %s\n' "${v:-?}" "$3" "$out" ) 2>/dev/null
}
{ probe 25.03 18.0.1 6.3.1; probe 25.03 "" 6.3.1; probe 25.09 "" 6.4.2
  probe 25.09 20.0.2 6.4.2; probe 26.03 "" 7.2.0; probe 26.03 21.0.2 7.2.0; } | grep '^cce/'
rm -rf "$W"
