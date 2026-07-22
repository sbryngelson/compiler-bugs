#!/bin/bash
# Demonstrate the defect without a full LLVM build: the intrinsic-module probe
# used by runtimes/cmake/config-Fortran.cmake ignores the target triple, so it
# tests the host and "succeeds" even for a GPU triple that has no such module.
#
# Flang's intrinsic modules are per-target (built by flang-rt for each target).
set -e

FC=${FC:-$(which amdflang 2>/dev/null || which flang)}
echo "flang: $FC"; "$FC" --version 2>&1 | head -1
echo

echo "=== host query (what the CMake probe actually runs -- no --target) ==="
"$FC" -print-file-name=iso_c_binding.mod
echo "  ^ resolves to a real host .../finclude/flang/<host-triple>/iso_c_binding.mod"
echo

echo "=== same query with the GPU triple the runtime is being configured for ==="
"$FC" --target=amdgcn-amd-amdhsa -print-file-name=iso_c_binding.mod
echo "  ^ returns the bare name: the module does not exist for this triple"
echo

echo "CMake's probe takes the first (host) answer, sets RUNTIMES_FORTRAN_MODULES=ON"
echo "for the GPU target, and the failure only surfaces ~180 diagnostics later when"
echo "omp_lib.F90 is compiled for the GPU triple and cannot find iso_c_binding.mod."
