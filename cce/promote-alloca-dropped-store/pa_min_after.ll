; ModuleID = 'pa_min.ll'
source_filename = "pa_min.ll"
target datalayout = "e-p:64:64-p1:64:64-p5:32:32-i64:64-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out, i32 %n, i32 %val) #0 {
entry:
  %a = freeze <3 x i32> poison
  %0 = insertelement <3 x i32> %a, i32 0, i32 0
  %1 = add i32 1073741823, %n
  %2 = insertelement <3 x i32> %0, i32 %val, i32 %1
  %3 = extractelement <3 x i32> %2, i32 0
  store i32 %3, ptr addrspace(1) %out, align 4
  ret void
}

attributes #0 = { "target-cpu"="gfx90a" }
