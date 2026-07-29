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

# ---------------------------------------------------------------------------
# Aggregate verdict.
#
# If INLINENEVER were honoured on the device, s_leaf would survive as a callable
# device function: a symbol in the device image AND at least one s_swappc call to
# it. The directive is silently dropped instead, so we expect neither -- while the
# leaf's arithmetic is still present, inlined into the kernel body.
# ---------------------------------------------------------------------------
echo
if [ "$v" -eq 0 ]; then
    echo "VERDICT: INCONCLUSIVE -- no arithmetic found in the device image at all."
    echo "         The kernel did not build or was not extracted; this is not a"
    echo "         statement about INLINENEVER. Check steps 1-2 above."
    exit 2
elif [ "$n" -eq 0 ] && [ "$c" -eq 0 ]; then
    echo "VERDICT: BUG PRESENT (as documented) -- INLINENEVER silently ignored on the device."
    echo "         s_leaf is not a device symbol (0) and the image contains no calls (0),"
    echo "         yet $v arithmetic ops are present: the body was inlined into the kernel."
    echo "         ftn accepted the directive in step 1 without a diagnostic."
    exit 0
elif [ "$n" -ge 1 ] && [ "$c" -ge 1 ]; then
    echo "VERDICT: FIXED -- s_leaf survives as a callable device function"
    echo "         ($n symbol(s), $c call site(s)); INLINENEVER is honoured."
    echo "         This DEVIATES from the documented behaviour; confirm it is a real fix."
    exit 1
else
    echo "VERDICT: PARTIAL -- s_leaf symbols=$n, call instructions=$c."
    echo "         A symbol with no calls (or calls with no symbol) means the directive"
    echo "         is half-honoured; report both numbers rather than a yes/no."
    exit 2
fi
