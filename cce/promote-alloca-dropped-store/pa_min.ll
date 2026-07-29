; AMDGPUPromoteAllocaToVector: a NEGATIVE byte-offset GEP chained onto a
; typed GEP is converted to a vector index using UNSIGNED division of the
; byte offset by the element size.
;   want:  idx = %n + (-4 / 4)          = %n - 1
;   got:   idx = %n + (0xFFFFFFFC / 4)  = %n + 0x3FFFFFFF   -> out of range -> poison
target datalayout = "e-p:64:64-p1:64:64-p5:32:32-i64:64-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out, i32 %n, i32 %val) {
entry:
  %a = alloca [3 x i32], align 4, addrspace(5)
  store i32 0, ptr addrspace(5) %a, align 4
  %p = getelementptr i32, ptr addrspace(5) %a, i32 %n
  %q = getelementptr i8,  ptr addrspace(5) %p, i32 -4
  store i32 %val, ptr addrspace(5) %q, align 4
  %r = load i32, ptr addrspace(5) %a, align 4
  store i32 %r, ptr addrspace(1) %out, align 4
  ret void
}
