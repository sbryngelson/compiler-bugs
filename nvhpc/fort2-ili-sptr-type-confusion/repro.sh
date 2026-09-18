#!/bin/bash
# nvfortran -O3 -mp=gpu -c repro.f90 -> fort2 TERMINATED by signal 11. See README.md.
# 20/20 on NVHPC 25.11 and 26.5. Clean on 24.5.
set -u
cd "$(dirname "$0")" || exit 1
echo "== compiler"
nvfortran --version | sed -n 2p
echo
echo "== nvfortran -O3 -mp=gpu -c repro.f90   (expect: fort2 TERMINATED by signal 11)"
nvfortran -O3 -mp=gpu -c repro.f90 -o repro.o; echo "exit status: $?"
echo
echo "== controls, all must succeed"
for f in "-O0 -mp=gpu" "-O3 -mp" "-O3"; do
    if nvfortran $f -c repro.f90 -o repro.o >/dev/null 2>&1; then
        echo "  [$f] compiles"
    else
        echo "  [$f] FAILED, unexpected"
    fi
done
rm -f repro.o m_big.mod
