#!/bin/bash
# Version triage: which LLVM releases mis-promote a negative byte-offset GEP?
set -u
for t in "/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin:CCE 21.0.2" \
         "/opt/rocm-7.0.2/llvm/bin:ROCm 7.0.2" \
         "/opt/rocm-7.2.0/llvm/bin:ROCm 7.2.0" \
         "/opt/rocm-7.13.0/llvm/bin:ROCm 7.13.0"; do
  b="${t%%:*}"; n="${t##*:}"; [ -x "$b/opt" ] || continue
  v=$("$b/opt" --version 2>/dev/null | grep -oE "LLVM version [0-9.]+")
  o=$("$b/opt" -mcpu=gfx90a -passes=amdgpu-promote-alloca -S pa_min.ll 2>/dev/null)
  if grep -q "alloca \[3 x i32\]" <<<"$o"; then r="not promoted (safe)"
  elif grep -q "add i32 1073741823" <<<"$o"; then r="PROMOTED WITH WRONG INDEX (+0x3FFFFFFF)"
  elif grep -qE "add i32 %n, -1" <<<"$o"; then r="promoted correctly (-1)"
  else r="unrecognised"; fi
  printf "%-14s %-20s %s\n" "$n" "$v" "$r"
done
