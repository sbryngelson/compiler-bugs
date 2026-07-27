#!/bin/bash
# llc's MIR printer emits a basic-block label the MIR parser cannot read, when the
# IR block name contains a comma (as Fortran front ends can produce).
B=/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin
IN=${1:?usage: run.sh <module.bc>}
$B/llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a -stop-before=amdgpu-rewrite-agpr-copy-mfma -o /tmp/rt.mir "$IN"
$B/llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx90a -x mir -start-before=amdgpu-rewrite-agpr-copy-mfma \
       -filetype=obj -o /dev/null /tmp/rt.mir 2>&1 | head -2
