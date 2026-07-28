; ModuleID = '/lustre/orion/cfd154/scratch/sbryngelson/cce21-dbg/reduced.ll'
source_filename = "ld-temp.o"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.fma.f64(double, double, double) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { double, i32 } @llvm.frexp.f64.i32(double) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.amdgcn.rcp.f64(double) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.ldexp.f64.i32(double, i32) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.fabs.f64(double) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.rint.f64(double) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.sqrt.f64(double) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef align 4 ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr() #0

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite)
declare void @llvm.experimental.noalias.scope.decl(metadata) #1

; Function Attrs: nofree noinline norecurse nounwind
define amdgpu_kernel void @"s_compute_bubble_ee_source$m_bubbles_ee_$ck_L185_6"(double %"$$_arg_dmbeta_c_t6871", double %"$$_arg_dmbeta_t_t6882", double %"$$_arg_dmcson_t6904", double %"$$_arg_dmmass_n_t6915") #2 {
", bb212":
  %r61 = tail call i32 @llvm.amdgcn.workitem.id.x()
  %r65 = zext i32 %r61 to i64
  %r109 = load i32, ptr addrspace(1) null, align 32
  %r119 = load i32, ptr addrspace(1) null, align 32
  %r121 = load i32, ptr addrspace(1) null, align 32
  %r154 = zext nneg i32 %r121 to i64
  %r156 = zext nneg i32 %r119 to i64
  %r256 = mul nuw nsw i64 %r156, %r154
  %r287.not = icmp eq i32 %r109, 0
  br label %"1787utop1"

"1787utop1":                                      ; preds = %"file ../../../lustre/orion/cfd154/scratch/sbryngelson/wt-cce21/src/simulation/m_bubbles_EE.fpp, line 290, in loop at depth 1, bb145", %", bb212"
  %"$$induc_p203_t282.0" = phi i64 [ %r65, %", bb212" ], [ 0, %"file ../../../lustre/orion/cfd154/scratch/sbryngelson/wt-cce21/src/simulation/m_bubbles_EE.fpp, line 290, in loop at depth 1, bb145" ]
  %r426 = sdiv i64 %"$$induc_p203_t282.0", %r256
  %r1553 = load double, ptr addrspace(1) null, align 8
  %r1561 = load double, ptr addrspace(1) null, align 8
  %r1772 = fdiv double 0.000000e+00, %r1561
  %r1773 = fadd double %r1772, 0.000000e+00
  %r1778 = fadd double %r1773, -1.000000e+00
  %r1781 = fdiv double 0.000000e+00, %r1773
  %r1847 = load i64, ptr addrspace(1) inttoptr (i64 -8 to ptr addrspace(1)), align 8
  %r1857 = load i64, ptr addrspace(1) inttoptr (i64 -24 to ptr addrspace(1)), align 8
  %r1858 = sub i64 0, %r1857
  %r1859 = mul i64 %r1847, %r1858
  %r1862 = getelementptr double, ptr null, i64 %r1859
  %r1863 = load double, ptr %r1862, align 8
  %r1864 = load i32, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) null, i64 72), align 8
  %r1865 = sext i32 %r1864 to i64
  %r1866 = mul nsw i64 %r1865, 15
  %gep54 = getelementptr ptr, ptr addrspace(1) null, i64 %r1866
  %r1875 = load ptr, ptr addrspace(1) %gep54, align 8
  %r1944 = load double, ptr %r1875, align 8
  %r2089 = load i64, ptr addrspace(1) inttoptr (i64 -56 to ptr addrspace(1)), align 8
  %r2099 = load i64, ptr addrspace(1) inttoptr (i64 -72 to ptr addrspace(1)), align 8
  %r2100 = sub i64 0, %r2099
  %r2101 = mul i64 %r2089, %r2100
  %r2111 = load i64, ptr addrspace(1) inttoptr (i64 -32 to ptr addrspace(1)), align 8
  %r2121 = load i64, ptr addrspace(1) inttoptr (i64 -48 to ptr addrspace(1)), align 8
  %r2122 = sub i64 0, %r2121
  %r2123 = mul i64 %r2111, %r2122
  %0 = getelementptr double, ptr null, i64 %r2101
  %r2126 = getelementptr double, ptr %0, i64 %r2123
  %r2127 = load double, ptr %r2126, align 8
  br i1 false, label %", in loop at depth 1, bb130", label %", in loop at depth 1, bb134"

", in loop at depth 1, bb130":                    ; preds = %"1787utop1"
  ret void

", in loop at depth 1, bb134":                    ; preds = %"1787utop1"
  %r2257 = load double, ptr null, align 8
  br i1 true, label %", bb7.i66", label %"f_bpres_dot$m_bubbles_.exit"

", bb7.i66":                                      ; preds = %", in loop at depth 1, bb134"
  %r198.i = load double, ptr addrspace(1) null, align 8
  %r199.i = fmul double %r198.i, 0.000000e+00
  br label %"f_bpres_dot$m_bubbles_.exit"

"f_bpres_dot$m_bubbles_.exit":                    ; preds = %", bb7.i66", %", in loop at depth 1, bb134"
  %"$f_bpres_dot_s2.0.i" = phi double [ %r199.i, %", bb7.i66" ], [ 0.000000e+00, %", in loop at depth 1, bb134" ]
  %r2420 = load i64, ptr addrspace(1) inttoptr (i64 64 to ptr addrspace(1)), align 8
  %r2428 = load i64, ptr addrspace(1) inttoptr (i64 48 to ptr addrspace(1)), align 8
  %r2429 = sub i64 0, %r2428
  %r2436 = load i64, ptr addrspace(1) inttoptr (i64 88 to ptr addrspace(1)), align 8
  %r2444 = load i64, ptr addrspace(1) inttoptr (i64 72 to ptr addrspace(1)), align 8
  %r2445 = sub i64 0, %r2444
  %r2446 = mul i64 %r2436, %r2445
  %r2447 = mul i64 %r2420, %r2429
  %1 = getelementptr double, ptr null, i64 %r2447
  %r2698 = getelementptr double, ptr %1, i64 %r2446
  br i1 %r287.not, label %", in loop at depth 1, bb143", label %", in loop at depth 1, bb141"

", in loop at depth 1, bb141":                    ; preds = %"f_bpres_dot$m_bubbles_.exit"
  %r396.i = load double, ptr addrspace(1) null, align 8
  %r397.i = fmul double %r396.i, 0.000000e+00
  %r414.i = load i32, ptr addrspace(1) null, align 4
  %r90.i11712.i = load i32, ptr addrspace(1) null, align 4
  %r91.i11713.i = icmp eq i32 %r90.i11712.i, 0
  %r.i.i18693.i = load i32, ptr addrspace(1) null, align 4
  %r13.i.i18694.not.i = icmp eq i32 %r.i.i18693.i, 3
  %r165.i.i19031.i = load double, ptr addrspace(1) null, align 8
  %r32.i.i18709.i = load i32, ptr addrspace(1) getelementptr (i8, ptr addrspace(1) null, i64 20), align 4
  %r49.i.i18724.not.i = icmp eq i32 %r32.i.i18709.i, 0
  %r221.i1551.i16917.i = fsub double 0.000000e+00, %r1944
  %r222.i1552.i16918.i = fmul double 0.000000e+00, %r221.i1551.i16917.i
  %r223.i1553.i16919.i = fdiv double 0.000000e+00, %r222.i1552.i16918.i
  %2 = tail call double @llvm.sqrt.f64(double %r223.i1553.i16919.i)
  %r238.i5466.i17087.i = fmul double %2, 0.000000e+00
  %r239.i5467.i17088.i = fdiv double 0.000000e+00, %r238.i5466.i17087.i
  %r292.i.i17142.i = fmul double 0.000000e+00, %r239.i5467.i17088.i
  %r40.i1399.i11889.i = fdiv double %r1778, 0.000000e+00
  %r45.i1403.i11893.i = fadd double %r1781, 0.000000e+00
  %r47.i1405.i11895.i = fdiv double 0.000000e+00, %r45.i1403.i11893.i
  %r139.i1493.i11983.i = fmul double %r1773, 0.000000e+00
  %r119.i2309.i12124.i = fdiv double -1.000000e+00, %r1773
  %r121.i2311.i12126.i = fptosi double %r119.i2309.i12124.i to i64
  %r122.i2312.i12127.i = shl i64 %r121.i2311.i12126.i, 0
  %3 = insertelement <2 x i64> zeroinitializer, i64 %r122.i2312.i12127.i, i64 0
  %r.i.i18253.i = load i32, ptr addrspace(1) null, align 4
  %r13.i.i18254.not.i = icmp eq i32 %r.i.i18253.i, 0
  %r533.i13693.i = load double, ptr addrspace(1) null, align 8
  %r534.i13694.i = fadd double %r533.i13693.i, 0.000000e+00
  %.pre79 = fdiv double 0.000000e+00, %r1553
  %4 = fmul double %.pre79, 0.000000e+00
  %.pre80 = fdiv double 0.000000e+00, 0.000000e+00
  br label %"1961utop1.i"

"1961utop1.i":                                    ; preds = %"1967ubot1.i", %", in loop at depth 1, bb141"
  %"$$_pb_local_t113.1" = phi double [ %r2257, %", in loop at depth 1, bb141" ], [ %"$$_pb_local_t113.1", %"1967ubot1.i" ]
  %"$$_myv_t120.0" = phi double [ %r2127, %", in loop at depth 1, bb141" ], [ %"$$_myv_t120.1", %"1967ubot1.i" ]
  %"$$_myr_t121.0" = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %"$$_myr_t121.1", %"1967ubot1.i" ]
  %mydmvdt_tmp.i4985.sroa.6.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %mydmvdt_tmp.i4985.sroa.6.3.i, %"1967ubot1.i" ]
  %mydmvdt_tmp.i4985.sroa.0.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %mydmvdt_tmp.i4985.sroa.0.3.i, %"1967ubot1.i" ]
  %mydmvdt_tmp.i.sroa.0.0.i = phi double [ undef, %", in loop at depth 1, bb141" ], [ %mydmvdt_tmp.i.sroa.0.3.i, %"1967ubot1.i" ]
  %mygamma_m.i19984.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %mygamma_m.i19984.3.i, %"1967ubot1.i" ]
  %myv_tmp2.sroa.96.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %myv_tmp2.sroa.96.3.i, %"1967ubot1.i" ]
  %myv_tmp1.sroa.48.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %myv_tmp1.sroa.48.2.i, %"1967ubot1.i" ]
  %mymv_tmp2.sroa.18.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %mymv_tmp2.sroa.18.3.i, %"1967ubot1.i" ]
  %mymv_tmp2.sroa.0.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %mymv_tmp2.sroa.0.3.i, %"1967ubot1.i" ]
  %h.0.i = phi double [ 0x3F1A36E2EB1C432C, %", in loop at depth 1, bb141" ], [ %h.3.i, %"1967ubot1.i" ]
  %mygamma_m.i22184.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %mygamma_m.i22184.3.i, %"1967ubot1.i" ]
  %myr_m.i22183.0.i = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %myr_m.i22183.3.i, %"1967ubot1.i" ]
  %"$iter_count_s15.0.i" = phi i32 [ 0, %", in loop at depth 1, bb141" ], [ %"$iter_count_s15.2.i", %"1967ubot1.i" ]
  %"$t_new_s14.0.i" = phi double [ 0.000000e+00, %", in loop at depth 1, bb141" ], [ %"$t_new_s14.1.i", %"1967ubot1.i" ]
  %r402.i = fsub double %r397.i, 0.000000e+00
  %r407.i = fcmp ole double 0.000000e+00, %r397.i
  %r410.i = select i1 %r407.i, double %h.0.i, double %r402.i
  %r415.not.i = icmp slt i32 %"$iter_count_s15.0.i", %r414.i
  br i1 %r415.not.i, label %", in loop at depth 0, bb17.i", label %"1967ubot1.i"

", in loop at depth 0, bb17.i":                   ; preds = %"1961utop1.i"
  %r28.i.i18705.i = fadd double %"$$_arg_dmmass_n_t6915", 0.000000e+00
  %r31.i.i18708.i = fdiv double 0.000000e+00, %r28.i.i18705.i
  %r50.i.i18725.i = select i1 %r49.i.i18724.not.i, double %r31.i.i18708.i, double 0.000000e+00
  %r56.i.i18731.i = tail call double @llvm.fma.f64(double %"$$_arg_dmmass_n_t6915", double 0.000000e+00, double 0.000000e+00)
  %r67.i.i18741.i = tail call double @llvm.fma.f64(double %r50.i.i18725.i, double 0.000000e+00, double 0.000000e+00)
  %r80.i.i18751.i = fmul double %"$$_myr_t121.0", 0.000000e+00
  %r214.i.i18978.i = fsub double %"$$_pb_local_t113.1", %r165.i.i19031.i
  %5 = fneg double %r214.i.i18978.i
  %r216.i.i18980.i = fmul double 0.000000e+00, %5
  %r263.i1583.i17415.i = fmul double %"$$_myv_t120.0", 0.000000e+00
  %r229.i5459.i17079.i = fdiv double %"$$_myv_t120.0", %2
  %r232.i.i17082.i = fmul double %"$$_myv_t120.0", 0.000000e+00
  %r241.i.i17090.i = tail call double @llvm.fma.f64(double %r229.i5459.i17079.i, double 0.000000e+00, double 0.000000e+00)
  %r245.i5472.i17094.i = fmul double 0.000000e+00, %r241.i.i17090.i
  %r251.i5476.i17100.i = fmul double %r232.i.i17082.i, 0.000000e+00
  %r253.i5478.i17102.i = fmul double %r251.i5476.i17100.i, 0.000000e+00
  %r254.i5479.i17103.i = fmul double %r253.i5478.i17102.i, 0.000000e+00
  %r263.i5487.i17112.i = fadd double %r229.i5459.i17079.i, 0.000000e+00
  %r280.i.i17127.i = fmul double %"$$_myr_t121.0", 0.000000e+00
  %r294.i.i17144.i = tail call double @llvm.fma.f64(double %r292.i.i17142.i, double 0.000000e+00, double %r280.i.i17127.i)
  %r14.i1599.i11813.i = fmul double %"$$_myv_t120.0", 0.000000e+00
  %r735.i14387.i = tail call double @llvm.fabs.f64(double %"$$_myr_t121.0")
  %r751.i14401.i = tail call double @llvm.fabs.f64(double %"$$_myv_t120.0")
  %r16.i1601.i5177.i = fmul double 0.000000e+00, %r14.i1599.i11813.i
  %r91.i1671.i10103.i = fsub double 0.000000e+00, %r16.i1601.i5177.i
  %r92.i1672.i10104.i = fadd double 0.000000e+00, %r91.i1671.i10103.i
  %r166.i2345.i5531.i = fdiv double 0.000000e+00, %r80.i.i18751.i
  %r63.i4935.i8429.i = load double, ptr addrspace(1) null, align 32
  %r33.i1930.i7235.i = fdiv double 0.000000e+00, %r63.i4935.i8429.i
  %r38.i1935.i7240.i = fadd double %r33.i1930.i7235.i, 0.000000e+00
  %r21.i2172.i7410.i = load i32, ptr addrspace(1) null, align 32
  %r22.i2173.i7411.i = icmp eq i32 %r21.i2172.i7410.i, 0
  %r.i.i22213.i = load i32, ptr addrspace(1) null, align 4
  %r13.i.i22214.not.i = icmp eq i32 %r.i.i22213.i, 0
  %r171.i.i22555.i = load double, ptr addrspace(1) null, align 8
  %r32.i.i22229.i = load i32, ptr addrspace(1) getelementptr (i8, ptr addrspace(1) null, i64 20), align 4
  %r49.i.i22244.not.i = icmp eq i32 %r32.i.i22229.i, 0
  %"$c2_liquid_s1.i2150.i4702.0.i.pre-phi" = select i1 %r22.i2173.i7411.i, double %r223.i1553.i16919.i, double 0.000000e+00
  %6 = fmul double %"$c2_liquid_s1.i2150.i4702.0.i.pre-phi", 0.000000e+00
  br label %"1967utop1.i"

"1967utop1.i":                                    ; preds = %", in inner loop at depth 1, bb106.i", %", in loop at depth 0, bb17.i"
  %mydmvdt_tmp.i4985.sroa.6.1.i = phi double [ %mydmvdt_tmp.i4985.sroa.6.0.i, %", in loop at depth 0, bb17.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mydmvdt_tmp.i4985.sroa.0.1.i = phi double [ %mydmvdt_tmp.i4985.sroa.0.0.i, %", in loop at depth 0, bb17.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mydmvdt_tmp.i.sroa.0.1.i = phi double [ %mydmvdt_tmp.i.sroa.0.0.i, %", in loop at depth 0, bb17.i" ], [ %mydmvdt_tmp.i.sroa.0.2.i, %", in inner loop at depth 1, bb106.i" ]
  %myr_m.i18223.1.i = phi double [ 0.000000e+00, %", in loop at depth 0, bb17.i" ], [ %myr_m.i18223.4.i, %", in inner loop at depth 1, bb106.i" ]
  %mygamma_m.i18664.1.i = phi double [ 0.000000e+00, %", in loop at depth 0, bb17.i" ], [ %mygamma_m.i18664.3.i, %", in inner loop at depth 1, bb106.i" ]
  %myr_m.i18663.1.i = phi double [ 0.000000e+00, %", in loop at depth 0, bb17.i" ], [ %myr_m.i18663.3.i, %", in inner loop at depth 1, bb106.i" ]
  %mygamma_m.i19984.1.i = phi double [ %mygamma_m.i19984.0.i, %", in loop at depth 0, bb17.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %myv_tmp2.sroa.96.1.i = phi double [ %myv_tmp2.sroa.96.0.i, %", in loop at depth 0, bb17.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %myv_tmp1.sroa.48.1.i = phi double [ %myv_tmp1.sroa.48.0.i, %", in loop at depth 0, bb17.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %myr_tmp2.sroa.110.1.i = phi double [ 0.000000e+00, %", in loop at depth 0, bb17.i" ], [ %myr_tmp2.sroa.110.2.i, %", in inner loop at depth 1, bb106.i" ]
  %myr_tmp1.sroa.55.1.i = phi double [ 0.000000e+00, %", in loop at depth 0, bb17.i" ], [ %myr_tmp1.sroa.55.3.i, %", in inner loop at depth 1, bb106.i" ]
  %mymv_tmp2.sroa.18.1.i = phi double [ %mymv_tmp2.sroa.18.0.i, %", in loop at depth 0, bb17.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mymv_tmp2.sroa.0.1.i = phi double [ %mymv_tmp2.sroa.0.0.i, %", in loop at depth 0, bb17.i" ], [ %mymv_tmp2.sroa.0.2.i, %", in inner loop at depth 1, bb106.i" ]
  %h.1.i = phi double [ %r410.i, %", in loop at depth 0, bb17.i" ], [ %h.2.i, %", in inner loop at depth 1, bb106.i" ]
  %mygamma_m.i22184.1.i = phi double [ %mygamma_m.i22184.0.i, %", in loop at depth 0, bb17.i" ], [ %mygamma_m.i22184.2.i, %", in inner loop at depth 1, bb106.i" ]
  %myr_m.i22183.1.i = phi double [ %myr_m.i22183.0.i, %", in loop at depth 0, bb17.i" ], [ %myr_m.i22183.2.i, %", in inner loop at depth 1, bb106.i" ]
  %"$iter_count_s15.1.i" = phi i32 [ %"$iter_count_s15.0.i", %", in loop at depth 0, bb17.i" ], [ 0, %", in inner loop at depth 1, bb106.i" ]
  %r419.i = add nsw i32 %"$iter_count_s15.1.i", 0
  br i1 %r91.i11713.i, label %"f_cpbw_km$m_bubbles_.exit3962.i16853.i", label %", bb3.i11716.i"

", bb3.i11716.i":                                 ; preds = %"1967utop1.i"
  %mygamma_m.i18664.4.i = select i1 %r13.i.i18694.not.i, double %r67.i.i18741.i, double %mygamma_m.i18664.1.i
  %myr_m.i18663.4.i = select i1 %r13.i.i18694.not.i, double %r56.i.i18731.i, double %myr_m.i18663.1.i
  br i1 %r13.i.i18694.not.i, label %", bb3.i61.i18790.i", label %"f_cpbw_km$m_bubbles_.exit3962.i16853.i"

", bb3.i61.i18790.i":                             ; preds = %", bb3.i11716.i"
  br label %"f_cpbw_km$m_bubbles_.exit3962.i16853.i"

"f_cpbw_km$m_bubbles_.exit3962.i16853.i":         ; preds = %", bb3.i61.i18790.i", %", bb3.i11716.i", %"1967utop1.i"
  %mydpbdt_tmp.i11622.sroa.0.0.i = phi double [ %"$f_bpres_dot_s2.0.i", %"1967utop1.i" ], [ 0.000000e+00, %", bb3.i61.i18790.i" ], [ %r216.i.i18980.i, %", bb3.i11716.i" ]
  %mygamma_m.i18664.3.i = phi double [ %mygamma_m.i18664.1.i, %"1967utop1.i" ], [ %mygamma_m.i18664.4.i, %", bb3.i11716.i" ], [ 0.000000e+00, %", bb3.i61.i18790.i" ]
  %myr_m.i18663.3.i = phi double [ %myr_m.i18663.1.i, %"1967utop1.i" ], [ 0.000000e+00, %", bb3.i11716.i" ], [ %myr_m.i18663.4.i, %", bb3.i61.i18790.i" ]
  %r162.i3879.i16867.i = fadd double %"$$_pb_local_t113.1", 0.000000e+00
  %r186.i5446.i17065.i = fadd double %mydpbdt_tmp.i11622.sroa.0.0.i, 0.000000e+00
  %r258.i5482.i17107.i = fadd double %r186.i5446.i17065.i, %r254.i5479.i17103.i
  %r260.i5484.i17109.i = fmul double %"$$_myr_t121.0", %r258.i5482.i17107.i
  %r270.i5492.i17117.i = fsub double %r162.i3879.i16867.i, %r1863
  %r271.i5493.i17118.i = fmul double %r263.i5487.i17112.i, %r270.i5492.i17117.i
  %r273.i5495.i17120.i = fdiv double %r271.i5493.i17118.i, %r1553
  %r274.i5496.i17121.i = tail call double @llvm.fma.f64(double %r239.i5467.i17088.i, double %r260.i5484.i17109.i, double %r273.i5495.i17120.i)
  %r275.i5497.i17122.i = tail call double @llvm.fma.f64(double %r245.i5472.i17094.i, double 0.000000e+00, double %r274.i5496.i17121.i)
  %"$f_rddot_km_s13.i.i10988.0.i" = fdiv double %r275.i5497.i17122.i, %r294.i.i17144.i
  %r186.i12330.i = fadd double %"$$_myr_t121.0", 0.000000e+00
  %r195.i12339.i = fcmp ult double %r186.i12330.i, 0.000000e+00
  br i1 %r195.i12339.i, label %"s_advance_substep$m_bubbles_.exit17467.i", label %", bb9.i12347.i"

", bb9.i12347.i":                                 ; preds = %"f_cpbw_km$m_bubbles_.exit3962.i16853.i"
  br i1 %r13.i.i18254.not.i, label %", bb3.i.i18256.i", label %", bb11.i.i18590.i"

", bb3.i.i18256.i":                               ; preds = %", bb9.i12347.i"
  br label %", bb3.i61.i18350.i"

", bb11.i.i18590.i":                              ; preds = %", bb9.i12347.i"
  br label %", bb3.i61.i18350.i"

", bb3.i61.i18350.i":                             ; preds = %", bb11.i.i18590.i", %", bb3.i.i18256.i"
  %myr_m.i18223.5.i = phi double [ 0.000000e+00, %", bb3.i.i18256.i" ], [ %myr_m.i18223.1.i, %", bb11.i.i18590.i" ]
  %r738.i14390.i = fdiv double 0.000000e+00, %r735.i14387.i
  %r777.i14423.i = fdiv double 0.000000e+00, %r751.i14401.i
  %r780.i14426.i = fcmp oge double 0.000000e+00, 0.000000e+00
  %r783.i14428.i = select i1 %r780.i14426.i, double %r777.i14423.i, double 0.000000e+00
  %r796.i14439.i = fcmp une double %"$f_rddot_km_s13.i.i10988.0.i", 0.000000e+00
  %or.cond117 = select i1 %r91.i11713.i, i1 false, i1 %r796.i14439.i
  %"$err_s3.i11619.0.i" = select i1 %or.cond117, double %r783.i14428.i, double 0.000000e+00
  %r823.i14466.i = fmul double %"$err_s3.i11619.0.i", 0.000000e+00
  %r824.i14467.i = tail call double @llvm.fma.f64(double %r738.i14390.i, double 0.000000e+00, double %r823.i14466.i)
  %r825.i14468.i = fmul double %r824.i14467.i, 0.000000e+00
  %7 = tail call noundef double @llvm.sqrt.f64(double %r825.i14468.i)
  br label %"s_advance_substep$m_bubbles_.exit17467.i"

"s_advance_substep$m_bubbles_.exit17467.i":       ; preds = %", bb3.i61.i18350.i", %"f_cpbw_km$m_bubbles_.exit3962.i16853.i"
  %myr_m.i18223.4.i = phi double [ %myr_m.i18223.5.i, %", bb3.i61.i18350.i" ], [ %myr_m.i18223.1.i, %"f_cpbw_km$m_bubbles_.exit3962.i16853.i" ]
  %myv_tmp1.sroa.48.3.i = phi double [ 0.000000e+00, %", bb3.i61.i18350.i" ], [ %myv_tmp1.sroa.48.1.i, %"f_cpbw_km$m_bubbles_.exit3962.i16853.i" ]
  %myr_tmp1.sroa.55.3.i = phi double [ 0.000000e+00, %", bb3.i61.i18350.i" ], [ %myr_tmp1.sroa.55.1.i, %"f_cpbw_km$m_bubbles_.exit3962.i16853.i" ]
  %err.sroa.0.0.i = phi double [ %7, %", bb3.i61.i18350.i" ], [ %r534.i13694.i, %"f_cpbw_km$m_bubbles_.exit3962.i16853.i" ]
  %r491.i = fcmp ugt double %err.sroa.0.0.i, %r533.i13693.i
  br i1 %r491.i, label %", in inner loop at depth 1, bb21.i", label %", in inner loop at depth 1, bb23.i"

", in inner loop at depth 1, bb21.i":             ; preds = %"s_advance_substep$m_bubbles_.exit17467.i"
  %r496.i = fmul double %h.1.i, 0.000000e+00
  br label %", in inner loop at depth 1, bb106.i"

", in inner loop at depth 1, bb23.i":             ; preds = %"s_advance_substep$m_bubbles_.exit17467.i"
  %r500.i = fmul double %h.1.i, 5.000000e-01
  br label %"l$00066.i5114.i"

"l$00066.i5114.i":                                ; preds = %", in inner loop at depth 1, bb23.i"
  %r91.i1447.i5299.i = tail call double @llvm.fma.f64(double %r92.i1672.i10104.i, double %r47.i1405.i11895.i, double 0.000000e+00)
  %8 = fcmp oeq double %r91.i1447.i5299.i, 0.000000e+00
  %9 = select i1 %8, double 0xFFF0000000000000, double 0.000000e+00
  %r113.i1469.i5321.i = fmul double %r40.i1399.i11889.i, %9
  %10 = fcmp ogt double %r113.i1469.i5321.i, 0.000000e+00
  %11 = select i1 %10, double 0x7FF0000000000000, double 0.000000e+00
  %r117.i1472.i5324.i = insertelement <2 x double> zeroinitializer, double 0.000000e+00, i64 0
  %12 = bitcast <2 x double> zeroinitializer to <2 x i64>
  %r131.i1485.i5337.i = fmul double %r1773, %11
  %r132.i1486.i5338.i = fmul double %r45.i1403.i11893.i, %r131.i1485.i5337.i
  %r134.i1488.i5340.i = fdiv double %r132.i1486.i5338.i, 0.000000e+00
  %r142.i1496.i5348.i = fmul double %r1778, %r134.i1488.i5340.i
  %r143.i1497.i5349.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r139.i1493.i11983.i, double %r142.i1496.i5348.i)
  %13 = tail call noundef double @llvm.sqrt.f64(double %r143.i1497.i5349.i)
  %r38.i2019.i5377.i = load double, ptr addrspace(1) null, align 8
  %r140.i2329.i5507.i = fmul double %9, %r119.i2309.i12124.i
  %14 = fmul double %r140.i2329.i5507.i, 0.000000e+00
  %15 = tail call double @llvm.rint.f64(double %14)
  %16 = fptosi double %15 to i32
  %17 = tail call double @llvm.ldexp.f64.i32(double 1.000000e+00, i32 %16)
  %r144.i2333.i5510.i = insertelement <2 x double> zeroinitializer, double 0.000000e+00, i64 0
  %18 = bitcast <2 x double> zeroinitializer to <2 x i64>
  %19 = fmul double %r38.i2019.i5377.i, 0.000000e+00
  %r207.i2378.i5569.i = fmul double %19, 0.000000e+00
  %r208.i2379.i5570.i = tail call double @llvm.fma.f64(double %17, double %r166.i2345.i5531.i, double %r207.i2378.i5569.i)
  %r22.i3093.i5590.i = fdiv double 0.000000e+00, %13
  %r28.i3099.i5595.i = fmul double %"$$_myv_t120.0", 0.000000e+00
  %r40.i3111.i5605.i = fadd double %r28.i3099.i5595.i, 0.000000e+00
  %r44.i3115.i5609.i = fmul double %"$$_myr_t121.0", 0.000000e+00
  %r48.i3119.i5612.i = fmul double %r44.i3115.i5609.i, %r208.i2379.i5570.i
  %r55.i3126.i5619.i = fmul double %r263.i1583.i17415.i, 0.000000e+00
  %r56.i3127.i5620.i = tail call double @llvm.fma.f64(double %r22.i3093.i5590.i, double %r48.i3119.i5612.i, double %r55.i3126.i5619.i)
  %r57.i3128.i5621.i = tail call double @llvm.fma.f64(double %r134.i1488.i5340.i, double %r40.i3111.i5605.i, double %r56.i3127.i5620.i)
  %r110.i3181.i5670.i = fmul double %r44.i3115.i5609.i, 0.000000e+00
  %r111.i3182.i5671.i = fdiv double %r57.i3128.i5621.i, %r110.i3181.i5670.i
  %r186.i5692.i = fadd double %"$$_myr_t121.0", 0.000000e+00
  %r195.i5701.i = fcmp ult double %r186.i5692.i, 0.000000e+00
  br i1 %r195.i5701.i, label %"s_advance_substep$m_bubbles_.exit10829.i", label %", bb9.i5709.i"

", bb9.i5709.i":                                  ; preds = %"l$00066.i5114.i"
  br i1 %r91.i11713.i, label %"l$00070.i5788.i", label %", bb11.i5728.i"

", bb11.i5728.i":                                 ; preds = %", bb9.i5709.i"
  br i1 false, label %", bb3.i.i20016.i", label %", bb11.i.i20350.i"

", bb3.i.i20016.i":                               ; preds = %", bb11.i5728.i"
  br label %", bb3.i61.i20110.i"

", bb11.i.i20350.i":                              ; preds = %", bb11.i5728.i"
  br label %", bb3.i61.i20110.i"

", bb3.i61.i20110.i":                             ; preds = %", bb11.i.i20350.i", %", bb3.i.i20016.i"
  %mygamma_m.i19984.6.i = phi double [ 0.000000e+00, %", bb3.i.i20016.i" ], [ %mygamma_m.i19984.1.i, %", bb11.i.i20350.i" ]
  %r70.i109.i20156.i = fmul double %"$$_arg_dmbeta_t_t6882", 0.000000e+00
  %r71.i110.i20157.i = fmul double 0.000000e+00, %r70.i109.i20156.i
  %r73.i.i20159.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r71.i110.i20157.i, double 0.000000e+00)
  %r75.i112.i20161.i = fmul double %mygamma_m.i19984.6.i, %r73.i.i20159.i
  %r76.i113.i20162.i = fmul double 0.000000e+00, %r75.i112.i20161.i
  br label %"l$00070.i5788.i"

"l$00070.i5788.i":                                ; preds = %", bb3.i61.i20110.i", %", bb9.i5709.i"
  %mydmvdt_tmp.i4985.sroa.6.4.i = phi double [ %mydmvdt_tmp.i4985.sroa.6.1.i, %", bb9.i5709.i" ], [ 0.000000e+00, %", bb3.i61.i20110.i" ]
  %mydpbdt_tmp.i4984.sroa.9.0.i = phi double [ 0.000000e+00, %", bb9.i5709.i" ], [ %r76.i113.i20162.i, %", bb3.i61.i20110.i" ]
  %r132.i974.i6678.i = fmul double %r45.i1403.i11893.i, 0.000000e+00
  %r134.i976.i6680.i = fdiv double %r132.i974.i6678.i, 0.000000e+00
  %r142.i984.i6688.i = fmul double 0.000000e+00, 0.000000e+00
  %r143.i985.i6689.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r139.i1493.i11983.i, double 0.000000e+00)
  %20 = tail call noundef double @llvm.sqrt.f64(double %r143.i985.i6689.i)
  %r38.i2127.i6717.i = load double, ptr addrspace(1) null, align 8
  %r167.i2793.i6873.i = fadd double %"$f_bpres_dot_s2.0.i", 0.000000e+00
  %21 = fmul double %r38.i2127.i6717.i, %4
  %r207.i2833.i6910.i = fmul double %21, 0.000000e+00
  %r208.i2834.i6911.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r167.i2793.i6873.i, double %r207.i2833.i6910.i)
  %r22.i3331.i6931.i = fdiv double 1.000000e+00, %20
  %r28.i3337.i6936.i = fmul double 0.000000e+00, %r22.i3331.i6931.i
  %r31.i3340.i6939.i = fsub double 0.000000e+00, %r28.i3337.i6936.i
  %r40.i3349.i6946.i = fadd double %r28.i3337.i6936.i, 0.000000e+00
  %r44.i3353.i6950.i = fmul double 0.000000e+00, %r31.i3340.i6939.i
  %r48.i3357.i6953.i = fmul double %r44.i3353.i6950.i, %r208.i2834.i6911.i
  %r50.i3359.i6955.i = tail call double @llvm.fma.f64(double %r28.i3337.i6936.i, double 0.000000e+00, double 0.000000e+00)
  %r51.i3360.i6956.i = fmul double %r50.i3359.i6955.i, 0.000000e+00
  %r55.i3364.i6960.i = fmul double 0.000000e+00, %r51.i3360.i6956.i
  %r56.i3365.i6961.i = tail call double @llvm.fma.f64(double %r22.i3331.i6931.i, double %r48.i3357.i6953.i, double %r55.i3364.i6960.i)
  %r57.i3366.i6962.i = tail call double @llvm.fma.f64(double %r134.i976.i6680.i, double %r40.i3349.i6946.i, double %r56.i3365.i6961.i)
  %r110.i3419.i7011.i = fmul double %r44.i3353.i6950.i, 0.000000e+00
  %r111.i3420.i7012.i = fdiv double %r57.i3366.i6962.i, %r110.i3419.i7011.i
  %r520.i7042.i = fadd double %"$$_myr_t121.0", 0.000000e+00
  %r559.i7076.i = tail call double @llvm.fma.f64(double %r111.i3420.i7012.i, double 0.000000e+00, double %r111.i3182.i5671.i)
  %r560.i7077.i = fadd double 0.000000e+00, %r559.i7076.i
  %r562.i7079.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r560.i7077.i, double 0.000000e+00)
  %r594.i7105.i = tail call double @llvm.fma.f64(double %"$f_bpres_dot_s2.0.i", double 0.000000e+00, double 0.000000e+00)
  %r595.i7106.i = fadd double %mydpbdt_tmp.i4984.sroa.9.0.i, %r594.i7105.i
  %r599.i7110.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r595.i7106.i, double 0.000000e+00)
  %r626.i7130.i = tail call double @llvm.fma.f64(double 0.000000e+00, double 0.000000e+00, double %mydmvdt_tmp.i4985.sroa.0.1.i)
  %r627.i7131.i = fadd double %mydmvdt_tmp.i4985.sroa.6.4.i, %r626.i7130.i
  %r631.i7135.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r627.i7131.i, double %mymv_tmp2.sroa.0.1.i)
  br i1 false, label %", bb3.i.i19136.i", label %", bb11.i.i19470.i"

", bb3.i.i19136.i":                               ; preds = %"l$00070.i5788.i"
  br label %", bb3.i61.i19230.i"

", bb11.i.i19470.i":                              ; preds = %"l$00070.i5788.i"
  br label %", bb3.i61.i19230.i"

", bb3.i61.i19230.i":                             ; preds = %", bb11.i.i19470.i", %", bb3.i.i19136.i"
  %r160.i3014.i7568.i = tail call double @llvm.fma.f64(double 0.000000e+00, double 0.000000e+00, double %r38.i1935.i7240.i)
  %r162.i3016.i7570.i = fmul double %r562.i7079.i, %r160.i3014.i7568.i
  %r165.i3019.i7573.i = fmul double %r520.i7042.i, %r520.i7042.i
  %r166.i3020.i7574.i = fdiv double %r162.i3016.i7570.i, %r165.i3019.i7573.i
  %r167.i3021.i7575.i = fadd double 0.000000e+00, %r166.i3020.i7574.i
  %22 = fmul double 0.000000e+00, %6
  %r207.i3061.i7612.i = fmul double %22, 0.000000e+00
  %r208.i3062.i7613.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r167.i3021.i7575.i, double %r207.i3061.i7612.i)
  %r44.i3472.i7652.i = fmul double %r520.i7042.i, 0.000000e+00
  %r48.i3476.i7655.i = fmul double %r44.i3472.i7652.i, %r208.i3062.i7613.i
  %r56.i3484.i7663.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r48.i3476.i7655.i, double 0.000000e+00)
  %r57.i3485.i7664.i = tail call double @llvm.fma.f64(double 0.000000e+00, double 0.000000e+00, double %r56.i3484.i7663.i)
  %r110.i3538.i7713.i = fmul double %r44.i3472.i7652.i, 0.000000e+00
  %r111.i3539.i7714.i = fdiv double %r57.i3485.i7664.i, %r110.i3538.i7713.i
  %r731.i7745.i = tail call double @llvm.fabs.f64(double %r520.i7042.i)
  %r736.i7750.i = fcmp ogt double %r731.i7745.i, 0.000000e+00
  %r737.i7751.i = select i1 %r736.i7750.i, double %r731.i7745.i, double 0.000000e+00
  %r738.i7752.i = fdiv double 0.000000e+00, %r737.i7751.i
  %r773.i7781.i = tail call double @llvm.fma.f64(double %r111.i3539.i7714.i, double 0.000000e+00, double 0.000000e+00)
  %r774.i7782.i = fadd double 0.000000e+00, %r773.i7781.i
  %r775.i7783.i = fmul double 0.000000e+00, %r774.i7782.i
  %r777.i7785.i = fdiv double %r775.i7783.i, %r751.i14401.i
  %r780.i7788.i = fcmp oge double 0.000000e+00, 0.000000e+00
  %r783.i7790.i = select i1 %r780.i7788.i, double %r777.i7785.i, double 0.000000e+00
  %r823.i7828.i = fmul double 0.000000e+00, %r783.i7790.i
  %r824.i7829.i = tail call double @llvm.fma.f64(double %r738.i7752.i, double 0.000000e+00, double %r823.i7828.i)
  %r825.i7830.i = fmul double %r824.i7829.i, 0.000000e+00
  %23 = tail call noundef double @llvm.sqrt.f64(double %r825.i7830.i)
  br label %"s_advance_substep$m_bubbles_.exit10829.i"

"s_advance_substep$m_bubbles_.exit10829.i":       ; preds = %", bb3.i61.i19230.i", %"l$00066.i5114.i"
  %mydmvdt_tmp.i4985.sroa.6.5.i = phi double [ %mydmvdt_tmp.i4985.sroa.6.4.i, %", bb3.i61.i19230.i" ], [ 0.000000e+00, %"l$00066.i5114.i" ]
  %mygamma_m.i19984.5.i = phi double [ 0.000000e+00, %", bb3.i61.i19230.i" ], [ %mygamma_m.i19984.1.i, %"l$00066.i5114.i" ]
  %myv_tmp2.sroa.96.5.i = phi double [ 0.000000e+00, %", bb3.i61.i19230.i" ], [ %myv_tmp2.sroa.96.1.i, %"l$00066.i5114.i" ]
  %myr_tmp2.sroa.110.5.i = phi double [ %r520.i7042.i, %", bb3.i61.i19230.i" ], [ %myr_tmp2.sroa.110.1.i, %"l$00066.i5114.i" ]
  %mypb_tmp2.sroa.54.2.i = phi double [ %r599.i7110.i, %", bb3.i61.i19230.i" ], [ 0.000000e+00, %"l$00066.i5114.i" ]
  %mymv_tmp2.sroa.18.7.i = phi double [ %r631.i7135.i, %", bb3.i61.i19230.i" ], [ %mymv_tmp2.sroa.18.1.i, %"l$00066.i5114.i" ]
  %err.sroa.7.0.i = phi double [ %23, %", bb3.i61.i19230.i" ], [ %r534.i13694.i, %"l$00066.i5114.i" ]
  %r575.i = fcmp ugt double %err.sroa.7.0.i, 0.000000e+00
  br i1 %r575.i, label %", in inner loop at depth 1, bb26.i", label %", in inner loop at depth 1, bb28.i"

", in inner loop at depth 1, bb26.i":             ; preds = %"s_advance_substep$m_bubbles_.exit10829.i"
  %r580.i = fmul double %h.1.i, 0.000000e+00
  br label %", in inner loop at depth 1, bb106.i"

", in inner loop at depth 1, bb28.i":             ; preds = %"s_advance_substep$m_bubbles_.exit10829.i"
  br i1 %r91.i11713.i, label %"l$00066.i.i", label %", bb3.i3989.i"

", bb3.i3989.i":                                  ; preds = %", in inner loop at depth 1, bb28.i"
  br i1 %r13.i.i22214.not.i, label %", bb3.i.i22216.i", label %", bb11.i.i22550.i"

", bb3.i.i22216.i":                               ; preds = %", bb3.i3989.i"
  %r50.i.i22245.i = select i1 %r49.i.i22244.not.i, double 0.000000e+00, double 0x7FF0000000000000
  %r67.i.i22261.i = tail call double @llvm.fma.f64(double %r50.i.i22245.i, double 0.000000e+00, double 0.000000e+00)
  br label %", bb3.i61.i22310.i"

", bb11.i.i22550.i":                              ; preds = %", bb3.i3989.i"
  br label %", bb3.i61.i22310.i"

", bb3.i61.i22310.i":                             ; preds = %", bb11.i.i22550.i", %", bb3.i.i22216.i"
  %fvapflux.i22185.5.i = phi double [ 0.000000e+00, %", bb3.i.i22216.i" ], [ 0x7FF8000000000000, %", bb11.i.i22550.i" ]
  %mygamma_m.i22184.5.i = phi double [ %r67.i.i22261.i, %", bb3.i.i22216.i" ], [ %mygamma_m.i22184.1.i, %", bb11.i.i22550.i" ]
  %myr_m.i22183.5.i = phi double [ 0.000000e+00, %", bb3.i.i22216.i" ], [ %myr_m.i22183.1.i, %", bb11.i.i22550.i" ]
  %r66.i106.i22352.i = fdiv double 0.000000e+00, %myr_m.i22183.5.i
  %r68.i108.i22354.i = fsub double %r66.i106.i22352.i, %r171.i.i22555.i
  %24 = fneg double %r68.i108.i22354.i
  %r70.i109.i22356.i = fmul double 0.000000e+00, %24
  %r71.i110.i22357.i = fmul double 0.000000e+00, %r70.i109.i22356.i
  %r73.i.i22359.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r71.i110.i22357.i, double 0.000000e+00)
  %r75.i112.i22361.i = fmul double %mygamma_m.i22184.5.i, %r73.i.i22359.i
  %r76.i113.i22362.i = fmul double 0.000000e+00, %r75.i112.i22361.i
  %r49.i22370.i = fmul double %fvapflux.i22185.5.i, 0x402921FB54442D18
  %r53.i22374.i = fmul double 0.000000e+00, %r49.i22370.i
  br label %"l$00066.i.i"

"l$00066.i.i":                                    ; preds = %", bb3.i61.i22310.i", %", in inner loop at depth 1, bb28.i"
  %mydpbdt_tmp.i.sroa.0.0.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb28.i" ], [ %r76.i113.i22362.i, %", bb3.i61.i22310.i" ]
  %mydmvdt_tmp.i.sroa.0.4.i = phi double [ %mydmvdt_tmp.i.sroa.0.1.i, %", in inner loop at depth 1, bb28.i" ], [ %r53.i22374.i, %", bb3.i61.i22310.i" ]
  %mymv_tmp2.sroa.0.4.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb28.i" ], [ %mymv_tmp2.sroa.18.7.i, %", bb3.i61.i22310.i" ]
  %mygamma_m.i22184.4.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb28.i" ], [ %mygamma_m.i22184.5.i, %", bb3.i61.i22310.i" ]
  %myr_m.i22183.4.i = phi double [ %myr_m.i22183.1.i, %", in inner loop at depth 1, bb28.i" ], [ 0.000000e+00, %", bb3.i61.i22310.i" ]
  %r90.i3161.i.i = fmul double 0.000000e+00, %r119.i2309.i12124.i
  %25 = fcmp ogt double %r90.i3161.i.i, 0.000000e+00
  %26 = select i1 %25, double 0x7FF0000000000000, double 0.000000e+00
  %r94.i3165.i.i = insertelement <2 x double> zeroinitializer, double 0.000000e+00, i64 0
  %27 = bitcast <2 x double> zeroinitializer to <2 x i64>
  %r106.i3177.i.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %26, double 0.000000e+00)
  %r110.i3181.i.i = fmul double 0.000000e+00, %r106.i3177.i.i
  %r111.i3182.i.i = fdiv double 0.000000e+00, %r110.i3181.i.i
  %r186.i4081.i = fadd double %myr_tmp2.sroa.110.5.i, 0.000000e+00
  %r210.i4107.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r111.i3182.i.i, double %myv_tmp2.sroa.96.5.i)
  %r230.i4127.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %mydpbdt_tmp.i.sroa.0.0.i, double %mypb_tmp2.sroa.54.2.i)
  %r245.i4141.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %mydmvdt_tmp.i.sroa.0.4.i, double 0.000000e+00)
  %r55.i.i21810.i = fmul double %r245.i4141.i, 0.000000e+00
  %r56.i.i21811.i = tail call double @llvm.fma.f64(double 0.000000e+00, double 0.000000e+00, double %r55.i.i21810.i)
  %r62.i102.i21909.i = fmul double %r230.i4127.i, 0.000000e+00
  %r66.i106.i21912.i = fdiv double %r62.i102.i21909.i, %r56.i.i21811.i
  %28 = fneg double %r66.i106.i21912.i
  %r70.i109.i21916.i = fmul double 0.000000e+00, %28
  %r71.i110.i21917.i = fmul double 0.000000e+00, %r70.i109.i21916.i
  %r73.i.i21919.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r71.i110.i21917.i, double 0.000000e+00)
  %r75.i112.i21921.i = fmul double 0.000000e+00, %r73.i.i21919.i
  %r76.i113.i21922.i = fmul double 0.000000e+00, %r75.i112.i21921.i
  %r134.i1232.i.i = fdiv double 0.000000e+00, %r1778
  %r143.i1241.i.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r139.i1493.i11983.i, double 0.000000e+00)
  %29 = tail call noundef double @llvm.sqrt.f64(double %r143.i1241.i.i)
  %r38.i2072.i.i = load double, ptr addrspace(1) null, align 8
  %r41.i2075.i.i = load double, ptr %r2698, align 8
  %r42.i2076.i.i = fsub double %r38.i2072.i.i, %r41.i2075.i.i
  %r162.i2560.i.i = fmul double %r210.i4107.i, 0.000000e+00
  %r165.i2563.i.i = fmul double %r186.i4081.i, 0.000000e+00
  %r166.i2564.i.i = fdiv double %r162.i2560.i.i, %r165.i2563.i.i
  %r167.i2565.i.i = fadd double %r76.i113.i21922.i, %r166.i2564.i.i
  %30 = fmul double %r42.i2076.i.i, 0.000000e+00
  %r207.i2605.i.i = fmul double %30, 0.000000e+00
  %r208.i2606.i.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r167.i2565.i.i, double %r207.i2605.i.i)
  %r17.i3207.i.i = fdiv double 0.000000e+00, 0.000000e+00
  %r18.i3208.i.i = fadd double %r17.i3207.i.i, 0.000000e+00
  %r22.i3212.i.i = fdiv double 0.000000e+00, %29
  %r48.i3238.i.i = fmul double 0.000000e+00, %r208.i2606.i.i
  %r56.i3246.i.i = tail call double @llvm.fma.f64(double %r22.i3212.i.i, double %r48.i3238.i.i, double 0.000000e+00)
  %r57.i3247.i.i = tail call double @llvm.fma.f64(double %r134.i1232.i.i, double 0.000000e+00, double %r56.i3246.i.i)
  %r59.i3249.i.i = fmul double %r22.i3212.i.i, 0.000000e+00
  %r61.i3251.i.i = fmul double %r59.i3249.i.i, 0.000000e+00
  %r63.i3253.i.i = fdiv double %r61.i3251.i.i, %r186.i4081.i
  %r72.i3262.i.i = insertelement <2 x double> zeroinitializer, double %r18.i3208.i.i, i64 0
  %31 = bitcast <2 x double> %r72.i3262.i.i to <2 x i64>
  %32 = and <2 x i64> %3, %31
  %r101.i3291.i.i = bitcast <2 x i64> %32 to <2 x double>
  %r102.i3292.i.i = extractelement <2 x double> %r101.i3291.i.i, i64 0
  %r106.i3296.i.i = tail call double @llvm.fma.f64(double %r63.i3253.i.i, double %r102.i3292.i.i, double 0.000000e+00)
  %r110.i3300.i.i = fmul double 0.000000e+00, %r106.i3296.i.i
  %r111.i3301.i.i = fdiv double %r57.i3247.i.i, %r110.i3300.i.i
  %r368.i.i = fadd double 0.000000e+00, %r111.i3301.i.i
  %r370.i.i = tail call double @llvm.fma.f64(double 0.000000e+00, double %r368.i.i, double 0.000000e+00)
  %r513.i.i = tail call double @llvm.fma.f64(double %r370.i.i, double 0.000000e+00, double 0.000000e+00)
  %r514.i.i = fadd double %r210.i4107.i, %r513.i.i
  %r515.i.i = fmul double 0.000000e+00, %r514.i.i
  %r520.i.i = fadd double %myr_tmp2.sroa.110.5.i, %r515.i.i
  %r680.i = fcmp ugt double 0.000000e+00, %r533.i13693.i
  br i1 %r680.i, label %", in inner loop at depth 1, bb106.i", label %", in inner loop at depth 1, bb32.i"

", in inner loop at depth 1, bb32.i":             ; preds = %"l$00066.i.i"
  %r1157.i = load double, ptr addrspace(1) null, align 8
  %r1164.i = fdiv double %r1157.i, %err.sroa.0.0.i
  %r1183.i = tail call double @llvm.fabs.f64(double %r1164.i)
  %33 = tail call { double, i32 } @llvm.frexp.f64.i32(double %r1183.i)
  %34 = extractvalue { double, i32 } %33, 0
  %35 = fmul double %34, 0.000000e+00
  %36 = fadd double %35, 0.000000e+00
  %37 = fmul double 0.000000e+00, %36
  %38 = fadd double 0.000000e+00, %37
  %39 = fmul double 0.000000e+00, %38
  %40 = tail call double @llvm.fma.f64(double %39, double 0.000000e+00, double 0x3FCC71C016291751)
  %41 = tail call double @llvm.fma.f64(double 0.000000e+00, double %40, double 0x3FD249249B27ACF1)
  %42 = tail call double @llvm.fma.f64(double 0.000000e+00, double %41, double 0x3FD99999998EF7B6)
  %43 = tail call double @llvm.fma.f64(double 0.000000e+00, double %42, double 0x3FE5555555555780)
  %44 = fmul double 0.000000e+00, %43
  %45 = fadd double 0.000000e+00, %44
  %46 = fsub double 0.000000e+00, %45
  %47 = fsub double 0.000000e+00, %46
  %48 = fcmp oeq double %r1164.i, 0.000000e+00
  %49 = fmul double %47, 0.000000e+00
  %r1186.i = select i1 %48, double 0xFFF0000000000000, double %49
  %50 = tail call double @llvm.fma.f64(double 0.000000e+00, double 0x3FE62E42FEFA39EF, double %r1186.i)
  %51 = tail call double @llvm.fma.f64(double 0.000000e+00, double 0x3C7ABC9E3B39803F, double %50)
  %52 = tail call double @llvm.fma.f64(double %51, double 0.000000e+00, double 0x3E928AF3FCA7AB0C)
  %53 = tail call double @llvm.fma.f64(double 0.000000e+00, double %52, double 0x3EC71DEE623FDE64)
  %54 = tail call double @llvm.fma.f64(double 0.000000e+00, double %53, double 0x3EFA01997C89E6B0)
  %55 = tail call double @llvm.fma.f64(double 0.000000e+00, double %54, double 0x3F2A01A014761F6E)
  %56 = tail call double @llvm.fma.f64(double 0.000000e+00, double %55, double 0x3F56C16C1852B7B0)
  %57 = tail call double @llvm.fma.f64(double 0.000000e+00, double %56, double 0x3F81111111122322)
  %58 = tail call double @llvm.fma.f64(double 0.000000e+00, double %57, double 0x3FA55555555502A1)
  %59 = tail call double @llvm.fma.f64(double 0.000000e+00, double %58, double 0x3FC5555555555511)
  %60 = tail call double @llvm.fma.f64(double 0.000000e+00, double %59, double 0x3FE000000000000B)
  %61 = tail call double @llvm.fma.f64(double 0.000000e+00, double %60, double 0.000000e+00)
  %62 = tail call double @llvm.fma.f64(double 0.000000e+00, double %61, double 0.000000e+00)
  %r1205.i = fmul double %h.1.i, %62
  br label %"1967ubot1.i"

", in inner loop at depth 1, bb106.i":            ; preds = %"l$00066.i.i", %", in inner loop at depth 1, bb26.i", %", in inner loop at depth 1, bb21.i"
  %mydmvdt_tmp.i.sroa.0.2.i = phi double [ %mydmvdt_tmp.i.sroa.0.1.i, %", in inner loop at depth 1, bb21.i" ], [ %mydmvdt_tmp.i.sroa.0.1.i, %", in inner loop at depth 1, bb26.i" ], [ 0.000000e+00, %"l$00066.i.i" ]
  %myr_tmp2.sroa.110.2.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb21.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb26.i" ], [ %r520.i.i, %"l$00066.i.i" ]
  %mymv_tmp2.sroa.0.2.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb21.i" ], [ %mymv_tmp2.sroa.0.1.i, %", in inner loop at depth 1, bb26.i" ], [ 0.000000e+00, %"l$00066.i.i" ]
  %h.2.i = phi double [ %r496.i, %", in inner loop at depth 1, bb21.i" ], [ %r580.i, %", in inner loop at depth 1, bb26.i" ], [ %r500.i, %"l$00066.i.i" ]
  %mygamma_m.i22184.2.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb21.i" ], [ %mygamma_m.i22184.1.i, %", in inner loop at depth 1, bb26.i" ], [ 0.000000e+00, %"l$00066.i.i" ]
  %myr_m.i22183.2.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb21.i" ], [ %myr_m.i22183.1.i, %", in inner loop at depth 1, bb26.i" ], [ 0.000000e+00, %"l$00066.i.i" ]
  %r1226.i = icmp slt i32 0, %r414.i
  br i1 %r1226.i, label %"1967utop1.i", label %"1967ubot1.i"

"1967ubot1.i":                                    ; preds = %", in inner loop at depth 1, bb106.i", %", in inner loop at depth 1, bb32.i", %"1961utop1.i"
  %"$$_myv_t120.1" = phi double [ %myv_tmp1.sroa.48.3.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %"$$_myr_t121.1" = phi double [ %myr_tmp1.sroa.55.3.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mydmvdt_tmp.i4985.sroa.6.3.i = phi double [ %mydmvdt_tmp.i4985.sroa.6.5.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mydmvdt_tmp.i4985.sroa.0.3.i = phi double [ %mydmvdt_tmp.i4985.sroa.0.1.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mydmvdt_tmp.i.sroa.0.3.i = phi double [ %mydmvdt_tmp.i.sroa.0.4.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mygamma_m.i19984.3.i = phi double [ %mygamma_m.i19984.5.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %myv_tmp2.sroa.96.3.i = phi double [ %myv_tmp2.sroa.96.5.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %myv_tmp1.sroa.48.2.i = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ %myv_tmp1.sroa.48.3.i, %", in inner loop at depth 1, bb106.i" ]
  %mymv_tmp2.sroa.18.3.i = phi double [ %mymv_tmp2.sroa.18.7.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mymv_tmp2.sroa.0.3.i = phi double [ %mymv_tmp2.sroa.0.4.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %h.3.i = phi double [ %r1205.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %mygamma_m.i22184.3.i = phi double [ %mygamma_m.i22184.4.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %myr_m.i22183.3.i = phi double [ %myr_m.i22183.4.i, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ 0.000000e+00, %", in inner loop at depth 1, bb106.i" ]
  %"$iter_count_s15.2.i" = phi i32 [ %r419.i, %", in inner loop at depth 1, bb32.i" ], [ 0, %"1961utop1.i" ], [ 0, %", in inner loop at depth 1, bb106.i" ]
  %"$t_new_s14.1.i" = phi double [ 0.000000e+00, %", in inner loop at depth 1, bb32.i" ], [ 0.000000e+00, %"1961utop1.i" ], [ %"$t_new_s14.0.i", %", in inner loop at depth 1, bb106.i" ]
  %r1267.i = fcmp une double %"$t_new_s14.1.i", 0.000000e+00
  %r1276.i = icmp slt i32 %"$iter_count_s15.2.i", 0
  %or.cond127 = select i1 %r1267.i, i1 %r1276.i, i1 false
  br i1 %or.cond127, label %"1961utop1.i", label %"f_advance_step$m_bubbles_.exit"

"f_advance_step$m_bubbles_.exit":                 ; preds = %"1967ubot1.i"
  %r2639 = load i64, ptr addrspace(1) inttoptr (i64 -56 to ptr addrspace(1)), align 8
  %r2649 = load i64, ptr addrspace(1) inttoptr (i64 -72 to ptr addrspace(1)), align 8
  %r2650 = sub i64 %"$$induc_p203_t282.0", %r2649
  %r2651 = mul i64 %r2639, %r2650
  %r2661 = load i64, ptr addrspace(1) inttoptr (i64 -8 to ptr addrspace(1)), align 8
  %r2671 = load i64, ptr addrspace(1) inttoptr (i64 -24 to ptr addrspace(1)), align 8
  %r2672 = sub i64 %r426, %r2671
  %r2673 = mul i64 %r2661, %r2672
  %63 = getelementptr double, ptr null, i64 %r2651
  %r2676 = getelementptr double, ptr %63, i64 %r2673
  store double 0.000000e+00, ptr %r2676, align 8
  br label %"file ../../../lustre/orion/cfd154/scratch/sbryngelson/wt-cce21/src/simulation/m_bubbles_EE.fpp, line 290, in loop at depth 1, bb145"

", in loop at depth 1, bb143":                    ; preds = %"f_bpres_dot$m_bubbles_.exit"
  %r.i = load i32, ptr addrspace(1) null, align 32
  %cond = icmp eq i32 0, 0
  br i1 %cond, label %", bb9.i", label %"f_rddot$m_bubbles_.exit"

", bb9.i":                                        ; preds = %", in loop at depth 1, bb143"
  %r213.i = fadd double %r1863, %r1781
  %r214.i = fmul double 0.000000e+00, %r213.i
  %r221.i = fsub double 0.000000e+00, %r1944
  %r222.i = fmul double 0.000000e+00, %r221.i
  %r223.i = fdiv double %r214.i, %r222.i
  %64 = tail call noundef double @llvm.sqrt.f64(double %r223.i)
  %r229.i.i = fdiv double %r2127, %64
  %r279.i.i = fsub double 0.000000e+00, %r229.i.i
  %r280.i.i = fmul double 0.000000e+00, %r279.i.i
  %r294.i.i = tail call double @llvm.fma.f64(double 0.000000e+00, double 0.000000e+00, double %r280.i.i)
  %"$f_rddot_km_s13.i.0.i" = fdiv double 0.000000e+00, %r294.i.i
  br label %"f_rddot$m_bubbles_.exit"

"f_rddot$m_bubbles_.exit":                        ; preds = %", bb9.i", %", in loop at depth 1, bb143"
  %"$f_rddot_s3.0.i" = phi double [ %"$f_rddot_km_s13.i.0.i", %", bb9.i" ], [ 0.000000e+00, %", in loop at depth 1, bb143" ]
  %r2703 = fmul double 0.000000e+00, %"$f_rddot_s3.0.i"
  %r2704 = load ptr addrspace(1), ptr addrspace(1) null, align 32
  store double %r2703, ptr addrspace(1) %r2704, align 8
  br label %"file ../../../lustre/orion/cfd154/scratch/sbryngelson/wt-cce21/src/simulation/m_bubbles_EE.fpp, line 290, in loop at depth 1, bb145"

"file ../../../lustre/orion/cfd154/scratch/sbryngelson/wt-cce21/src/simulation/m_bubbles_EE.fpp, line 290, in loop at depth 1, bb145": ; preds = %"f_rddot$m_bubbles_.exit", %"f_advance_step$m_bubbles_.exit"
  br label %"1787utop1"
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #3

attributes #0 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite) }
attributes #2 = { nofree noinline norecurse nounwind "amdgpu-agpr-alloc"="0" "amdgpu-flat-work-group-size"="1,256" "amdgpu-no-completion-action" "amdgpu-no-default-queue" "amdgpu-no-dispatch-id" "amdgpu-no-dispatch-ptr" "amdgpu-no-flat-scratch-init" "amdgpu-no-heap-ptr" "amdgpu-no-hostcall-ptr" "amdgpu-no-lds-kernel-id" "amdgpu-no-multigrid-sync-arg" "amdgpu-no-queue-ptr" "amdgpu-no-workgroup-id-x" "amdgpu-no-workgroup-id-y" "amdgpu-no-workgroup-id-z" "amdgpu-no-workitem-id-x" "amdgpu-no-workitem-id-y" "amdgpu-no-workitem-id-z" "kernel" "target-cpu"="gfx90a" "uniform-work-group-size"="true" }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
