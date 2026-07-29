; Control: the SAME operation expressed with addrspacecast, which is the
; documented way to convert private -> flat on AMDGPU (it adds the scratch
; aperture base). Compare against repro-p5-null-fold.ll, which instead does
; ptrtoint -> zext -> inttoptr and loses the aperture.
target datalayout = "e-p:64:64-p1:64:64-p5:32:32-i64:64-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @k(ptr addrspace(1) %out) #0 {
entry:
  %a = alloca [10 x double], align 32, addrspace(5)
  %flat = addrspacecast ptr addrspace(5) %a to ptr     ; <-- correct conversion
  %g = getelementptr double, ptr %flat, i64 0
  %p5 = addrspacecast ptr %g to ptr addrspace(5)
  store double 1.000000e+00, ptr addrspace(5) %p5, align 8
  %l = load volatile double, ptr addrspace(5) %a, align 8
  store double %l, ptr addrspace(1) %out, align 8
  ret void
}
attributes #0 = { "amdgpu-flat-work-group-size"="1,256" }
