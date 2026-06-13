#!/bin/bash
# Compile all bug reproducers for Intel GPU (PVC)
# Run on a system with ifx loaded (e.g. module load iimpi/2025a)

IFX_FLAGS=(-fiopenmp -fopenmp-targets=spir64_gen -Xopenmp-target-backend "-device pvc" -O2)

for src in bug*.f90; do
    exe="${src%.f90}"
    echo -n "Compiling $src ... "
    if ifx "${IFX_FLAGS[@]}" -o "$exe" "$src" 2>/dev/null; then
        echo "OK"
    else
        echo "FAILED"
        ifx "${IFX_FLAGS[@]}" -o "$exe" "$src"
    fi
done
