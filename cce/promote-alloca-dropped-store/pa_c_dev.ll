; ModuleID = '_pc.bc'
source_filename = "pa_c.c"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

@__omp_rtl_debug_kind = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0
@__omp_rtl_assume_teams_oversubscription = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0
@__omp_rtl_assume_threads_oversubscription = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0
@__omp_rtl_assume_no_thread_state = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0
@__omp_rtl_assume_no_nested_parallelism = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0
@__omp_offloading_8116438_fc0130d3_main_l9_exec_mode = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc0130d3_main_l9_cray$kerninfo_onelevel" = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc0130d3_main_l9_cray$kerninfo_onelevel_comb" = weak addrspace(1) constant i8 0
@"__omp_offloading_8116438_fc0130d3_main_l9_cray$kerninfo_has_noloop_version" = weak addrspace(1) constant i8 0
@__oclc_ABI_version = external local_unnamed_addr addrspace(4) global i32
@"__omp_offloading_8116438_fc0130d3_main_l9_cray$remove_dyn_ptr" = weak addrspace(1) constant i8 1
@"__omp_offloading_8116438_fc0130d3_main_l9_cce$noloop$form_cray$remove_dyn_ptr" = weak addrspace(1) constant i8 1
@llvm.used = appending addrspace(1) global [6 x ptr] [ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc0130d3_main_l9_cce$noloop$form_cray$remove_dyn_ptr" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc0130d3_main_l9_cray$kerninfo_has_noloop_version" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc0130d3_main_l9_cray$kerninfo_onelevel" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc0130d3_main_l9_cray$kerninfo_onelevel_comb" to ptr), ptr addrspacecast (ptr addrspace(1) @"__omp_offloading_8116438_fc0130d3_main_l9_cray$remove_dyn_ptr" to ptr), ptr addrspacecast (ptr addrspace(1) @__omp_offloading_8116438_fc0130d3_main_l9_exec_mode to ptr)], section "llvm.metadata"

; Function Attrs: alwaysinline norecurse nounwind
define weak_odr protected amdgpu_kernel void @__omp_offloading_8116438_fc0130d3_main_l9(i64 noundef %n, ptr noundef nonnull align 4 dereferenceable(256) %out) local_unnamed_addr #0 !dbg !14 {
entry:
  %0 = addrspacecast ptr %out to ptr addrspace(1)
  %idx.i = alloca [3 x i32], align 4, addrspace(5)
  %1 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !17
  %2 = load i32, ptr addrspace(4) @__oclc_ABI_version, align 4, !dbg !17
  %3 = icmp sgt i32 %2, 499, !dbg !17
  %4 = tail call align 8 dereferenceable(256) ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr(), !dbg !17
  %5 = getelementptr inbounds nuw i8, ptr addrspace(4) %4, i64 12, !dbg !17
  %6 = tail call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !17
  %7 = getelementptr inbounds nuw i8, ptr addrspace(4) %6, i64 4, !dbg !17
  %8 = select i1 %3, ptr addrspace(4) %5, ptr addrspace(4) %7, !dbg !17
  %9 = load i16, ptr addrspace(4) %8, align 4, !dbg !17, !range !20, !invariant.load !16, !noundef !16
  %conv.i1 = zext nneg i16 %9 to i32, !dbg !17
  %10 = mul i32 %1, %conv.i1, !dbg !17
  %11 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !17
  %add.i = add i32 %11, %10, !dbg !17
  %12 = getelementptr inbounds nuw i8, ptr addrspace(4) %6, i64 12, !dbg !17
  %13 = load i32, ptr addrspace(4) %12, align 4, !dbg !17, !range !21, !invariant.load !16
  %invariant.gep = getelementptr i8, ptr addrspace(5) %idx.i, i32 -4, !dbg !17
  %n.tr = trunc i64 %n to i32
  %14 = shl i32 %n.tr, 2
  %gep = getelementptr i8, ptr addrspace(5) %invariant.gep, i32 %14
  br label %omp.dispatch.cond.i, !dbg !17

omp.dispatch.cond.i:                              ; preds = %omp.inner.for.body.i, %entry
  %.omp.comb.ub.0.i = phi i32 [ %add.i, %entry ], [ %19, %omp.inner.for.body.i ], !dbg !22
  %.omp.comb.lb.0.i = phi i32 [ %add.i, %entry ], [ %18, %omp.inner.for.body.i ], !dbg !22
  %cond.i = tail call i32 @llvm.smin.i32(i32 %.omp.comb.ub.0.i, i32 63), !dbg !23
  %cmp1.not.i = icmp sgt i32 %.omp.comb.lb.0.i, %cond.i, !dbg !24, !cray.depth !25
  br i1 %cmp1.not.i, label %__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined.exit, label %omp.inner.for.body.i, !dbg !17, !cray.depth !25

omp.inner.for.body.i:                             ; preds = %omp.dispatch.cond.i
  call void @llvm.lifetime.start.p5(i64 12, ptr addrspace(5) %idx.i) #4, !dbg !26, !cray.depth !25
  call void @llvm.memset.p5.i64(ptr addrspace(5) noundef align 4 dereferenceable(12) %idx.i, i8 0, i64 12, i1 false), !dbg !29
  %15 = mul i32 %.omp.comb.lb.0.i, 5, !dbg !30
  %16 = add i32 %15, 5, !dbg !30
  store i32 %16, ptr addrspace(5) %gep, align 4, !dbg !31, !tbaa !32, !cray.depth !25
  %17 = load i32, ptr addrspace(5) %idx.i, align 4, !dbg !36, !tbaa !32, !cray.depth !25
  %idxprom.i = sext i32 %.omp.comb.lb.0.i to i64, !dbg !37
  %arrayidx7.i = getelementptr inbounds [64 x i32], ptr addrspace(1) %0, i64 0, i64 %idxprom.i, !dbg !37
  store i32 %17, ptr addrspace(1) %arrayidx7.i, align 4, !dbg !38, !tbaa !32, !cray.depth !25
  call void @llvm.lifetime.end.p5(i64 12, ptr addrspace(5) %idx.i) #4, !dbg !39, !cray.depth !25
  %18 = add i32 %13, %.omp.comb.lb.0.i, !dbg !24
  %19 = add i32 %13, %cond.i, !dbg !24
  br label %omp.dispatch.cond.i, !dbg !40

__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined.exit: ; preds = %omp.dispatch.cond.i
  ret void, !dbg !41
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p5(i64 immarg, ptr addrspace(5) captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p5(i64 immarg, ptr addrspace(5) captures(none)) #1

; Function Attrs: alwaysinline norecurse nounwind
define weak_odr protected amdgpu_kernel void @"__omp_offloading_8116438_fc0130d3_main_l9_cce$noloop$form"(i64 noundef %n, ptr noundef nonnull align 4 dereferenceable(256) %out) local_unnamed_addr #0 !dbg !42 {
entry:
  %0 = addrspacecast ptr %out to ptr addrspace(1)
  %idx.i = alloca [3 x i32], align 4, addrspace(5)
  %1 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !43
  %2 = load i32, ptr addrspace(4) @__oclc_ABI_version, align 4, !dbg !43
  %3 = icmp sgt i32 %2, 499, !dbg !43
  %4 = tail call align 8 dereferenceable(256) ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr(), !dbg !43
  %5 = getelementptr inbounds nuw i8, ptr addrspace(4) %4, i64 12, !dbg !43
  %6 = tail call align 4 dereferenceable(64) ptr addrspace(4) @llvm.amdgcn.dispatch.ptr(), !dbg !43
  %7 = getelementptr inbounds nuw i8, ptr addrspace(4) %6, i64 4, !dbg !43
  %8 = select i1 %3, ptr addrspace(4) %5, ptr addrspace(4) %7, !dbg !43
  %9 = load i16, ptr addrspace(4) %8, align 4, !dbg !43, !range !20, !invariant.load !16, !noundef !16
  %conv.i1 = zext nneg i16 %9 to i32, !dbg !43
  %10 = mul i32 %1, %conv.i1, !dbg !43
  %11 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !43
  %add.i = add i32 %11, %10, !dbg !43
  %cmp1.not.i = icmp sgt i32 %add.i, 63, !dbg !46
  br i1 %cmp1.not.i, label %__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined.2.exit, label %omp.inner.for.body.i, !dbg !43, !cray.depth !25

omp.inner.for.body.i:                             ; preds = %entry
  call void @llvm.lifetime.start.p5(i64 12, ptr addrspace(5) %idx.i) #4, !dbg !47, !cray.depth !25
  call void @llvm.memset.p5.i64(ptr addrspace(5) noundef align 4 dereferenceable(12) %idx.i, i8 0, i64 12, i1 false), !dbg !50
  %n.tr = trunc i64 %n to i32, !dbg !51
  %12 = shl i32 %n.tr, 2, !dbg !51
  %add.ptr.i = getelementptr inbounds i8, ptr addrspace(5) %idx.i, i32 %12, !dbg !51
  %add.ptr4.i = getelementptr inbounds i8, ptr addrspace(5) %add.ptr.i, i32 -4, !dbg !52
  %13 = mul i32 %add.i, 5, !dbg !53
  %14 = add i32 %13, 5, !dbg !53
  store i32 %14, ptr addrspace(5) %add.ptr4.i, align 4, !dbg !54, !tbaa !32, !cray.depth !25
  %15 = load i32, ptr addrspace(5) %idx.i, align 4, !dbg !55, !tbaa !32, !cray.depth !25
  %idxprom.i = sext i32 %add.i to i64, !dbg !56
  %arrayidx7.i = getelementptr inbounds [64 x i32], ptr addrspace(1) %0, i64 0, i64 %idxprom.i, !dbg !56
  store i32 %15, ptr addrspace(1) %arrayidx7.i, align 4, !dbg !57, !tbaa !32, !cray.depth !25
  call void @llvm.lifetime.end.p5(i64 12, ptr addrspace(5) %idx.i) #4, !dbg !58, !cray.depth !25
  br label %__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined.2.exit, !dbg !59

__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined.2.exit: ; preds = %entry, %omp.inner.for.body.i
  ret void, !dbg !60
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef nonnull align 4 ptr addrspace(4) @llvm.amdgcn.dispatch.ptr() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef align 4 ptr addrspace(4) @llvm.amdgcn.implicitarg.ptr() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #2

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #2

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p5.i64(ptr addrspace(5) writeonly captures(none), i8, i64, i1 immarg) #3

attributes #0 = { alwaysinline norecurse nounwind "amdgpu-agpr-alloc"="0" "amdgpu-flat-work-group-size"="1,1024" "amdgpu-no-completion-action" "amdgpu-no-default-queue" "amdgpu-no-dispatch-id" "amdgpu-no-flat-scratch-init" "amdgpu-no-heap-ptr" "amdgpu-no-hostcall-ptr" "amdgpu-no-lds-kernel-id" "amdgpu-no-multigrid-sync-arg" "amdgpu-no-queue-ptr" "amdgpu-no-workgroup-id-x" "amdgpu-no-workgroup-id-y" "amdgpu-no-workgroup-id-z" "amdgpu-no-workitem-id-x" "amdgpu-no-workitem-id-y" "amdgpu-no-workitem-id-z" "amdgpu-waves-per-eu"="4,8" "kernel" "no-trapping-math"="true" "omp_target_thread_limit"="1024" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" "uniform-work-group-size"="true" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #4 = { nounwind }

!llvm.dbg.cu = !{!0}
!omp_offload.info = !{!2}
!llvm.module.flags = !{!3, !4, !5, !6, !7, !8, !9, !10}
!opencl.ocl.version = !{!11}
!llvm.ident = !{!12, !13}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "Cray clang version 21.0.2  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)", isOptimized: true, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "pa_c.c", directory: "/lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/promote-alloca-dropped-store")
!2 = !{i32 0, i32 135357496, i32 -67030829, !"main", i32 9, i32 0, i32 0}
!3 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = !{i32 1, !"wchar_size", i32 4}
!6 = !{i32 7, !"openmp", i32 51}
!7 = !{i32 7, !"openmp-device", i32 51}
!8 = !{i32 8, !"PIC Level", i32 2}
!9 = !{i32 1, !"ThinLTO", i32 0}
!10 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!11 = !{i32 2, i32 0}
!12 = !{!"Cray clang version 21.0.2  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!13 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!14 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc0130d3_main_l9", scope: !1, file: !1, line: 9, type: !15, scopeLine: 9, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!15 = !DISubroutineType(types: !16)
!16 = !{}
!17 = !DILocation(line: 9, column: 1, scope: !18, inlinedAt: !19)
!18 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined", scope: !1, file: !1, line: 9, type: !15, scopeLine: 9, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!19 = distinct !DILocation(line: 9, column: 1, scope: !14)
!20 = !{i16 1, i16 1025}
!21 = !{i32 1, i32 0}
!22 = !DILocation(line: 0, scope: !18, inlinedAt: !19)
!23 = !DILocation(line: 10, column: 10, scope: !18, inlinedAt: !19)
!24 = !DILocation(line: 10, column: 5, scope: !18, inlinedAt: !19)
!25 = !{i32 1}
!26 = !DILocation(line: 11, column: 9, scope: !27, inlinedAt: !28)
!27 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined_omp_outlined", scope: !1, file: !1, line: 9, type: !15, scopeLine: 9, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!28 = distinct !DILocation(line: 9, column: 1, scope: !18, inlinedAt: !19)
!29 = !DILocation(line: 11, column: 13, scope: !27, inlinedAt: !28)
!30 = !DILocation(line: 14, column: 16, scope: !27, inlinedAt: !28)
!31 = !DILocation(line: 14, column: 12, scope: !27, inlinedAt: !28)
!32 = !{!33, !33, i64 0}
!33 = !{!"int", !34, i64 0}
!34 = !{!"omnipotent char", !35, i64 0}
!35 = !{!"Simple C/C++ TBAA"}
!36 = !DILocation(line: 15, column: 18, scope: !27, inlinedAt: !28)
!37 = !DILocation(line: 15, column: 9, scope: !27, inlinedAt: !28)
!38 = !DILocation(line: 15, column: 16, scope: !27, inlinedAt: !28)
!39 = !DILocation(line: 16, column: 5, scope: !27, inlinedAt: !28)
!40 = !DILocation(line: 9, column: 88, scope: !18, inlinedAt: !19)
!41 = !DILocation(line: 16, column: 5, scope: !14)
!42 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc0130d3_main_l9", scope: !1, file: !1, line: 9, type: !15, scopeLine: 9, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!43 = !DILocation(line: 9, column: 1, scope: !44, inlinedAt: !45)
!44 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined", scope: !1, file: !1, line: 9, type: !15, scopeLine: 9, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!45 = distinct !DILocation(line: 9, column: 1, scope: !42)
!46 = !DILocation(line: 10, column: 5, scope: !44, inlinedAt: !45)
!47 = !DILocation(line: 11, column: 9, scope: !48, inlinedAt: !49)
!48 = distinct !DISubprogram(name: "__omp_offloading_8116438_fc0130d3_main_l9_omp_outlined_omp_outlined", scope: !1, file: !1, line: 9, type: !15, scopeLine: 9, flags: DIFlagArtificial | DIFlagPrototyped, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!49 = distinct !DILocation(line: 9, column: 1, scope: !44, inlinedAt: !45)
!50 = !DILocation(line: 11, column: 13, scope: !48, inlinedAt: !49)
!51 = !DILocation(line: 12, column: 22, scope: !48, inlinedAt: !49)
!52 = !DILocation(line: 13, column: 36, scope: !48, inlinedAt: !49)
!53 = !DILocation(line: 14, column: 16, scope: !48, inlinedAt: !49)
!54 = !DILocation(line: 14, column: 12, scope: !48, inlinedAt: !49)
!55 = !DILocation(line: 15, column: 18, scope: !48, inlinedAt: !49)
!56 = !DILocation(line: 15, column: 9, scope: !48, inlinedAt: !49)
!57 = !DILocation(line: 15, column: 16, scope: !48, inlinedAt: !49)
!58 = !DILocation(line: 16, column: 5, scope: !48, inlinedAt: !49)
!59 = !DILocation(line: 9, column: 88, scope: !44, inlinedAt: !45)
!60 = !DILocation(line: 16, column: 5, scope: !42)
