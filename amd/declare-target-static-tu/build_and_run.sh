#!/bin/bash
# Compile the two TUs SEPARATELY (the bug needs the update and the kernel-read in different
# objects) and link with LTO, using the same flags MFC uses on Frontier. Needs an MI250X (gfx90a).
set -e
cd "$(dirname "$0")"
module load cpe/25.09 PrgEnv-amd amd/7.2.0 rocm/7.2.0 2>/dev/null || true
FC=$(which amdflang 2>/dev/null || which flang)
echo "compiler: $FC"; $FC --version 2>&1 | head -1
CFLAGS="-fopenmp --offload-arch=gfx90a -O3 -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription"
export OMP_TARGET_OFFLOAD=MANDATORY
rm -f *.o *.mod repro
$FC $CFLAGS -c repro_mod.f90  -o repro_mod.o    # TU1: declares arrays + kernel
$FC $CFLAGS -c repro_main.f90 -o repro_main.o   # TU2: host update + driver
$FC -fopenmp --offload-arch=gfx90a -flto-partitions=16 repro_mod.o repro_main.o -o repro
echo "--- run ---"
./repro
