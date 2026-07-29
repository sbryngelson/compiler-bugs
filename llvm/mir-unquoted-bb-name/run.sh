#!/bin/bash
# llc emits MIR it cannot re-parse when a block name contains a comma.
set -u
for t in "/opt/rocm-7.2.0/llvm/bin:LLVM22" "/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin:CCE21.0.2"; do
  b="${t%%:*}"; n="${t##*:}"; [ -x "$b/llc" ] || continue
  "$b/llc" -mcpu=gfx90a -stop-before=greedy bb-comma-name.ll -o /tmp/o_$n.mir 2>/dev/null
  lbl=$(grep -m1 -oE "^  bb\.[0-9]+\..*:" /tmp/o_$n.mir)
  "$b/llc" -mcpu=gfx90a -x mir -start-before=greedy /tmp/o_$n.mir -o /dev/null 2>/tmp/e_$n.log
  printf "%-11s emitted %-18s re-parse rc=%s  %s\n" "$n" "${lbl:-<none>}" "$?" \
    "$(grep -m1 -oE 'error:.*' /tmp/e_$n.log | cut -c1-32)"
done
