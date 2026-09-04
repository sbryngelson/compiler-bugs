#!/bin/bash
# Build the three files separately (so the device routine is a real call, not an inlined one)
# with the flags MFC uses, then run. The login node has a GPU; on a compute node prefix the
# run with: srun -n1 --gpus-per-task 1
#
#   module reset
#   module load cpe/25.03 rocm/6.3.1 craype-accel-amd-gfx90a
#   module swap cce cce/19.0.0
#   ./build_and_run.sh
set -u
cd "$(dirname "$0")" || exit 1
. ../lib/guard.sh

WANT=${1:-19.0.0}
echo "== environment (want CCE $WANT)"
guard_ftn "$WANT"
guard_accel

F="-hacc -h acc_model=auto_async_none -h acc_model=no_fast_addr -O2"
out=build-$WANT
mkdir -p "$out"
echo "== building in $out (three separate compilations)"
( cd "$out" && ftn $F -c ../m_eos.f90 && ftn $F -c ../m_rhs.f90 && ftn $F ../main.f90 m_eos.o m_rhs.o -o repro ) >"$out/build.log" 2>&1 \
    || { echo "build failed:"; cat "$out/build.log"; exit 1; }
grep -q 'ftn-1350' "$out/build.log" && guard_fatal "ftn ignored -hacc -- this would be a host build."
guard_device_image "$out/repro"

export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"
if [ "${NO_RUN:-0}" = 1 ]; then echo "== NO_RUN set: ./$out/repro"; exit 0; fi
echo "== running"
./"$out"/repro | tee "$out/run.txt"
echo
echo "== reading it: 'sanity store' and 'scalar' must be 0 bad (mapping and control);"
echo "   any nonzero 'element' line is the defect: the by-reference array element is misaddressed."
