#!/bin/bash
# Reproduce: CCE 21.0.2 accepts !DIR$ INLINENEVER on a device routine, then emits it
# with alwaysinline and inlines it anyway. No diagnostic.
set -u
BIN=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
ftn --version | head -1

echo "=== 1. compile: the directive is accepted, no diagnostic ==="
rm -f inlinenever device.elf M_KERNEL.mod
ftn -hacc -o inlinenever inlinenever.f90
echo "rc=$?  (0 = accepted; ftn-790 would mean 'unknown directive')"

echo "=== 2. extract the AMDGPU device image from the host binary ==="
python3 extract-device-image.py inlinenever device.elf

echo "=== 3. is s_leaf a callable device function? ==="
n=$("$BIN"/llvm-nm device.elf 2>/dev/null | grep -c "s_leaf")
echo "device symbols matching s_leaf: $n   (expected >=1 if INLINENEVER were honoured)"

echo "=== 4. are there any calls at all in the device image? ==="
c=$("$BIN"/llvm-objdump -d device.elf 2>/dev/null | grep -cE "s_swappc|s_setpc")
echo "call instructions: $c   (0 = everything was inlined)"

echo "=== 5. the leaf body is present, inlined into the kernel ==="
v=$("$BIN"/llvm-objdump -d device.elf 2>/dev/null | grep -cE "v_(mul|div|rcp|fma|add)")
echo "v_ arithmetic ops in kernel: $v"

echo
echo "=== device symbols (only the kernel should appear) ==="
"$BIN"/llvm-nm device.elf 2>/dev/null | grep " T \| R " | head
