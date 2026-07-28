; CCE 21 / LLVM 21 AMDGPU: flat->private addrspacecast of a private object at
; frame offset 0 lowers to the private-null sentinel 0xFFFFFFFF, so the store
; lands scratch_base + 4 GiB.  LLVM 19 folds the round trip away instead.
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out, i64 %idx) #0 {
entry:
  %a = alloca [10 x double], align 32, addrspace(5)
  %off = ptrtoint ptr addrspace(5) %a to i32
  %z = zext i32 %off to i64
  %flat = inttoptr i64 %z to ptr
  %g = getelementptr double, ptr %flat, i64 %idx
  %p5 = addrspacecast ptr %g to ptr addrspace(5)
  store double 1.000000e+00, ptr addrspace(5) %p5, align 8
  %l = load volatile double, ptr addrspace(5) %a, align 8
  store double %l, ptr addrspace(1) %out, align 8
  ret void
}
attributes #0 = { "amdgpu-flat-work-group-size"="1,256" }
