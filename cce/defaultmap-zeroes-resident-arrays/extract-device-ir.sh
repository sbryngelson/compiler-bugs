#!/bin/bash
# Extract the device LLVM IR CCE hands to the AMDGPU pipeline.
# Stored in a .cray.llvm.offloading ELF section, wrapped in an LLVM
# OffloadBinary (magic 0x10FF10AD). save-temps does not work for a direct ftn call.
set -eu
src=${1:?usage: extract-device-ir.sh file.f90 [out.ll] [ftn-flags...]}
out=${2:-dev.ll}; shift 2 || shift 1 || true
BIN=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
ftn "${@:--homp}" -c "$src" -o _dev.o
$BIN/llvm-objcopy --dump-section=.cray.llvm.offloading=_off.bin _dev.o
python3 -c "
d=open('_off.bin','rb').read(); i=d.find(b'BC\xc0\xde')
assert i>=0, 'no bitcode in offload section'
open('_dev.bc','wb').write(d[i:]); print('bitcode at offset', i)"
$BIN/llvm-dis _dev.bc -o "$out"; rm -f _dev.o _off.bin _dev.bc; echo "wrote $out"
