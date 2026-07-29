#!/bin/bash
# Extract the device LLVM IR that CCE hands to the AMDGPU pass pipeline.
# CCE stores it in a .cray.llvm.offloading section, wrapped in an LLVM
# OffloadBinary (magic 0x10FF10AD). save-temps does NOT work for a direct
# `ftn -o exe file.f90`, which is why this exists.
set -eu
src=${1:?usage: extract-device-ir.sh file.f90 [out.ll]}
out=${2:-dev.ll}
BIN=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
ftn -hacc -c "$src" -o _dev.o
$BIN/llvm-objcopy --dump-section=.cray.llvm.offloading=_off.bin _dev.o
python3 -c "
import sys
d=open('_off.bin','rb').read()
i=d.find(b'BC\xc0\xde')
assert i>=0, 'no bitcode found in offload section'
open('_dev.bc','wb').write(d[i:])
print('bitcode at offset', i)
"
$BIN/llvm-dis _dev.bc -o "$out"
rm -f _dev.o _off.bin _dev.bc
echo "wrote $out"
