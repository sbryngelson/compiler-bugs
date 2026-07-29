; ModuleID = '_c.bc'
source_filename = "dm_min.c"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

@__omp_rtl_debug_kind = weak_odr hidden addrspace(1) constant i32 0
@__omp_rtl_assume_teams_oversubscription = weak_odr hidden addrspace(1) constant i32 0
@__omp_rtl_assume_threads_oversubscription = weak_odr hidden addrspace(1) constant i32 0
@__omp_rtl_assume_no_thread_state = weak_odr hidden addrspace(1) constant i32 0
@__omp_rtl_assume_no_nested_parallelism = weak_odr hidden addrspace(1) constant i32 0
@__omp_offloading_8116438_fc00c07e_main_l11_exec_mode = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc00c07e_main_l11_cray$kerninfo_onelevel" = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc00c07e_main_l11_cray$kerninfo_onelevel_comb" = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc00c07e_main_l11_cray$kerninfo_has_noloop_version" = weak addrspace(1) constant i8 0
@__omp_offloading_8116438_fc00c07e_main_l16_exec_mode = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc00c07e_main_l16_cray$kerninfo_onelevel" = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc00c07e_main_l16_cray$kerninfo_onelevel_comb" = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc00c07e_main_l16_cray$kerninfo_has_noloop_version" = weak addrspace(1) constant i8 0
@llvm.used = appending addrspace(1) global [8 x ptr] [ptr addrspacecast (ptr addrspace(1) @__omp_offloading_8116438_fc00c07e_main_l11_exec_mode to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc00c07e_main_l11_cray$kerninfo_onelevel" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc00c07e_main_l11_cray$kerninfo_onelevel_comb" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc00c07e_main_l11_cray$kerninfo_has_noloop_version" to ptr), ptr addrspacecast (ptr addrspace(1) @__omp_offloading_8116438_fc00c07e_main_l16_exec_mode to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc00c07e_main_l16_cray$kerninfo_onelevel" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc00c07e_main_l16_cray$kerninfo_onelevel_comb" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc00c07e_main_l16_cray$kerninfo_has_noloop_version" to ptr)], section "llvm.metadata"
@__oclc_ABI_version = external local_unnamed_addr addrspace(4) global i32

; Function Attrs: convergent noinline norecurse nounwind optnone
define weak_odr protected amdgpu_kernel void @__omp_offloading_8116438_fc00c07e_main_l11(ptr noalias noundef %dyn_ptr, i64 noundef %n, ptr noundef %a, ptr noundef nonnull align 4 dereferenceable(4) %d1) #0 !dbg !16 {
entry:
  %.global_tid..addr.i1 = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i2 = alloca ptr, align 8, addrspace(5)
  %.previous.lb..addr.i = alloca i64, align 8, addrspace(5)
  %.previous.ub..addr.i = alloca i64, align 8, addrspace(5)
  %n.addr.i3 = alloca i64, align 8, addrspace(5)
  %a.addr.i4 = alloca ptr, align 8, addrspace(5)
  %d1.addr.i5 = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i6 = alloca i32, align 4, addrspace(5)
  %tmp.i7 = alloca i32, align 4, addrspace(5)
  %.capture_expr..i8 = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i9 = alloca i32, align 4, addrspace(5)
  %i.i10 = alloca i32, align 4, addrspace(5)
  %.omp.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i11 = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i12 = alloca i32, align 4, addrspace(5)
  %i4.i = alloca i32, align 4, addrspace(5)
  %fork_tid.i = alloca i32, align 4, addrspace(5)
  %.global_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %n.addr.i = alloca i64, align 8, addrspace(5)
  %a.addr.i = alloca ptr, align 8, addrspace(5)
  %d1.addr.i = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i = alloca i32, align 4, addrspace(5)
  %tmp.i = alloca i32, align 4, addrspace(5)
  %.capture_expr..i = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i = alloca i32, align 4, addrspace(5)
  %i.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i = alloca i32, align 4, addrspace(5)
  %i3.i = alloca i32, align 4, addrspace(5)
  %n.casted.i = alloca i64, align 8, addrspace(5)
  %fork_tid = alloca i32, align 4, addrspace(5)
  %dyn_ptr.addr = alloca ptr, align 8, addrspace(5)
  %n.addr = alloca i64, align 8, addrspace(5)
  %a.addr = alloca ptr, align 8, addrspace(5)
  %d1.addr = alloca ptr, align 8, addrspace(5)
  %n.casted = alloca i64, align 8, addrspace(5)
  %dyn_ptr.addr.ascast = addrspacecast ptr addrspace(5) %dyn_ptr.addr to ptr
  %n.addr.ascast = addrspacecast ptr addrspace(5) %n.addr to ptr
  %a.addr.ascast = addrspacecast ptr addrspace(5) %a.addr to ptr
  %d1.addr.ascast = addrspacecast ptr addrspace(5) %d1.addr to ptr
  %n.casted.ascast = addrspacecast ptr addrspace(5) %n.casted to ptr
  store ptr %dyn_ptr, ptr %dyn_ptr.addr.ascast, align 8
  store i64 %n, ptr %n.addr.ascast, align 8
  store ptr %a, ptr %a.addr.ascast, align 8
  store ptr %d1, ptr %d1.addr.ascast, align 8
  %0 = load ptr, ptr %d1.addr.ascast, align 8, !dbg !19, !nonnull !18, !align !20
  %1 = load i32, ptr %n.addr.ascast, align 4, !dbg !19
  store i32 %1, ptr %n.casted.ascast, align 4, !dbg !19
  %2 = load i64, ptr %n.casted.ascast, align 8, !dbg !19
  %3 = load ptr, ptr %a.addr.ascast, align 8, !dbg !19
  store i32 0, ptr addrspace(5) %fork_tid, align 4, !dbg !19
  %4 = addrspacecast ptr addrspace(5) %fork_tid to ptr, !dbg !19
  call void @llvm.experimental.noalias.scope.decl(metadata !21), !dbg !19
  call void @llvm.experimental.noalias.scope.decl(metadata !24), !dbg !19
  %.global_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.global_tid..addr.i to ptr
  %.bound_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.bound_tid..addr.i to ptr
  %n.addr.ascast.i = addrspacecast ptr addrspace(5) %n.addr.i to ptr
  %a.addr.ascast.i = addrspacecast ptr addrspace(5) %a.addr.i to ptr
  %d1.addr.ascast.i = addrspacecast ptr addrspace(5) %d1.addr.i to ptr
  %.omp.iv.ascast.i = addrspacecast ptr addrspace(5) %.omp.iv.i to ptr
  %tmp.ascast.i = addrspacecast ptr addrspace(5) %tmp.i to ptr
  %.capture_expr..ascast.i = addrspacecast ptr addrspace(5) %.capture_expr..i to ptr
  %.capture_expr.1.ascast.i = addrspacecast ptr addrspace(5) %.capture_expr.1.i to ptr
  %i.ascast.i = addrspacecast ptr addrspace(5) %i.i to ptr
  %.omp.comb.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.lb.i to ptr
  %.omp.comb.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.ub.i to ptr
  %.omp.stride.ascast.i = addrspacecast ptr addrspace(5) %.omp.stride.i to ptr
  %.omp.is_last.ascast.i = addrspacecast ptr addrspace(5) %.omp.is_last.i to ptr
  %i3.ascast.i = addrspacecast ptr addrspace(5) %i3.i to ptr
  %n.casted.ascast.i = addrspacecast ptr addrspace(5) %n.casted.i to ptr
  store ptr %4, ptr %.global_tid..addr.ascast.i, align 8, !noalias !26
  store ptr %4, ptr %.bound_tid..addr.ascast.i, align 8, !noalias !26
  store i64 %2, ptr %n.addr.ascast.i, align 8, !noalias !26
  store ptr %3, ptr %a.addr.ascast.i, align 8, !noalias !26
  store ptr %0, ptr %d1.addr.ascast.i, align 8, !noalias !26
  %5 = load ptr, ptr %d1.addr.ascast.i, align 8, !dbg !27, !noalias !26, !nonnull !18, !align !20
  %6 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !30, !noalias !26
  store i32 %6, ptr %.capture_expr..ascast.i, align 4, !dbg !30, !noalias !26
  %7 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !30, !noalias !26
  %sub2.i = sub nsw i32 %7, 1, !dbg !31
  store i32 %sub2.i, ptr %.capture_expr.1.ascast.i, align 4, !dbg !31, !noalias !26
  store i32 0, ptr %i.ascast.i, align 4, !dbg !32, !noalias !26
  %8 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !30, !noalias !26
  %cmp.i = icmp slt i32 0, %8, !dbg !31
  br i1 %cmp.i, label %omp.precond.then.i, label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.exit, !dbg !27

omp.precond.then.i:                               ; preds = %entry
  store i32 0, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !33, !noalias !26
  %9 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !31, !noalias !26
  store i32 %9, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !33, !noalias !26
  store i32 1, ptr %.omp.stride.ascast.i, align 4, !dbg !33, !noalias !26
  store i32 0, ptr %.omp.is_last.ascast.i, align 4, !dbg !33, !noalias !26
  %10 = call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !27
  %11 = load i32, ptr addrspace(4) @__oclc_ABI_version, align 4, !dbg !27
  %12 = icmp sgt i32 %11, 499, !dbg !27
  %13 = call align 8 dereferenceable(256) ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr(), !dbg !27
  %14 = getelementptr inbounds nuw i8, ptr addrspace(4) %13, i64 12, !dbg !27
  %15 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !27
  %16 = getelementptr inbounds nuw i8, ptr addrspace(4) %15, i64 4, !dbg !27
  %17 = select i1 %12, ptr addrspace(4) %14, ptr addrspace(4) %16, !dbg !27
  %18 = load i16, ptr addrspace(4) %17, align 4, !dbg !27, !range !34, !invariant.load !18, !noundef !18
  %conv.i31 = zext nneg i16 %18 to i32, !dbg !27
  %mul.i = mul i32 %10, %conv.i31, !dbg !27
  %19 = call i32 @llvm.amdgcn.workitem.id.x(), !dbg !27
  %add.i32 = add i32 %mul.i, %19, !dbg !27
  %conv1.i = zext i32 %add.i32 to i64, !dbg !27
  %20 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !27
  %21 = getelementptr inbounds nuw i8, ptr addrspace(4) %20, i64 12, !dbg !27
  %22 = load i32, ptr addrspace(4) %21, align 4, !dbg !27, !range !35, !invariant.load !18
  %conv.i30 = zext i32 %22 to i64, !dbg !27
  %23 = trunc i64 %conv1.i to i32, !dbg !27
  %24 = trunc i64 %conv.i30 to i32, !dbg !27
  %25 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !27, !noalias !26
  %26 = add i32 %25, %23, !dbg !27
  store i32 %26, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !27, !noalias !26
  store i32 %26, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !27, !noalias !26
  store i32 %24, ptr %.omp.stride.ascast.i, align 4, !dbg !27, !noalias !26
  br label %omp.dispatch.cond.i, !dbg !27

omp.dispatch.cond.i:                              ; preds = %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.exit, %omp.precond.then.i
  %27 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %28 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !31, !noalias !26, !cray.depth !36
  %cmp4.i = icmp sgt i32 %27, %28, !dbg !33, !cray.depth !36
  br i1 %cmp4.i, label %cond.true.i, label %cond.false.i, !dbg !33, !cray.depth !36

cond.true.i:                                      ; preds = %omp.dispatch.cond.i
  %29 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !31, !noalias !26, !cray.depth !36
  br label %cond.end.i, !dbg !33, !cray.depth !36

cond.false.i:                                     ; preds = %omp.dispatch.cond.i
  %30 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  br label %cond.end.i, !dbg !33, !cray.depth !36

cond.end.i:                                       ; preds = %cond.false.i, %cond.true.i
  %cond.i = phi i32 [ %29, %cond.true.i ], [ %30, %cond.false.i ], !dbg !33, !cray.depth !36
  store i32 %cond.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %31 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  store i32 %31, ptr %.omp.iv.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %32 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %33 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %cmp5.i = icmp sle i32 %32, %33, !dbg !31, !cray.depth !36
  br i1 %cmp5.i, label %omp.dispatch.body.i, label %omp.dispatch.end.i, !dbg !27, !cray.depth !36

omp.dispatch.body.i:                              ; preds = %cond.end.i
  %34 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !27, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %35 = zext i32 %34 to i64, !dbg !27, !cray.depth !38
  %36 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !27, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %37 = zext i32 %36 to i64, !dbg !27, !cray.depth !38
  %38 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !27, !noalias !26, !llvm.access.group !37, !cray.depth !38
  store i32 %38, ptr %n.casted.ascast.i, align 4, !dbg !27, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %39 = load i64, ptr %n.casted.ascast.i, align 8, !dbg !27, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %40 = load ptr, ptr %a.addr.ascast.i, align 8, !dbg !27, !noalias !26, !llvm.access.group !37, !cray.depth !38
  store i32 0, ptr addrspace(5) %fork_tid.i, align 4, !dbg !27, !noalias !26
  %41 = addrspacecast ptr addrspace(5) %fork_tid.i to ptr, !dbg !27
  call void @llvm.experimental.noalias.scope.decl(metadata !39), !dbg !27
  call void @llvm.experimental.noalias.scope.decl(metadata !42), !dbg !27
  %.global_tid..addr.ascast.i13 = addrspacecast ptr addrspace(5) %.global_tid..addr.i1 to ptr
  %.bound_tid..addr.ascast.i14 = addrspacecast ptr addrspace(5) %.bound_tid..addr.i2 to ptr
  %.previous.lb..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.lb..addr.i to ptr
  %.previous.ub..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.ub..addr.i to ptr
  %n.addr.ascast.i15 = addrspacecast ptr addrspace(5) %n.addr.i3 to ptr
  %a.addr.ascast.i16 = addrspacecast ptr addrspace(5) %a.addr.i4 to ptr
  %d1.addr.ascast.i17 = addrspacecast ptr addrspace(5) %d1.addr.i5 to ptr
  %.omp.iv.ascast.i18 = addrspacecast ptr addrspace(5) %.omp.iv.i6 to ptr
  %tmp.ascast.i19 = addrspacecast ptr addrspace(5) %tmp.i7 to ptr
  %.capture_expr..ascast.i20 = addrspacecast ptr addrspace(5) %.capture_expr..i8 to ptr
  %.capture_expr.1.ascast.i21 = addrspacecast ptr addrspace(5) %.capture_expr.1.i9 to ptr
  %i.ascast.i22 = addrspacecast ptr addrspace(5) %i.i10 to ptr
  %.omp.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.lb.i to ptr
  %.omp.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.ub.i to ptr
  %.omp.stride.ascast.i23 = addrspacecast ptr addrspace(5) %.omp.stride.i11 to ptr
  %.omp.is_last.ascast.i24 = addrspacecast ptr addrspace(5) %.omp.is_last.i12 to ptr
  %i4.ascast.i = addrspacecast ptr addrspace(5) %i4.i to ptr
  store ptr %41, ptr %.global_tid..addr.ascast.i13, align 8, !noalias !44
  store ptr %41, ptr %.bound_tid..addr.ascast.i14, align 8, !noalias !44
  store i64 %35, ptr %.previous.lb..addr.ascast.i, align 8, !noalias !44
  store i64 %37, ptr %.previous.ub..addr.ascast.i, align 8, !noalias !44
  store i64 %39, ptr %n.addr.ascast.i15, align 8, !noalias !44
  store ptr %40, ptr %a.addr.ascast.i16, align 8, !noalias !44
  store ptr %5, ptr %d1.addr.ascast.i17, align 8, !noalias !44
  %42 = load ptr, ptr %d1.addr.ascast.i17, align 8, !dbg !45, !noalias !44, !nonnull !18, !align !20
  %43 = load i32, ptr %n.addr.ascast.i15, align 4, !dbg !48, !noalias !44
  store i32 %43, ptr %.capture_expr..ascast.i20, align 4, !dbg !48, !noalias !44
  %44 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !48, !noalias !44
  %sub2.i25 = sub nsw i32 %44, 1, !dbg !49
  store i32 %sub2.i25, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !49, !noalias !44
  store i32 0, ptr %i.ascast.i22, align 4, !dbg !50, !noalias !44
  %45 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !48, !noalias !44
  %cmp.i26 = icmp slt i32 0, %45, !dbg !49
  br i1 %cmp.i26, label %omp.precond.then.i27, label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.exit, !dbg !45

omp.precond.then.i27:                             ; preds = %omp.dispatch.body.i
  store i32 0, ptr %.omp.lb.ascast.i, align 4, !dbg !51, !noalias !44
  %46 = load i32, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !49, !noalias !44
  store i32 %46, ptr %.omp.ub.ascast.i, align 4, !dbg !51, !noalias !44
  %47 = load i64, ptr %.previous.lb..addr.ascast.i, align 8, !dbg !45, !noalias !44
  %conv.i = trunc i64 %47 to i32, !dbg !45
  %48 = load i64, ptr %.previous.ub..addr.ascast.i, align 8, !dbg !45, !noalias !44
  %conv3.i = trunc i64 %48 to i32, !dbg !45
  store i32 %conv.i, ptr %.omp.lb.ascast.i, align 4, !dbg !45, !noalias !44
  store i32 %conv3.i, ptr %.omp.ub.ascast.i, align 4, !dbg !45, !noalias !44
  store i32 1, ptr %.omp.stride.ascast.i23, align 4, !dbg !51, !noalias !44
  store i32 0, ptr %.omp.is_last.ascast.i24, align 4, !dbg !51, !noalias !44
  %49 = load i32, ptr %.omp.lb.ascast.i, align 4, !dbg !51, !noalias !44
  store i32 %49, ptr %.omp.iv.ascast.i18, align 4, !dbg !51, !noalias !44
  %50 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !51, !noalias !44, !cray.depth !36
  store i32 %50, ptr %i4.ascast.i, align 4, !dbg !50, !noalias !44, !cray.depth !36
  %51 = load ptr, ptr %a.addr.ascast.i16, align 8, !dbg !52, !noalias !44, !cray.depth !36
  %52 = load i32, ptr %i4.ascast.i, align 4, !dbg !53, !noalias !44, !cray.depth !36
  %idxprom.i = sext i32 %52 to i64, !dbg !52, !cray.depth !36
  %arrayidx.i = getelementptr inbounds i32, ptr %51, i64 %idxprom.i, !dbg !52, !cray.depth !36
  %53 = load i32, ptr %arrayidx.i, align 4, !dbg !52, !cray.depth !36
  %tobool.i = icmp ne i32 %53, 0, !dbg !52, !cray.depth !36
  br i1 %tobool.i, label %if.then.i, label %if.end.i, !dbg !52, !cray.depth !36

if.then.i:                                        ; preds = %omp.precond.then.i27
  %54 = atomicrmw add ptr %42, i32 1 syncscope("agent") monotonic, align 4, !dbg !54, !amdgpu.no.fine.grained.memory !18, !amdgpu.no.remote.memory !18, !cray.depth !36
  br label %if.end.i, !dbg !55, !cray.depth !36

if.end.i:                                         ; preds = %if.then.i, %omp.precond.then.i27
  %55 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !51, !noalias !44, !cray.depth !36
  %56 = load i32, ptr %.omp.stride.ascast.i23, align 4, !dbg !51, !noalias !44, !cray.depth !36
  %add8.i29 = add nsw i32 %55, %56, !dbg !49, !cray.depth !36
  store i32 %add8.i29, ptr %.omp.iv.ascast.i18, align 4, !dbg !49, !noalias !44, !cray.depth !36
  br label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.exit, !dbg !45

__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.exit: ; preds = %omp.dispatch.body.i, %if.end.i
  %57 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !33, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %58 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !33, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %add.i = add nsw i32 %57, %58, !dbg !31, !cray.depth !38
  store i32 %add.i, ptr %.omp.iv.ascast.i, align 4, !dbg !31, !noalias !26, !llvm.access.group !37, !cray.depth !38
  %59 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %60 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %add7.i = add nsw i32 %59, %60, !dbg !31, !cray.depth !36
  store i32 %add7.i, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !31, !noalias !26, !cray.depth !36
  %61 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %62 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !33, !noalias !26, !cray.depth !36
  %add8.i = add nsw i32 %61, %62, !dbg !31, !cray.depth !36
  store i32 %add8.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !31, !noalias !26, !cray.depth !36
  br label %omp.dispatch.cond.i, !dbg !56

omp.dispatch.end.i:                               ; preds = %cond.end.i
  br label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.exit, !dbg !56

__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.exit: ; preds = %entry, %omp.dispatch.end.i
  ret void, !dbg !57
}

declare void @"__craygpu==>sched_dist_static_init_4"(i32, ptr, ptr, ptr, ptr, i32, i32)

declare i32 @"__craygpu==>inner_loop_need_top_test"()

declare i32 @"__craygpu==>inner_loop_branch"()

declare void @"__craygpu==>fork_parallel_dist_for___omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined"(ptr, i64, i64, i64, ptr, ptr)

declare i32 @"__craygpu==>outer_loop_branch"()

declare void @"__craygpu==>sched_dist_finish"()

declare void @"__craygpu==>fork_teams___omp_offloading_8116438_fc00c07e_main_l11_omp_outlined"(ptr, i64, ptr, ptr)

; Function Attrs: convergent noinline norecurse nounwind optnone
define weak_odr protected amdgpu_kernel void @__omp_offloading_8116438_fc00c07e_main_l16(ptr noalias noundef %dyn_ptr, i64 noundef %n, ptr noundef %a, ptr noundef nonnull align 4 dereferenceable(4) %d2) #0 !dbg !58 {
entry:
  %.global_tid..addr.i1 = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i2 = alloca ptr, align 8, addrspace(5)
  %.previous.lb..addr.i = alloca i64, align 8, addrspace(5)
  %.previous.ub..addr.i = alloca i64, align 8, addrspace(5)
  %n.addr.i3 = alloca i64, align 8, addrspace(5)
  %a.addr.i4 = alloca ptr, align 8, addrspace(5)
  %d2.addr.i5 = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i6 = alloca i32, align 4, addrspace(5)
  %tmp.i7 = alloca i32, align 4, addrspace(5)
  %.capture_expr..i8 = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i9 = alloca i32, align 4, addrspace(5)
  %i.i10 = alloca i32, align 4, addrspace(5)
  %.omp.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i11 = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i12 = alloca i32, align 4, addrspace(5)
  %i4.i = alloca i32, align 4, addrspace(5)
  %fork_tid.i = alloca i32, align 4, addrspace(5)
  %.global_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %n.addr.i = alloca i64, align 8, addrspace(5)
  %a.addr.i = alloca ptr, align 8, addrspace(5)
  %d2.addr.i = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i = alloca i32, align 4, addrspace(5)
  %tmp.i = alloca i32, align 4, addrspace(5)
  %.capture_expr..i = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i = alloca i32, align 4, addrspace(5)
  %i.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i = alloca i32, align 4, addrspace(5)
  %i3.i = alloca i32, align 4, addrspace(5)
  %n.casted.i = alloca i64, align 8, addrspace(5)
  %fork_tid = alloca i32, align 4, addrspace(5)
  %dyn_ptr.addr = alloca ptr, align 8, addrspace(5)
  %n.addr = alloca i64, align 8, addrspace(5)
  %a.addr = alloca ptr, align 8, addrspace(5)
  %d2.addr = alloca ptr, align 8, addrspace(5)
  %n.casted = alloca i64, align 8, addrspace(5)
  %dyn_ptr.addr.ascast = addrspacecast ptr addrspace(5) %dyn_ptr.addr to ptr
  %n.addr.ascast = addrspacecast ptr addrspace(5) %n.addr to ptr
  %a.addr.ascast = addrspacecast ptr addrspace(5) %a.addr to ptr
  %d2.addr.ascast = addrspacecast ptr addrspace(5) %d2.addr to ptr
  %n.casted.ascast = addrspacecast ptr addrspace(5) %n.casted to ptr
  store ptr %dyn_ptr, ptr %dyn_ptr.addr.ascast, align 8
  store i64 %n, ptr %n.addr.ascast, align 8
  store ptr %a, ptr %a.addr.ascast, align 8
  store ptr %d2, ptr %d2.addr.ascast, align 8
  %0 = load ptr, ptr %d2.addr.ascast, align 8, !dbg !59, !nonnull !18, !align !20
  %1 = load i32, ptr %n.addr.ascast, align 4, !dbg !59
  store i32 %1, ptr %n.casted.ascast, align 4, !dbg !59
  %2 = load i64, ptr %n.casted.ascast, align 8, !dbg !59
  %3 = load ptr, ptr %a.addr.ascast, align 8, !dbg !59
  store i32 0, ptr addrspace(5) %fork_tid, align 4, !dbg !59
  %4 = addrspacecast ptr addrspace(5) %fork_tid to ptr, !dbg !59
  call void @llvm.experimental.noalias.scope.decl(metadata !60), !dbg !59
  call void @llvm.experimental.noalias.scope.decl(metadata !63), !dbg !59
  %.global_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.global_tid..addr.i to ptr
  %.bound_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.bound_tid..addr.i to ptr
  %n.addr.ascast.i = addrspacecast ptr addrspace(5) %n.addr.i to ptr
  %a.addr.ascast.i = addrspacecast ptr addrspace(5) %a.addr.i to ptr
  %d2.addr.ascast.i = addrspacecast ptr addrspace(5) %d2.addr.i to ptr
  %.omp.iv.ascast.i = addrspacecast ptr addrspace(5) %.omp.iv.i to ptr
  %tmp.ascast.i = addrspacecast ptr addrspace(5) %tmp.i to ptr
  %.capture_expr..ascast.i = addrspacecast ptr addrspace(5) %.capture_expr..i to ptr
  %.capture_expr.1.ascast.i = addrspacecast ptr addrspace(5) %.capture_expr.1.i to ptr
  %i.ascast.i = addrspacecast ptr addrspace(5) %i.i to ptr
  %.omp.comb.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.lb.i to ptr
  %.omp.comb.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.ub.i to ptr
  %.omp.stride.ascast.i = addrspacecast ptr addrspace(5) %.omp.stride.i to ptr
  %.omp.is_last.ascast.i = addrspacecast ptr addrspace(5) %.omp.is_last.i to ptr
  %i3.ascast.i = addrspacecast ptr addrspace(5) %i3.i to ptr
  %n.casted.ascast.i = addrspacecast ptr addrspace(5) %n.casted.i to ptr
  store ptr %4, ptr %.global_tid..addr.ascast.i, align 8, !noalias !65
  store ptr %4, ptr %.bound_tid..addr.ascast.i, align 8, !noalias !65
  store i64 %2, ptr %n.addr.ascast.i, align 8, !noalias !65
  store ptr %3, ptr %a.addr.ascast.i, align 8, !noalias !65
  store ptr %0, ptr %d2.addr.ascast.i, align 8, !noalias !65
  %5 = load ptr, ptr %d2.addr.ascast.i, align 8, !dbg !66, !noalias !65, !nonnull !18, !align !20
  %6 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !69, !noalias !65
  store i32 %6, ptr %.capture_expr..ascast.i, align 4, !dbg !69, !noalias !65
  %7 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !69, !noalias !65
  %sub2.i = sub nsw i32 %7, 1, !dbg !70
  store i32 %sub2.i, ptr %.capture_expr.1.ascast.i, align 4, !dbg !70, !noalias !65
  store i32 0, ptr %i.ascast.i, align 4, !dbg !71, !noalias !65
  %8 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !69, !noalias !65
  %cmp.i = icmp slt i32 0, %8, !dbg !70
  br i1 %cmp.i, label %omp.precond.then.i, label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.exit, !dbg !66

omp.precond.then.i:                               ; preds = %entry
  store i32 0, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !72, !noalias !65
  %9 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !70, !noalias !65
  store i32 %9, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !72, !noalias !65
  store i32 1, ptr %.omp.stride.ascast.i, align 4, !dbg !72, !noalias !65
  store i32 0, ptr %.omp.is_last.ascast.i, align 4, !dbg !72, !noalias !65
  %10 = call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !66
  %11 = load i32, ptr addrspace(4) @__oclc_ABI_version, align 4, !dbg !66
  %12 = icmp sgt i32 %11, 499, !dbg !66
  %13 = call align 8 dereferenceable(256) ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr(), !dbg !66
  %14 = getelementptr inbounds nuw i8, ptr addrspace(4) %13, i64 12, !dbg !66
  %15 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !66
  %16 = getelementptr inbounds nuw i8, ptr addrspace(4) %15, i64 4, !dbg !66
  %17 = select i1 %12, ptr addrspace(4) %14, ptr addrspace(4) %16, !dbg !66
  %18 = load i16, ptr addrspace(4) %17, align 4, !dbg !66, !range !34, !invariant.load !18, !noundef !18
  %conv.i31 = zext nneg i16 %18 to i32, !dbg !66
  %mul.i = mul i32 %10, %conv.i31, !dbg !66
  %19 = call i32 @llvm.amdgcn.workitem.id.x(), !dbg !66
  %add.i32 = add i32 %mul.i, %19, !dbg !66
  %conv1.i = zext i32 %add.i32 to i64, !dbg !66
  %20 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !66
  %21 = getelementptr inbounds nuw i8, ptr addrspace(4) %20, i64 12, !dbg !66
  %22 = load i32, ptr addrspace(4) %21, align 4, !dbg !66, !range !35, !invariant.load !18
  %conv.i30 = zext i32 %22 to i64, !dbg !66
  %23 = trunc i64 %conv1.i to i32, !dbg !66
  %24 = trunc i64 %conv.i30 to i32, !dbg !66
  %25 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !66, !noalias !65
  %26 = add i32 %25, %23, !dbg !66
  store i32 %26, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !66, !noalias !65
  store i32 %26, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !66, !noalias !65
  store i32 %24, ptr %.omp.stride.ascast.i, align 4, !dbg !66, !noalias !65
  br label %omp.dispatch.cond.i, !dbg !66

omp.dispatch.cond.i:                              ; preds = %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.exit, %omp.precond.then.i
  %27 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %28 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !70, !noalias !65, !cray.depth !36
  %cmp4.i = icmp sgt i32 %27, %28, !dbg !72, !cray.depth !36
  br i1 %cmp4.i, label %cond.true.i, label %cond.false.i, !dbg !72, !cray.depth !36

cond.true.i:                                      ; preds = %omp.dispatch.cond.i
  %29 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !70, !noalias !65, !cray.depth !36
  br label %cond.end.i, !dbg !72, !cray.depth !36

cond.false.i:                                     ; preds = %omp.dispatch.cond.i
  %30 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  br label %cond.end.i, !dbg !72, !cray.depth !36

cond.end.i:                                       ; preds = %cond.false.i, %cond.true.i
  %cond.i = phi i32 [ %29, %cond.true.i ], [ %30, %cond.false.i ], !dbg !72, !cray.depth !36
  store i32 %cond.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %31 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  store i32 %31, ptr %.omp.iv.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %32 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %33 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %cmp5.i = icmp sle i32 %32, %33, !dbg !70, !cray.depth !36
  br i1 %cmp5.i, label %omp.dispatch.body.i, label %omp.dispatch.end.i, !dbg !66, !cray.depth !36

omp.dispatch.body.i:                              ; preds = %cond.end.i
  %34 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !66, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %35 = zext i32 %34 to i64, !dbg !66, !cray.depth !38
  %36 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !66, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %37 = zext i32 %36 to i64, !dbg !66, !cray.depth !38
  %38 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !66, !noalias !65, !llvm.access.group !73, !cray.depth !38
  store i32 %38, ptr %n.casted.ascast.i, align 4, !dbg !66, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %39 = load i64, ptr %n.casted.ascast.i, align 8, !dbg !66, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %40 = load ptr, ptr %a.addr.ascast.i, align 8, !dbg !66, !noalias !65, !llvm.access.group !73, !cray.depth !38
  store i32 0, ptr addrspace(5) %fork_tid.i, align 4, !dbg !66, !noalias !65
  %41 = addrspacecast ptr addrspace(5) %fork_tid.i to ptr, !dbg !66
  call void @llvm.experimental.noalias.scope.decl(metadata !74), !dbg !66
  call void @llvm.experimental.noalias.scope.decl(metadata !77), !dbg !66
  %.global_tid..addr.ascast.i13 = addrspacecast ptr addrspace(5) %.global_tid..addr.i1 to ptr
  %.bound_tid..addr.ascast.i14 = addrspacecast ptr addrspace(5) %.bound_tid..addr.i2 to ptr
  %.previous.lb..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.lb..addr.i to ptr
  %.previous.ub..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.ub..addr.i to ptr
  %n.addr.ascast.i15 = addrspacecast ptr addrspace(5) %n.addr.i3 to ptr
  %a.addr.ascast.i16 = addrspacecast ptr addrspace(5) %a.addr.i4 to ptr
  %d2.addr.ascast.i17 = addrspacecast ptr addrspace(5) %d2.addr.i5 to ptr
  %.omp.iv.ascast.i18 = addrspacecast ptr addrspace(5) %.omp.iv.i6 to ptr
  %tmp.ascast.i19 = addrspacecast ptr addrspace(5) %tmp.i7 to ptr
  %.capture_expr..ascast.i20 = addrspacecast ptr addrspace(5) %.capture_expr..i8 to ptr
  %.capture_expr.1.ascast.i21 = addrspacecast ptr addrspace(5) %.capture_expr.1.i9 to ptr
  %i.ascast.i22 = addrspacecast ptr addrspace(5) %i.i10 to ptr
  %.omp.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.lb.i to ptr
  %.omp.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.ub.i to ptr
  %.omp.stride.ascast.i23 = addrspacecast ptr addrspace(5) %.omp.stride.i11 to ptr
  %.omp.is_last.ascast.i24 = addrspacecast ptr addrspace(5) %.omp.is_last.i12 to ptr
  %i4.ascast.i = addrspacecast ptr addrspace(5) %i4.i to ptr
  store ptr %41, ptr %.global_tid..addr.ascast.i13, align 8, !noalias !79
  store ptr %41, ptr %.bound_tid..addr.ascast.i14, align 8, !noalias !79
  store i64 %35, ptr %.previous.lb..addr.ascast.i, align 8, !noalias !79
  store i64 %37, ptr %.previous.ub..addr.ascast.i, align 8, !noalias !79
  store i64 %39, ptr %n.addr.ascast.i15, align 8, !noalias !79
  store ptr %40, ptr %a.addr.ascast.i16, align 8, !noalias !79
  store ptr %5, ptr %d2.addr.ascast.i17, align 8, !noalias !79
  %42 = load ptr, ptr %d2.addr.ascast.i17, align 8, !dbg !80, !noalias !79, !nonnull !18, !align !20
  %43 = load i32, ptr %n.addr.ascast.i15, align 4, !dbg !83, !noalias !79
  store i32 %43, ptr %.capture_expr..ascast.i20, align 4, !dbg !83, !noalias !79
  %44 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !83, !noalias !79
  %sub2.i25 = sub nsw i32 %44, 1, !dbg !84
  store i32 %sub2.i25, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !84, !noalias !79
  store i32 0, ptr %i.ascast.i22, align 4, !dbg !85, !noalias !79
  %45 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !83, !noalias !79
  %cmp.i26 = icmp slt i32 0, %45, !dbg !84
  br i1 %cmp.i26, label %omp.precond.then.i27, label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.exit, !dbg !80

omp.precond.then.i27:                             ; preds = %omp.dispatch.body.i
  store i32 0, ptr %.omp.lb.ascast.i, align 4, !dbg !86, !noalias !79
  %46 = load i32, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !84, !noalias !79
  store i32 %46, ptr %.omp.ub.ascast.i, align 4, !dbg !86, !noalias !79
  %47 = load i64, ptr %.previous.lb..addr.ascast.i, align 8, !dbg !80, !noalias !79
  %conv.i = trunc i64 %47 to i32, !dbg !80
  %48 = load i64, ptr %.previous.ub..addr.ascast.i, align 8, !dbg !80, !noalias !79
  %conv3.i = trunc i64 %48 to i32, !dbg !80
  store i32 %conv.i, ptr %.omp.lb.ascast.i, align 4, !dbg !80, !noalias !79
  store i32 %conv3.i, ptr %.omp.ub.ascast.i, align 4, !dbg !80, !noalias !79
  store i32 1, ptr %.omp.stride.ascast.i23, align 4, !dbg !86, !noalias !79
  store i32 0, ptr %.omp.is_last.ascast.i24, align 4, !dbg !86, !noalias !79
  %49 = load i32, ptr %.omp.lb.ascast.i, align 4, !dbg !86, !noalias !79
  store i32 %49, ptr %.omp.iv.ascast.i18, align 4, !dbg !86, !noalias !79
  %50 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !86, !noalias !79, !cray.depth !36
  store i32 %50, ptr %i4.ascast.i, align 4, !dbg !85, !noalias !79, !cray.depth !36
  %51 = load ptr, ptr %a.addr.ascast.i16, align 8, !dbg !87, !noalias !79, !cray.depth !36
  %52 = load i32, ptr %i4.ascast.i, align 4, !dbg !88, !noalias !79, !cray.depth !36
  %idxprom.i = sext i32 %52 to i64, !dbg !87, !cray.depth !36
  %arrayidx.i = getelementptr inbounds i32, ptr %51, i64 %idxprom.i, !dbg !87, !cray.depth !36
  %53 = load i32, ptr %arrayidx.i, align 4, !dbg !87, !cray.depth !36
  %tobool.i = icmp ne i32 %53, 0, !dbg !87, !cray.depth !36
  br i1 %tobool.i, label %if.then.i, label %if.end.i, !dbg !87, !cray.depth !36

if.then.i:                                        ; preds = %omp.precond.then.i27
  %54 = atomicrmw add ptr %42, i32 1 syncscope("agent") monotonic, align 4, !dbg !89, !amdgpu.no.fine.grained.memory !18, !amdgpu.no.remote.memory !18, !cray.depth !36
  br label %if.end.i, !dbg !90, !cray.depth !36

if.end.i:                                         ; preds = %if.then.i, %omp.precond.then.i27
  %55 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !86, !noalias !79, !cray.depth !36
  %56 = load i32, ptr %.omp.stride.ascast.i23, align 4, !dbg !86, !noalias !79, !cray.depth !36
  %add8.i29 = add nsw i32 %55, %56, !dbg !84, !cray.depth !36
  store i32 %add8.i29, ptr %.omp.iv.ascast.i18, align 4, !dbg !84, !noalias !79, !cray.depth !36
  br label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.exit, !dbg !80

__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.exit: ; preds = %omp.dispatch.body.i, %if.end.i
  %57 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !72, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %58 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !72, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %add.i = add nsw i32 %57, %58, !dbg !70, !cray.depth !38
  store i32 %add.i, ptr %.omp.iv.ascast.i, align 4, !dbg !70, !noalias !65, !llvm.access.group !73, !cray.depth !38
  %59 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %60 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %add7.i = add nsw i32 %59, %60, !dbg !70, !cray.depth !36
  store i32 %add7.i, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !70, !noalias !65, !cray.depth !36
  %61 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %62 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !72, !noalias !65, !cray.depth !36
  %add8.i = add nsw i32 %61, %62, !dbg !70, !cray.depth !36
  store i32 %add8.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !70, !noalias !65, !cray.depth !36
  br label %omp.dispatch.cond.i, !dbg !91

omp.dispatch.end.i:                               ; preds = %cond.end.i
  br label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.exit, !dbg !91

__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.exit: ; preds = %entry, %omp.dispatch.end.i
  ret void, !dbg !92
}

declare void @"__craygpu==>fork_parallel_dist_for___omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined"(ptr, i64, i64, i64, ptr, ptr)

declare void @"__craygpu==>fork_teams___omp_offloading_8116438_fc00c07e_main_l16_omp_outlined"(ptr, i64, ptr, ptr)

; Function Attrs: convergent noinline norecurse nounwind optnone
define weak_odr protected amdgpu_kernel void @"__omp_offloading_8116438_fc00c07e_main_l11_cce$noloop$form"(ptr noalias noundef %dyn_ptr, i64 noundef %n, ptr noundef %a, ptr noundef nonnull align 4 dereferenceable(4) %d1) #0 !dbg !93 {
entry:
  %.global_tid..addr.i1 = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i2 = alloca ptr, align 8, addrspace(5)
  %.previous.lb..addr.i = alloca i64, align 8, addrspace(5)
  %.previous.ub..addr.i = alloca i64, align 8, addrspace(5)
  %n.addr.i3 = alloca i64, align 8, addrspace(5)
  %a.addr.i4 = alloca ptr, align 8, addrspace(5)
  %d1.addr.i5 = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i6 = alloca i32, align 4, addrspace(5)
  %tmp.i7 = alloca i32, align 4, addrspace(5)
  %.capture_expr..i8 = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i9 = alloca i32, align 4, addrspace(5)
  %i.i10 = alloca i32, align 4, addrspace(5)
  %.omp.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i11 = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i12 = alloca i32, align 4, addrspace(5)
  %i4.i = alloca i32, align 4, addrspace(5)
  %fork_tid.i = alloca i32, align 4, addrspace(5)
  %.global_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %n.addr.i = alloca i64, align 8, addrspace(5)
  %a.addr.i = alloca ptr, align 8, addrspace(5)
  %d1.addr.i = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i = alloca i32, align 4, addrspace(5)
  %tmp.i = alloca i32, align 4, addrspace(5)
  %.capture_expr..i = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i = alloca i32, align 4, addrspace(5)
  %i.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i = alloca i32, align 4, addrspace(5)
  %i3.i = alloca i32, align 4, addrspace(5)
  %n.casted.i = alloca i64, align 8, addrspace(5)
  %fork_tid = alloca i32, align 4, addrspace(5)
  %dyn_ptr.addr = alloca ptr, align 8, addrspace(5)
  %n.addr = alloca i64, align 8, addrspace(5)
  %a.addr = alloca ptr, align 8, addrspace(5)
  %d1.addr = alloca ptr, align 8, addrspace(5)
  %n.casted = alloca i64, align 8, addrspace(5)
  %dyn_ptr.addr.ascast = addrspacecast ptr addrspace(5) %dyn_ptr.addr to ptr
  %n.addr.ascast = addrspacecast ptr addrspace(5) %n.addr to ptr
  %a.addr.ascast = addrspacecast ptr addrspace(5) %a.addr to ptr
  %d1.addr.ascast = addrspacecast ptr addrspace(5) %d1.addr to ptr
  %n.casted.ascast = addrspacecast ptr addrspace(5) %n.casted to ptr
  store ptr %dyn_ptr, ptr %dyn_ptr.addr.ascast, align 8
  store i64 %n, ptr %n.addr.ascast, align 8
  store ptr %a, ptr %a.addr.ascast, align 8
  store ptr %d1, ptr %d1.addr.ascast, align 8
  %0 = load ptr, ptr %d1.addr.ascast, align 8, !dbg !94, !nonnull !18, !align !20
  %1 = load i32, ptr %n.addr.ascast, align 4, !dbg !94
  store i32 %1, ptr %n.casted.ascast, align 4, !dbg !94
  %2 = load i64, ptr %n.casted.ascast, align 8, !dbg !94
  %3 = load ptr, ptr %a.addr.ascast, align 8, !dbg !94
  store i32 0, ptr addrspace(5) %fork_tid, align 4, !dbg !94
  %4 = addrspacecast ptr addrspace(5) %fork_tid to ptr, !dbg !94
  call void @llvm.experimental.noalias.scope.decl(metadata !95), !dbg !94
  call void @llvm.experimental.noalias.scope.decl(metadata !98), !dbg !94
  %.global_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.global_tid..addr.i to ptr
  %.bound_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.bound_tid..addr.i to ptr
  %n.addr.ascast.i = addrspacecast ptr addrspace(5) %n.addr.i to ptr
  %a.addr.ascast.i = addrspacecast ptr addrspace(5) %a.addr.i to ptr
  %d1.addr.ascast.i = addrspacecast ptr addrspace(5) %d1.addr.i to ptr
  %.omp.iv.ascast.i = addrspacecast ptr addrspace(5) %.omp.iv.i to ptr
  %tmp.ascast.i = addrspacecast ptr addrspace(5) %tmp.i to ptr
  %.capture_expr..ascast.i = addrspacecast ptr addrspace(5) %.capture_expr..i to ptr
  %.capture_expr.1.ascast.i = addrspacecast ptr addrspace(5) %.capture_expr.1.i to ptr
  %i.ascast.i = addrspacecast ptr addrspace(5) %i.i to ptr
  %.omp.comb.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.lb.i to ptr
  %.omp.comb.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.ub.i to ptr
  %.omp.stride.ascast.i = addrspacecast ptr addrspace(5) %.omp.stride.i to ptr
  %.omp.is_last.ascast.i = addrspacecast ptr addrspace(5) %.omp.is_last.i to ptr
  %i3.ascast.i = addrspacecast ptr addrspace(5) %i3.i to ptr
  %n.casted.ascast.i = addrspacecast ptr addrspace(5) %n.casted.i to ptr
  store ptr %4, ptr %.global_tid..addr.ascast.i, align 8, !noalias !100
  store ptr %4, ptr %.bound_tid..addr.ascast.i, align 8, !noalias !100
  store i64 %2, ptr %n.addr.ascast.i, align 8, !noalias !100
  store ptr %3, ptr %a.addr.ascast.i, align 8, !noalias !100
  store ptr %0, ptr %d1.addr.ascast.i, align 8, !noalias !100
  %5 = load ptr, ptr %d1.addr.ascast.i, align 8, !dbg !101, !noalias !100, !nonnull !18, !align !20
  %6 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !104, !noalias !100
  store i32 %6, ptr %.capture_expr..ascast.i, align 4, !dbg !104, !noalias !100
  %7 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !104, !noalias !100
  %sub2.i = sub nsw i32 %7, 1, !dbg !105
  store i32 %sub2.i, ptr %.capture_expr.1.ascast.i, align 4, !dbg !105, !noalias !100
  store i32 0, ptr %i.ascast.i, align 4, !dbg !106, !noalias !100
  %8 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !104, !noalias !100
  %cmp.i = icmp slt i32 0, %8, !dbg !105
  br i1 %cmp.i, label %omp.precond.then.i, label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.2.exit, !dbg !101

omp.precond.then.i:                               ; preds = %entry
  store i32 0, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !107, !noalias !100
  %9 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !105, !noalias !100
  store i32 %9, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !107, !noalias !100
  store i32 1, ptr %.omp.stride.ascast.i, align 4, !dbg !107, !noalias !100
  store i32 0, ptr %.omp.is_last.ascast.i, align 4, !dbg !107, !noalias !100
  %10 = call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !101
  %11 = load i32, ptr addrspace(4) @__oclc_ABI_version, align 4, !dbg !101
  %12 = icmp sgt i32 %11, 499, !dbg !101
  %13 = call align 8 dereferenceable(256) ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr(), !dbg !101
  %14 = getelementptr inbounds nuw i8, ptr addrspace(4) %13, i64 12, !dbg !101
  %15 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !101
  %16 = getelementptr inbounds nuw i8, ptr addrspace(4) %15, i64 4, !dbg !101
  %17 = select i1 %12, ptr addrspace(4) %14, ptr addrspace(4) %16, !dbg !101
  %18 = load i16, ptr addrspace(4) %17, align 4, !dbg !101, !range !34, !invariant.load !18, !noundef !18
  %conv.i31 = zext nneg i16 %18 to i32, !dbg !101
  %mul.i = mul i32 %10, %conv.i31, !dbg !101
  %19 = call i32 @llvm.amdgcn.workitem.id.x(), !dbg !101
  %add.i32 = add i32 %mul.i, %19, !dbg !101
  %conv1.i = zext i32 %add.i32 to i64, !dbg !101
  %20 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !101
  %21 = getelementptr inbounds nuw i8, ptr addrspace(4) %20, i64 12, !dbg !101
  %22 = load i32, ptr addrspace(4) %21, align 4, !dbg !101, !range !35, !invariant.load !18
  %conv.i30 = zext i32 %22 to i64, !dbg !101
  %23 = trunc i64 %conv1.i to i32, !dbg !101
  %24 = trunc i64 %conv.i30 to i32, !dbg !101
  %25 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !101, !noalias !100
  %26 = add i32 %25, %23, !dbg !101
  store i32 %26, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !101, !noalias !100
  store i32 %26, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !101, !noalias !100
  store i32 %24, ptr %.omp.stride.ascast.i, align 4, !dbg !101, !noalias !100
  %27 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %28 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !105, !noalias !100, !cray.depth !36
  %cmp4.i = icmp sgt i32 %27, %28, !dbg !107, !cray.depth !36
  br i1 %cmp4.i, label %cond.true.i, label %cond.false.i, !dbg !107, !cray.depth !36

cond.true.i:                                      ; preds = %omp.precond.then.i
  %29 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !105, !noalias !100, !cray.depth !36
  br label %cond.end.i, !dbg !107, !cray.depth !36

cond.false.i:                                     ; preds = %omp.precond.then.i
  %30 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  br label %cond.end.i, !dbg !107, !cray.depth !36

cond.end.i:                                       ; preds = %cond.false.i, %cond.true.i
  %cond.i = phi i32 [ %29, %cond.true.i ], [ %30, %cond.false.i ], !dbg !107, !cray.depth !36
  store i32 %cond.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %31 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  store i32 %31, ptr %.omp.iv.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %32 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %33 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %cmp5.i = icmp sle i32 %32, %33, !dbg !105, !cray.depth !36
  br i1 %cmp5.i, label %omp.dispatch.body.i, label %omp.dispatch.end.i, !dbg !101, !cray.depth !36

omp.dispatch.body.i:                              ; preds = %cond.end.i
  %34 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !101, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %35 = zext i32 %34 to i64, !dbg !101, !cray.depth !38
  %36 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !101, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %37 = zext i32 %36 to i64, !dbg !101, !cray.depth !38
  %38 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !101, !noalias !100, !llvm.access.group !108, !cray.depth !38
  store i32 %38, ptr %n.casted.ascast.i, align 4, !dbg !101, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %39 = load i64, ptr %n.casted.ascast.i, align 8, !dbg !101, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %40 = load ptr, ptr %a.addr.ascast.i, align 8, !dbg !101, !noalias !100, !llvm.access.group !108, !cray.depth !38
  store i32 0, ptr addrspace(5) %fork_tid.i, align 4, !dbg !101, !noalias !100
  %41 = addrspacecast ptr addrspace(5) %fork_tid.i to ptr, !dbg !101
  call void @llvm.experimental.noalias.scope.decl(metadata !109), !dbg !101
  call void @llvm.experimental.noalias.scope.decl(metadata !112), !dbg !101
  %.global_tid..addr.ascast.i13 = addrspacecast ptr addrspace(5) %.global_tid..addr.i1 to ptr
  %.bound_tid..addr.ascast.i14 = addrspacecast ptr addrspace(5) %.bound_tid..addr.i2 to ptr
  %.previous.lb..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.lb..addr.i to ptr
  %.previous.ub..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.ub..addr.i to ptr
  %n.addr.ascast.i15 = addrspacecast ptr addrspace(5) %n.addr.i3 to ptr
  %a.addr.ascast.i16 = addrspacecast ptr addrspace(5) %a.addr.i4 to ptr
  %d1.addr.ascast.i17 = addrspacecast ptr addrspace(5) %d1.addr.i5 to ptr
  %.omp.iv.ascast.i18 = addrspacecast ptr addrspace(5) %.omp.iv.i6 to ptr
  %tmp.ascast.i19 = addrspacecast ptr addrspace(5) %tmp.i7 to ptr
  %.capture_expr..ascast.i20 = addrspacecast ptr addrspace(5) %.capture_expr..i8 to ptr
  %.capture_expr.1.ascast.i21 = addrspacecast ptr addrspace(5) %.capture_expr.1.i9 to ptr
  %i.ascast.i22 = addrspacecast ptr addrspace(5) %i.i10 to ptr
  %.omp.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.lb.i to ptr
  %.omp.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.ub.i to ptr
  %.omp.stride.ascast.i23 = addrspacecast ptr addrspace(5) %.omp.stride.i11 to ptr
  %.omp.is_last.ascast.i24 = addrspacecast ptr addrspace(5) %.omp.is_last.i12 to ptr
  %i4.ascast.i = addrspacecast ptr addrspace(5) %i4.i to ptr
  store ptr %41, ptr %.global_tid..addr.ascast.i13, align 8, !noalias !114
  store ptr %41, ptr %.bound_tid..addr.ascast.i14, align 8, !noalias !114
  store i64 %35, ptr %.previous.lb..addr.ascast.i, align 8, !noalias !114
  store i64 %37, ptr %.previous.ub..addr.ascast.i, align 8, !noalias !114
  store i64 %39, ptr %n.addr.ascast.i15, align 8, !noalias !114
  store ptr %40, ptr %a.addr.ascast.i16, align 8, !noalias !114
  store ptr %5, ptr %d1.addr.ascast.i17, align 8, !noalias !114
  %42 = load ptr, ptr %d1.addr.ascast.i17, align 8, !dbg !115, !noalias !114, !nonnull !18, !align !20
  %43 = load i32, ptr %n.addr.ascast.i15, align 4, !dbg !118, !noalias !114
  store i32 %43, ptr %.capture_expr..ascast.i20, align 4, !dbg !118, !noalias !114
  %44 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !118, !noalias !114
  %sub2.i25 = sub nsw i32 %44, 1, !dbg !119
  store i32 %sub2.i25, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !119, !noalias !114
  store i32 0, ptr %i.ascast.i22, align 4, !dbg !120, !noalias !114
  %45 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !118, !noalias !114
  %cmp.i26 = icmp slt i32 0, %45, !dbg !119
  br i1 %cmp.i26, label %omp.precond.then.i27, label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3.exit, !dbg !115

omp.precond.then.i27:                             ; preds = %omp.dispatch.body.i
  store i32 0, ptr %.omp.lb.ascast.i, align 4, !dbg !121, !noalias !114
  %46 = load i32, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !119, !noalias !114
  store i32 %46, ptr %.omp.ub.ascast.i, align 4, !dbg !121, !noalias !114
  %47 = load i64, ptr %.previous.lb..addr.ascast.i, align 8, !dbg !115, !noalias !114
  %conv.i = trunc i64 %47 to i32, !dbg !115
  %48 = load i64, ptr %.previous.ub..addr.ascast.i, align 8, !dbg !115, !noalias !114
  %conv3.i = trunc i64 %48 to i32, !dbg !115
  store i32 %conv.i, ptr %.omp.lb.ascast.i, align 4, !dbg !115, !noalias !114
  store i32 %conv3.i, ptr %.omp.ub.ascast.i, align 4, !dbg !115, !noalias !114
  store i32 1, ptr %.omp.stride.ascast.i23, align 4, !dbg !121, !noalias !114
  store i32 0, ptr %.omp.is_last.ascast.i24, align 4, !dbg !121, !noalias !114
  %49 = load i32, ptr %.omp.lb.ascast.i, align 4, !dbg !121, !noalias !114
  store i32 %49, ptr %.omp.iv.ascast.i18, align 4, !dbg !121, !noalias !114
  %50 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !121, !noalias !114, !cray.depth !36
  store i32 %50, ptr %i4.ascast.i, align 4, !dbg !120, !noalias !114, !cray.depth !36
  %51 = load ptr, ptr %a.addr.ascast.i16, align 8, !dbg !122, !noalias !114, !cray.depth !36
  %52 = load i32, ptr %i4.ascast.i, align 4, !dbg !123, !noalias !114, !cray.depth !36
  %idxprom.i = sext i32 %52 to i64, !dbg !122, !cray.depth !36
  %arrayidx.i = getelementptr inbounds i32, ptr %51, i64 %idxprom.i, !dbg !122, !cray.depth !36
  %53 = load i32, ptr %arrayidx.i, align 4, !dbg !122, !cray.depth !36
  %tobool.i = icmp ne i32 %53, 0, !dbg !122, !cray.depth !36
  br i1 %tobool.i, label %if.then.i, label %if.end.i, !dbg !122, !cray.depth !36

if.then.i:                                        ; preds = %omp.precond.then.i27
  %54 = atomicrmw add ptr %42, i32 1 syncscope("agent") monotonic, align 4, !dbg !124, !amdgpu.no.fine.grained.memory !18, !amdgpu.no.remote.memory !18, !cray.depth !36
  br label %if.end.i, !dbg !125, !cray.depth !36

if.end.i:                                         ; preds = %if.then.i, %omp.precond.then.i27
  %55 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !121, !noalias !114, !cray.depth !36
  %56 = load i32, ptr %.omp.stride.ascast.i23, align 4, !dbg !121, !noalias !114, !cray.depth !36
  %add8.i29 = add nsw i32 %55, %56, !dbg !119, !cray.depth !36
  store i32 %add8.i29, ptr %.omp.iv.ascast.i18, align 4, !dbg !119, !noalias !114, !cray.depth !36
  br label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3.exit, !dbg !115

__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3.exit: ; preds = %omp.dispatch.body.i, %if.end.i
  %57 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !107, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %58 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !107, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %add.i = add nsw i32 %57, %58, !dbg !105, !cray.depth !38
  store i32 %add.i, ptr %.omp.iv.ascast.i, align 4, !dbg !105, !noalias !100, !llvm.access.group !108, !cray.depth !38
  %59 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %60 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %add7.i = add nsw i32 %59, %60, !dbg !105, !cray.depth !36
  store i32 %add7.i, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !105, !noalias !100, !cray.depth !36
  %61 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %62 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !107, !noalias !100, !cray.depth !36
  %add8.i = add nsw i32 %61, %62, !dbg !105, !cray.depth !36
  store i32 %add8.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !105, !noalias !100, !cray.depth !36
  br label %omp.dispatch.end.i, !dbg !126

omp.dispatch.end.i:                               ; preds = %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3.exit, %cond.end.i
  br label %__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.2.exit, !dbg !126

__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.2.exit: ; preds = %entry, %omp.dispatch.end.i
  ret void, !dbg !127
}

; Function Attrs: convergent noinline norecurse nounwind optnone
define weak_odr protected amdgpu_kernel void @"__omp_offloading_8116438_fc00c07e_main_l16_cce$noloop$form"(ptr noalias noundef %dyn_ptr, i64 noundef %n, ptr noundef %a, ptr noundef nonnull align 4 dereferenceable(4) %d2) #0 !dbg !128 {
entry:
  %.global_tid..addr.i1 = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i2 = alloca ptr, align 8, addrspace(5)
  %.previous.lb..addr.i = alloca i64, align 8, addrspace(5)
  %.previous.ub..addr.i = alloca i64, align 8, addrspace(5)
  %n.addr.i3 = alloca i64, align 8, addrspace(5)
  %a.addr.i4 = alloca ptr, align 8, addrspace(5)
  %d2.addr.i5 = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i6 = alloca i32, align 4, addrspace(5)
  %tmp.i7 = alloca i32, align 4, addrspace(5)
  %.capture_expr..i8 = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i9 = alloca i32, align 4, addrspace(5)
  %i.i10 = alloca i32, align 4, addrspace(5)
  %.omp.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i11 = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i12 = alloca i32, align 4, addrspace(5)
  %i4.i = alloca i32, align 4, addrspace(5)
  %fork_tid.i = alloca i32, align 4, addrspace(5)
  %.global_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %.bound_tid..addr.i = alloca ptr, align 8, addrspace(5)
  %n.addr.i = alloca i64, align 8, addrspace(5)
  %a.addr.i = alloca ptr, align 8, addrspace(5)
  %d2.addr.i = alloca ptr, align 8, addrspace(5)
  %.omp.iv.i = alloca i32, align 4, addrspace(5)
  %tmp.i = alloca i32, align 4, addrspace(5)
  %.capture_expr..i = alloca i32, align 4, addrspace(5)
  %.capture_expr.1.i = alloca i32, align 4, addrspace(5)
  %i.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.lb.i = alloca i32, align 4, addrspace(5)
  %.omp.comb.ub.i = alloca i32, align 4, addrspace(5)
  %.omp.stride.i = alloca i32, align 4, addrspace(5)
  %.omp.is_last.i = alloca i32, align 4, addrspace(5)
  %i3.i = alloca i32, align 4, addrspace(5)
  %n.casted.i = alloca i64, align 8, addrspace(5)
  %fork_tid = alloca i32, align 4, addrspace(5)
  %dyn_ptr.addr = alloca ptr, align 8, addrspace(5)
  %n.addr = alloca i64, align 8, addrspace(5)
  %a.addr = alloca ptr, align 8, addrspace(5)
  %d2.addr = alloca ptr, align 8, addrspace(5)
  %n.casted = alloca i64, align 8, addrspace(5)
  %dyn_ptr.addr.ascast = addrspacecast ptr addrspace(5) %dyn_ptr.addr to ptr
  %n.addr.ascast = addrspacecast ptr addrspace(5) %n.addr to ptr
  %a.addr.ascast = addrspacecast ptr addrspace(5) %a.addr to ptr
  %d2.addr.ascast = addrspacecast ptr addrspace(5) %d2.addr to ptr
  %n.casted.ascast = addrspacecast ptr addrspace(5) %n.casted to ptr
  store ptr %dyn_ptr, ptr %dyn_ptr.addr.ascast, align 8
  store i64 %n, ptr %n.addr.ascast, align 8
  store ptr %a, ptr %a.addr.ascast, align 8
  store ptr %d2, ptr %d2.addr.ascast, align 8
  %0 = load ptr, ptr %d2.addr.ascast, align 8, !dbg !129, !nonnull !18, !align !20
  %1 = load i32, ptr %n.addr.ascast, align 4, !dbg !129
  store i32 %1, ptr %n.casted.ascast, align 4, !dbg !129
  %2 = load i64, ptr %n.casted.ascast, align 8, !dbg !129
  %3 = load ptr, ptr %a.addr.ascast, align 8, !dbg !129
  store i32 0, ptr addrspace(5) %fork_tid, align 4, !dbg !129
  %4 = addrspacecast ptr addrspace(5) %fork_tid to ptr, !dbg !129
  call void @llvm.experimental.noalias.scope.decl(metadata !130), !dbg !129
  call void @llvm.experimental.noalias.scope.decl(metadata !133), !dbg !129
  %.global_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.global_tid..addr.i to ptr
  %.bound_tid..addr.ascast.i = addrspacecast ptr addrspace(5) %.bound_tid..addr.i to ptr
  %n.addr.ascast.i = addrspacecast ptr addrspace(5) %n.addr.i to ptr
  %a.addr.ascast.i = addrspacecast ptr addrspace(5) %a.addr.i to ptr
  %d2.addr.ascast.i = addrspacecast ptr addrspace(5) %d2.addr.i to ptr
  %.omp.iv.ascast.i = addrspacecast ptr addrspace(5) %.omp.iv.i to ptr
  %tmp.ascast.i = addrspacecast ptr addrspace(5) %tmp.i to ptr
  %.capture_expr..ascast.i = addrspacecast ptr addrspace(5) %.capture_expr..i to ptr
  %.capture_expr.1.ascast.i = addrspacecast ptr addrspace(5) %.capture_expr.1.i to ptr
  %i.ascast.i = addrspacecast ptr addrspace(5) %i.i to ptr
  %.omp.comb.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.lb.i to ptr
  %.omp.comb.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.comb.ub.i to ptr
  %.omp.stride.ascast.i = addrspacecast ptr addrspace(5) %.omp.stride.i to ptr
  %.omp.is_last.ascast.i = addrspacecast ptr addrspace(5) %.omp.is_last.i to ptr
  %i3.ascast.i = addrspacecast ptr addrspace(5) %i3.i to ptr
  %n.casted.ascast.i = addrspacecast ptr addrspace(5) %n.casted.i to ptr
  store ptr %4, ptr %.global_tid..addr.ascast.i, align 8, !noalias !135
  store ptr %4, ptr %.bound_tid..addr.ascast.i, align 8, !noalias !135
  store i64 %2, ptr %n.addr.ascast.i, align 8, !noalias !135
  store ptr %3, ptr %a.addr.ascast.i, align 8, !noalias !135
  store ptr %0, ptr %d2.addr.ascast.i, align 8, !noalias !135
  %5 = load ptr, ptr %d2.addr.ascast.i, align 8, !dbg !136, !noalias !135, !nonnull !18, !align !20
  %6 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !139, !noalias !135
  store i32 %6, ptr %.capture_expr..ascast.i, align 4, !dbg !139, !noalias !135
  %7 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !139, !noalias !135
  %sub2.i = sub nsw i32 %7, 1, !dbg !140
  store i32 %sub2.i, ptr %.capture_expr.1.ascast.i, align 4, !dbg !140, !noalias !135
  store i32 0, ptr %i.ascast.i, align 4, !dbg !141, !noalias !135
  %8 = load i32, ptr %.capture_expr..ascast.i, align 4, !dbg !139, !noalias !135
  %cmp.i = icmp slt i32 0, %8, !dbg !140
  br i1 %cmp.i, label %omp.precond.then.i, label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.5.exit, !dbg !136

omp.precond.then.i:                               ; preds = %entry
  store i32 0, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !142, !noalias !135
  %9 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !140, !noalias !135
  store i32 %9, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !142, !noalias !135
  store i32 1, ptr %.omp.stride.ascast.i, align 4, !dbg !142, !noalias !135
  store i32 0, ptr %.omp.is_last.ascast.i, align 4, !dbg !142, !noalias !135
  %10 = call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !136
  %11 = load i32, ptr addrspace(4) @__oclc_ABI_version, align 4, !dbg !136
  %12 = icmp sgt i32 %11, 499, !dbg !136
  %13 = call align 8 dereferenceable(256) ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr(), !dbg !136
  %14 = getelementptr inbounds nuw i8, ptr addrspace(4) %13, i64 12, !dbg !136
  %15 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !136
  %16 = getelementptr inbounds nuw i8, ptr addrspace(4) %15, i64 4, !dbg !136
  %17 = select i1 %12, ptr addrspace(4) %14, ptr addrspace(4) %16, !dbg !136
  %18 = load i16, ptr addrspace(4) %17, align 4, !dbg !136, !range !34, !invariant.load !18, !noundef !18
  %conv.i31 = zext nneg i16 %18 to i32, !dbg !136
  %mul.i = mul i32 %10, %conv.i31, !dbg !136
  %19 = call i32 @llvm.amdgcn.workitem.id.x(), !dbg !136
  %add.i32 = add i32 %mul.i, %19, !dbg !136
  %conv1.i = zext i32 %add.i32 to i64, !dbg !136
  %20 = call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !136
  %21 = getelementptr inbounds nuw i8, ptr addrspace(4) %20, i64 12, !dbg !136
  %22 = load i32, ptr addrspace(4) %21, align 4, !dbg !136, !range !35, !invariant.load !18
  %conv.i30 = zext i32 %22 to i64, !dbg !136
  %23 = trunc i64 %conv1.i to i32, !dbg !136
  %24 = trunc i64 %conv.i30 to i32, !dbg !136
  %25 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !136, !noalias !135
  %26 = add i32 %25, %23, !dbg !136
  store i32 %26, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !136, !noalias !135
  store i32 %26, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !136, !noalias !135
  store i32 %24, ptr %.omp.stride.ascast.i, align 4, !dbg !136, !noalias !135
  %27 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %28 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !140, !noalias !135, !cray.depth !36
  %cmp4.i = icmp sgt i32 %27, %28, !dbg !142, !cray.depth !36
  br i1 %cmp4.i, label %cond.true.i, label %cond.false.i, !dbg !142, !cray.depth !36

cond.true.i:                                      ; preds = %omp.precond.then.i
  %29 = load i32, ptr %.capture_expr.1.ascast.i, align 4, !dbg !140, !noalias !135, !cray.depth !36
  br label %cond.end.i, !dbg !142, !cray.depth !36

cond.false.i:                                     ; preds = %omp.precond.then.i
  %30 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  br label %cond.end.i, !dbg !142, !cray.depth !36

cond.end.i:                                       ; preds = %cond.false.i, %cond.true.i
  %cond.i = phi i32 [ %29, %cond.true.i ], [ %30, %cond.false.i ], !dbg !142, !cray.depth !36
  store i32 %cond.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %31 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  store i32 %31, ptr %.omp.iv.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %32 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %33 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %cmp5.i = icmp sle i32 %32, %33, !dbg !140, !cray.depth !36
  br i1 %cmp5.i, label %omp.dispatch.body.i, label %omp.dispatch.end.i, !dbg !136, !cray.depth !36

omp.dispatch.body.i:                              ; preds = %cond.end.i
  %34 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !136, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %35 = zext i32 %34 to i64, !dbg !136, !cray.depth !38
  %36 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !136, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %37 = zext i32 %36 to i64, !dbg !136, !cray.depth !38
  %38 = load i32, ptr %n.addr.ascast.i, align 4, !dbg !136, !noalias !135, !llvm.access.group !143, !cray.depth !38
  store i32 %38, ptr %n.casted.ascast.i, align 4, !dbg !136, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %39 = load i64, ptr %n.casted.ascast.i, align 8, !dbg !136, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %40 = load ptr, ptr %a.addr.ascast.i, align 8, !dbg !136, !noalias !135, !llvm.access.group !143, !cray.depth !38
  store i32 0, ptr addrspace(5) %fork_tid.i, align 4, !dbg !136, !noalias !135
  %41 = addrspacecast ptr addrspace(5) %fork_tid.i to ptr, !dbg !136
  call void @llvm.experimental.noalias.scope.decl(metadata !144), !dbg !136
  call void @llvm.experimental.noalias.scope.decl(metadata !147), !dbg !136
  %.global_tid..addr.ascast.i13 = addrspacecast ptr addrspace(5) %.global_tid..addr.i1 to ptr
  %.bound_tid..addr.ascast.i14 = addrspacecast ptr addrspace(5) %.bound_tid..addr.i2 to ptr
  %.previous.lb..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.lb..addr.i to ptr
  %.previous.ub..addr.ascast.i = addrspacecast ptr addrspace(5) %.previous.ub..addr.i to ptr
  %n.addr.ascast.i15 = addrspacecast ptr addrspace(5) %n.addr.i3 to ptr
  %a.addr.ascast.i16 = addrspacecast ptr addrspace(5) %a.addr.i4 to ptr
  %d2.addr.ascast.i17 = addrspacecast ptr addrspace(5) %d2.addr.i5 to ptr
  %.omp.iv.ascast.i18 = addrspacecast ptr addrspace(5) %.omp.iv.i6 to ptr
  %tmp.ascast.i19 = addrspacecast ptr addrspace(5) %tmp.i7 to ptr
  %.capture_expr..ascast.i20 = addrspacecast ptr addrspace(5) %.capture_expr..i8 to ptr
  %.capture_expr.1.ascast.i21 = addrspacecast ptr addrspace(5) %.capture_expr.1.i9 to ptr
  %i.ascast.i22 = addrspacecast ptr addrspace(5) %i.i10 to ptr
  %.omp.lb.ascast.i = addrspacecast ptr addrspace(5) %.omp.lb.i to ptr
  %.omp.ub.ascast.i = addrspacecast ptr addrspace(5) %.omp.ub.i to ptr
  %.omp.stride.ascast.i23 = addrspacecast ptr addrspace(5) %.omp.stride.i11 to ptr
  %.omp.is_last.ascast.i24 = addrspacecast ptr addrspace(5) %.omp.is_last.i12 to ptr
  %i4.ascast.i = addrspacecast ptr addrspace(5) %i4.i to ptr
  store ptr %41, ptr %.global_tid..addr.ascast.i13, align 8, !noalias !149
  store ptr %41, ptr %.bound_tid..addr.ascast.i14, align 8, !noalias !149
  store i64 %35, ptr %.previous.lb..addr.ascast.i, align 8, !noalias !149
  store i64 %37, ptr %.previous.ub..addr.ascast.i, align 8, !noalias !149
  store i64 %39, ptr %n.addr.ascast.i15, align 8, !noalias !149
  store ptr %40, ptr %a.addr.ascast.i16, align 8, !noalias !149
  store ptr %5, ptr %d2.addr.ascast.i17, align 8, !noalias !149
  %42 = load ptr, ptr %d2.addr.ascast.i17, align 8, !dbg !150, !noalias !149, !nonnull !18, !align !20
  %43 = load i32, ptr %n.addr.ascast.i15, align 4, !dbg !153, !noalias !149
  store i32 %43, ptr %.capture_expr..ascast.i20, align 4, !dbg !153, !noalias !149
  %44 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !153, !noalias !149
  %sub2.i25 = sub nsw i32 %44, 1, !dbg !154
  store i32 %sub2.i25, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !154, !noalias !149
  store i32 0, ptr %i.ascast.i22, align 4, !dbg !155, !noalias !149
  %45 = load i32, ptr %.capture_expr..ascast.i20, align 4, !dbg !153, !noalias !149
  %cmp.i26 = icmp slt i32 0, %45, !dbg !154
  br i1 %cmp.i26, label %omp.precond.then.i27, label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6.exit, !dbg !150

omp.precond.then.i27:                             ; preds = %omp.dispatch.body.i
  store i32 0, ptr %.omp.lb.ascast.i, align 4, !dbg !156, !noalias !149
  %46 = load i32, ptr %.capture_expr.1.ascast.i21, align 4, !dbg !154, !noalias !149
  store i32 %46, ptr %.omp.ub.ascast.i, align 4, !dbg !156, !noalias !149
  %47 = load i64, ptr %.previous.lb..addr.ascast.i, align 8, !dbg !150, !noalias !149
  %conv.i = trunc i64 %47 to i32, !dbg !150
  %48 = load i64, ptr %.previous.ub..addr.ascast.i, align 8, !dbg !150, !noalias !149
  %conv3.i = trunc i64 %48 to i32, !dbg !150
  store i32 %conv.i, ptr %.omp.lb.ascast.i, align 4, !dbg !150, !noalias !149
  store i32 %conv3.i, ptr %.omp.ub.ascast.i, align 4, !dbg !150, !noalias !149
  store i32 1, ptr %.omp.stride.ascast.i23, align 4, !dbg !156, !noalias !149
  store i32 0, ptr %.omp.is_last.ascast.i24, align 4, !dbg !156, !noalias !149
  %49 = load i32, ptr %.omp.lb.ascast.i, align 4, !dbg !156, !noalias !149
  store i32 %49, ptr %.omp.iv.ascast.i18, align 4, !dbg !156, !noalias !149
  %50 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !156, !noalias !149, !cray.depth !36
  store i32 %50, ptr %i4.ascast.i, align 4, !dbg !155, !noalias !149, !cray.depth !36
  %51 = load ptr, ptr %a.addr.ascast.i16, align 8, !dbg !157, !noalias !149, !cray.depth !36
  %52 = load i32, ptr %i4.ascast.i, align 4, !dbg !158, !noalias !149, !cray.depth !36
  %idxprom.i = sext i32 %52 to i64, !dbg !157, !cray.depth !36
  %arrayidx.i = getelementptr inbounds i32, ptr %51, i64 %idxprom.i, !dbg !157, !cray.depth !36
  %53 = load i32, ptr %arrayidx.i, align 4, !dbg !157, !cray.depth !36
  %tobool.i = icmp ne i32 %53, 0, !dbg !157, !cray.depth !36
  br i1 %tobool.i, label %if.then.i, label %if.end.i, !dbg !157, !cray.depth !36

if.then.i:                                        ; preds = %omp.precond.then.i27
  %54 = atomicrmw add ptr %42, i32 1 syncscope("agent") monotonic, align 4, !dbg !159, !amdgpu.no.fine.grained.memory !18, !amdgpu.no.remote.memory !18, !cray.depth !36
  br label %if.end.i, !dbg !160, !cray.depth !36

if.end.i:                                         ; preds = %if.then.i, %omp.precond.then.i27
  %55 = load i32, ptr %.omp.iv.ascast.i18, align 4, !dbg !156, !noalias !149, !cray.depth !36
  %56 = load i32, ptr %.omp.stride.ascast.i23, align 4, !dbg !156, !noalias !149, !cray.depth !36
  %add8.i29 = add nsw i32 %55, %56, !dbg !154, !cray.depth !36
  store i32 %add8.i29, ptr %.omp.iv.ascast.i18, align 4, !dbg !154, !noalias !149, !cray.depth !36
  br label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6.exit, !dbg !150

__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6.exit: ; preds = %omp.dispatch.body.i, %if.end.i
  %57 = load i32, ptr %.omp.iv.ascast.i, align 4, !dbg !142, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %58 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !142, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %add.i = add nsw i32 %57, %58, !dbg !140, !cray.depth !38
  store i32 %add.i, ptr %.omp.iv.ascast.i, align 4, !dbg !140, !noalias !135, !llvm.access.group !143, !cray.depth !38
  %59 = load i32, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %60 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %add7.i = add nsw i32 %59, %60, !dbg !140, !cray.depth !36
  store i32 %add7.i, ptr %.omp.comb.lb.ascast.i, align 4, !dbg !140, !noalias !135, !cray.depth !36
  %61 = load i32, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %62 = load i32, ptr %.omp.stride.ascast.i, align 4, !dbg !142, !noalias !135, !cray.depth !36
  %add8.i = add nsw i32 %61, %62, !dbg !140, !cray.depth !36
  store i32 %add8.i, ptr %.omp.comb.ub.ascast.i, align 4, !dbg !140, !noalias !135, !cray.depth !36
  br label %omp.dispatch.end.i, !dbg !161

omp.dispatch.end.i:                               ; preds = %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6.exit, %cond.end.i
  br label %__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.5.exit, !dbg !161

__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.5.exit: ; preds = %entry, %omp.dispatch.end.i
  ret void, !dbg !162
}

declare void @"__cray$acc$tgt_init_dev_runtime"(ptr)

declare void @"__cray$acc$tgt_enter_inactive_par"()

declare void @"__cray$acc$tgt_exit_inactive_par"()

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef nonnull align 4 ptr addrspace(4) @llvm.amdgcn.dispatch.ptr() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef align 4 ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite)
declare void @llvm.experimental.noalias.scope.decl(metadata) #2

attributes #0 = { convergent noinline norecurse nounwind optnone "amdgpu-flat-work-group-size"="1,1024" "amdgpu-no-completion-action" "frame-pointer"="all" "kernel" "no-trapping-math"="true" "omp_target_thread_limit"="1024" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" "uniform-work-group-size"="true" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite) }

!llvm.dbg.cu = !{!0}
!omp_offload.info = !{!2, !3}
!llvm.module.flags = !{!4, !5, !6, !7, !8, !9, !10, !11, !12}
!llvm.ident = !{!13, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14, !14}
!opencl.ocl.version = !{!15, !15, !15, !15, !15, !15, !15, !15, !15, !15, !15, !15, !15, !15, !15, !15}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "Cray clang version 21.0.2  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)", isOptimized: false, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "dm_min.c", directory: "/lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/defaultmap-zeroes-resident-arrays")
!2 = !{i32 0, i32 135357496, i32 -67059586, !"main", i32 11, i32 0, i32 0}
!3 = !{i32 0, i32 135357496, i32 -67059586, !"main", i32 16, i32 0, i32 1}
!4 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!5 = !{i32 2, !"Debug Info Version", i32 3}
!6 = !{i32 1, !"wchar_size", i32 4}
!7 = !{i32 7, !"openmp", i32 51}
!8 = !{i32 7, !"openmp-device", i32 51}
!9 = !{i32 8, !"PIC Level", i32 2}
!10 = !{i32 7, !"frame-pointer", i32 2}
!11 = !{i32 1, !"ThinLTO", i32 0}
!12 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!13 = !{!"Cray clang version 21.0.2  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!14 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!15 = !{i32 2, i32 0}
!16 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l11", scope: !1, file: !1, line: 11, type: !17, scopeLine: 11, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!17 = !DISubroutineType(types: !18)
!18 = !{}
!19 = !DILocation(line: 11, column: 1, scope: !16)
!20 = !{i64 4}
!21 = !{!22}
!22 = distinct !{!22, !23, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined: %.global_tid."}
!23 = distinct !{!23, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined"}
!24 = !{!25}
!25 = distinct !{!25, !23, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined: %.bound_tid."}
!26 = !{!22, !25}
!27 = !DILocation(line: 11, column: 1, scope: !28, inlinedAt: !29)
!28 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined", scope: !1, file: !1, line: 11, type: !17, scopeLine: 11, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!29 = distinct !DILocation(line: 11, column: 1, scope: !16)
!30 = !DILocation(line: 12, column: 25, scope: !28, inlinedAt: !29)
!31 = !DILocation(line: 12, column: 5, scope: !28, inlinedAt: !29)
!32 = !DILocation(line: 12, column: 28, scope: !28, inlinedAt: !29)
!33 = !DILocation(line: 12, column: 10, scope: !28, inlinedAt: !29)
!34 = !{i16 1, i16 1025}
!35 = !{i32 1, i32 0}
!36 = !{i32 1}
!37 = distinct !{}
!38 = !{i32 2}
!39 = !{!40}
!40 = distinct !{!40, !41, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined: %.global_tid."}
!41 = distinct !{!41, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined"}
!42 = !{!43}
!43 = distinct !{!43, !41, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined: %.bound_tid."}
!44 = !{!40, !43}
!45 = !DILocation(line: 11, column: 1, scope: !46, inlinedAt: !47)
!46 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined", scope: !1, file: !1, line: 11, type: !17, scopeLine: 11, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!47 = distinct !DILocation(line: 11, column: 1, scope: !28, inlinedAt: !29)
!48 = !DILocation(line: 12, column: 25, scope: !46, inlinedAt: !47)
!49 = !DILocation(line: 12, column: 5, scope: !46, inlinedAt: !47)
!50 = !DILocation(line: 12, column: 28, scope: !46, inlinedAt: !47)
!51 = !DILocation(line: 12, column: 10, scope: !46, inlinedAt: !47)
!52 = !DILocation(line: 12, column: 37, scope: !46, inlinedAt: !47)
!53 = !DILocation(line: 12, column: 39, scope: !46, inlinedAt: !47)
!54 = !DILocation(line: 14, column: 9, scope: !46, inlinedAt: !47)
!55 = !DILocation(line: 15, column: 5, scope: !46, inlinedAt: !47)
!56 = !DILocation(line: 11, column: 65, scope: !28, inlinedAt: !29)
!57 = !DILocation(line: 15, column: 5, scope: !16)
!58 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l16", scope: !1, file: !1, line: 16, type: !17, scopeLine: 16, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!59 = !DILocation(line: 16, column: 1, scope: !58)
!60 = !{!61}
!61 = distinct !{!61, !62, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined: %.global_tid."}
!62 = distinct !{!62, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined"}
!63 = !{!64}
!64 = distinct !{!64, !62, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined: %.bound_tid."}
!65 = !{!61, !64}
!66 = !DILocation(line: 16, column: 1, scope: !67, inlinedAt: !68)
!67 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined", scope: !1, file: !1, line: 16, type: !17, scopeLine: 16, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!68 = distinct !DILocation(line: 16, column: 1, scope: !58)
!69 = !DILocation(line: 17, column: 25, scope: !67, inlinedAt: !68)
!70 = !DILocation(line: 17, column: 5, scope: !67, inlinedAt: !68)
!71 = !DILocation(line: 17, column: 28, scope: !67, inlinedAt: !68)
!72 = !DILocation(line: 17, column: 10, scope: !67, inlinedAt: !68)
!73 = distinct !{}
!74 = !{!75}
!75 = distinct !{!75, !76, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined: %.global_tid."}
!76 = distinct !{!76, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined"}
!77 = !{!78}
!78 = distinct !{!78, !76, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined: %.bound_tid."}
!79 = !{!75, !78}
!80 = !DILocation(line: 16, column: 1, scope: !81, inlinedAt: !82)
!81 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined", scope: !1, file: !1, line: 16, type: !17, scopeLine: 16, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!82 = distinct !DILocation(line: 16, column: 1, scope: !67, inlinedAt: !68)
!83 = !DILocation(line: 17, column: 25, scope: !81, inlinedAt: !82)
!84 = !DILocation(line: 17, column: 5, scope: !81, inlinedAt: !82)
!85 = !DILocation(line: 17, column: 28, scope: !81, inlinedAt: !82)
!86 = !DILocation(line: 17, column: 10, scope: !81, inlinedAt: !82)
!87 = !DILocation(line: 17, column: 37, scope: !81, inlinedAt: !82)
!88 = !DILocation(line: 17, column: 39, scope: !81, inlinedAt: !82)
!89 = !DILocation(line: 19, column: 9, scope: !81, inlinedAt: !82)
!90 = !DILocation(line: 20, column: 5, scope: !81, inlinedAt: !82)
!91 = !DILocation(line: 16, column: 94, scope: !67, inlinedAt: !68)
!92 = !DILocation(line: 20, column: 5, scope: !58)
!93 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l11", scope: !1, file: !1, line: 11, type: !17, scopeLine: 11, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!94 = !DILocation(line: 11, column: 1, scope: !93)
!95 = !{!96}
!96 = distinct !{!96, !97, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.2: %.global_tid."}
!97 = distinct !{!97, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.2"}
!98 = !{!99}
!99 = distinct !{!99, !97, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined.2: %.bound_tid."}
!100 = !{!96, !99}
!101 = !DILocation(line: 11, column: 1, scope: !102, inlinedAt: !103)
!102 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined", scope: !1, file: !1, line: 11, type: !17, scopeLine: 11, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!103 = distinct !DILocation(line: 11, column: 1, scope: !93)
!104 = !DILocation(line: 12, column: 25, scope: !102, inlinedAt: !103)
!105 = !DILocation(line: 12, column: 5, scope: !102, inlinedAt: !103)
!106 = !DILocation(line: 12, column: 28, scope: !102, inlinedAt: !103)
!107 = !DILocation(line: 12, column: 10, scope: !102, inlinedAt: !103)
!108 = distinct !{}
!109 = !{!110}
!110 = distinct !{!110, !111, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3: %.global_tid."}
!111 = distinct !{!111, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3"}
!112 = !{!113}
!113 = distinct !{!113, !111, !"__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined.3: %.bound_tid."}
!114 = !{!110, !113}
!115 = !DILocation(line: 11, column: 1, scope: !116, inlinedAt: !117)
!116 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l11_omp_outlined_omp_outlined", scope: !1, file: !1, line: 11, type: !17, scopeLine: 11, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!117 = distinct !DILocation(line: 11, column: 1, scope: !102, inlinedAt: !103)
!118 = !DILocation(line: 12, column: 25, scope: !116, inlinedAt: !117)
!119 = !DILocation(line: 12, column: 5, scope: !116, inlinedAt: !117)
!120 = !DILocation(line: 12, column: 28, scope: !116, inlinedAt: !117)
!121 = !DILocation(line: 12, column: 10, scope: !116, inlinedAt: !117)
!122 = !DILocation(line: 12, column: 37, scope: !116, inlinedAt: !117)
!123 = !DILocation(line: 12, column: 39, scope: !116, inlinedAt: !117)
!124 = !DILocation(line: 14, column: 9, scope: !116, inlinedAt: !117)
!125 = !DILocation(line: 15, column: 5, scope: !116, inlinedAt: !117)
!126 = !DILocation(line: 11, column: 65, scope: !102, inlinedAt: !103)
!127 = !DILocation(line: 15, column: 5, scope: !93)
!128 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l16", scope: !1, file: !1, line: 16, type: !17, scopeLine: 16, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!129 = !DILocation(line: 16, column: 1, scope: !128)
!130 = !{!131}
!131 = distinct !{!131, !132, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.5: %.global_tid."}
!132 = distinct !{!132, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.5"}
!133 = !{!134}
!134 = distinct !{!134, !132, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined.5: %.bound_tid."}
!135 = !{!131, !134}
!136 = !DILocation(line: 16, column: 1, scope: !137, inlinedAt: !138)
!137 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined", scope: !1, file: !1, line: 16, type: !17, scopeLine: 16, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!138 = distinct !DILocation(line: 16, column: 1, scope: !128)
!139 = !DILocation(line: 17, column: 25, scope: !137, inlinedAt: !138)
!140 = !DILocation(line: 17, column: 5, scope: !137, inlinedAt: !138)
!141 = !DILocation(line: 17, column: 28, scope: !137, inlinedAt: !138)
!142 = !DILocation(line: 17, column: 10, scope: !137, inlinedAt: !138)
!143 = distinct !{}
!144 = !{!145}
!145 = distinct !{!145, !146, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6: %.global_tid."}
!146 = distinct !{!146, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6"}
!147 = !{!148}
!148 = distinct !{!148, !146, !"__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined.6: %.bound_tid."}
!149 = !{!145, !148}
!150 = !DILocation(line: 16, column: 1, scope: !151, inlinedAt: !152)
!151 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc00c07e_main_l16_omp_outlined_omp_outlined", scope: !1, file: !1, line: 16, type: !17, scopeLine: 16, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !0)
!152 = distinct !DILocation(line: 16, column: 1, scope: !137, inlinedAt: !138)
!153 = !DILocation(line: 17, column: 25, scope: !151, inlinedAt: !152)
!154 = !DILocation(line: 17, column: 5, scope: !151, inlinedAt: !152)
!155 = !DILocation(line: 17, column: 28, scope: !151, inlinedAt: !152)
!156 = !DILocation(line: 17, column: 10, scope: !151, inlinedAt: !152)
!157 = !DILocation(line: 17, column: 37, scope: !151, inlinedAt: !152)
!158 = !DILocation(line: 17, column: 39, scope: !151, inlinedAt: !152)
!159 = !DILocation(line: 19, column: 9, scope: !151, inlinedAt: !152)
!160 = !DILocation(line: 20, column: 5, scope: !151, inlinedAt: !152)
!161 = !DILocation(line: 16, column: 94, scope: !137, inlinedAt: !138)
!162 = !DILocation(line: 20, column: 5, scope: !128)
