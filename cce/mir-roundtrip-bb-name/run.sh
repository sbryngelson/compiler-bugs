#!/bin/bash
# MIR printer emits an unquoted basic-block name; if the name contains a comma
# the MIR parser then rejects llc's own output.
set -u
for t in "/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin:CCE21.0.2" "/opt/rocm-7.2.0/llvm/bin:LLVM22" "/opt/rocm-7.0.2/llvm/bin:LLVM20"; do
  b="${t%%:*}"; n="${t##*:}"; [ -x "$b/llc" ] || continue
  "$b/llc" -mcpu=gfx90a -stop-before=greedy bb-comma-name.ll -o /tmp/m_$n.mir 2>/dev/null
  bad=$(grep -m1 -oE "^  bb\.[0-9]+\..*," /tmp/m_$n.mir)
  "$b/llc" -mcpu=gfx90a -x mir -start-before=greedy /tmp/m_$n.mir -o /dev/null 2>/tmp/e_$n.log
  printf "%-11s emitted: %-18s re-parse rc=%s  %s\n" "$n" "${bad:-<none>}" "$?" \
    "$(grep -m1 -oE 'error:.*' /tmp/e_$n.log | cut -c1-40)"
done
