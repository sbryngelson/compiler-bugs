#!/bin/bash
# Cost of the -mattr=-mai-insts workaround on gfx90a, in one file.
# gfx90a has a unified VGPR/AGPR register file: disabling MFMA/AGPR removes half
# the allocator's budget, so register-hungry kernels spill to scratch.
set -u
BIN=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
EXTRACT=${EXTRACT:-../../extract-device-image.py}
ftn --version | head -1
printf "%-10s %-10s %-10s %-12s\n" arm max_vgpr max_agpr max_scratch
for m in baseline noagpr; do
    if [ "$m" = noagpr ]; then export CRAY_CCE_LLD_ARGS="-plugin-opt=-mattr=-mai-insts"
    else unset CRAY_CCE_LLD_ARGS; fi
    ftn -hacc -o "rp_$m" regpressure.f90 > "build_$m.log" 2>&1 || { echo "$m: BUILD FAILED"; continue; }
    python3 "$EXTRACT" "rp_$m" "rp_$m.elf" >/dev/null 2>&1
    g() { $BIN/llvm-readelf --notes "rp_$m.elf" 2>/dev/null | grep -oE "$1:[[:space:]]+[0-9]+" | grep -oE "[0-9]+" | sort -rn | head -1; }
    printf "%-10s %-10s %-10s %-12s\n" "$m" "$(g vgpr_count)" "$(g agpr_count){:-none}" "$(g private_segment_fixed_size)"
done
echo
echo "Expected: baseline uses AGPRs and spills ~nothing; -mai-insts caps VGPRs at 256,"
echo "uses no AGPRs, and scratch grows by more than an order of magnitude."
