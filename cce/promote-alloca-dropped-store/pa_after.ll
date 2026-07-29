; ModuleID = 'promote_alloca.ll'
source_filename = "promote_alloca.ll"
target datalayout = "e-p:64:64-p1:64:64-p5:32:32-i64:64-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out, i32 %nd, i32 %val) #0 {
entry:
  %idx = freeze <3 x i32> poison
  %0 = insertelement <3 x i32> %idx, i32 0, i32 0
  %1 = insertelement <3 x i32> %0, i32 0, i32 1
  %2 = insertelement <3 x i32> %1, i32 0, i32 2
  %off = add nsw i32 %nd, -1
  %3 = insertelement <3 x i32> %2, i32 %val, i32 %off
  %4 = extractelement <3 x i32> %3, i32 0
  store i32 %4, ptr addrspace(1) %out, align 4
  ret void
}

attributes #0 = { "target-cpu"="gfx90a" }
