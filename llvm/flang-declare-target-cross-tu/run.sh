#!/bin/bash
# Usage: ./run.sh <fortran-compiler> [offload-arch]
# Prepend the build's libs but KEEP the system LD_LIBRARY_PATH, otherwise the
# amdgpu plugin cannot dlopen libhsa-runtime64.so, reports zero devices, and
# runs every target region on the host -- which looks like a pass.
FC=${1:?usage: ./run.sh <flang> [arch]}
ARCH=${2:-gfx90a}
set -e
rm -f -- *.mod *.o repro control
$FC -fopenmp --offload-arch=$ARCH -O2 -c mod_a.f90 -o mod_a.o
$FC -fopenmp --offload-arch=$ARCH -O2 -c mod_b.f90 -o mod_b.o
$FC -fopenmp --offload-arch=$ARCH -O2 -c main.f90  -o main.o
$FC -fopenmp --offload-arch=$ARCH -O2 mod_a.o mod_b.o main.o -o repro
rm -f -- *.mod
$FC -fopenmp --offload-arch=$ARCH -O2 control_same_tu.f90 -o control
set +e
echo "--- cross-TU (mod_a / mod_b / main) ---"; ./repro;  echo "  exit=$?"
echo "--- control, same TU ---";                ./control; echo "  exit=$?"
