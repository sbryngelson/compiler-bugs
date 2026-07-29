# Minimal reproducer: ROCm 7.2.0 hipfort ships hipfft Fortran bindings and
# advertises a hipfft component, but omits hipfort-hipfft-targets.cmake, which
# hipfort-config.cmake includes unconditionally -> hard configure error.
#
#   cmake -S . -B build                        # fails  (hipfft)
#   cmake -S . -B build -DCOMP=hipblas         # succeeds (control)
cmake_minimum_required(VERSION 3.20)
project(hipfort_hipfft_repro LANGUAGES C)
set(COMP "hipfft" CACHE STRING "hipfort component to request")
list(APPEND CMAKE_PREFIX_PATH "$ENV{ROCM_PATH}" "/opt/rocm-7.2.0")
find_package(hipfort REQUIRED COMPONENTS ${COMP})
message(STATUS "FOUND hipfort with component '${COMP}'")
