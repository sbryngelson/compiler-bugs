; ModuleID = '_x.bc'
source_filename = "The Accel Module"
target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

@bare__cray_acc = common addrspace(1) global [15 x i64] zeroinitializer, align 32
@bitcasted_bare__cray_acc = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@dalloc__cray_acc = common addrspace(1) global [15 x i64] zeroinitializer, align 32
@bitcasted_dalloc__cray_acc = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@dptr__cray_acc = addrspace(1) global [15 x i64] [i64 0, i64 32, i64 216172782113849476, i64 562958543355914, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0, i64 0], align 32
@bitcasted_dptr__cray_acc = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc
@bitcasted_bare__cray_acc.1 = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@bitcasted_dalloc__cray_acc.2 = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@bitcasted_dptr__cray_acc.3 = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc
@bitcasted_bare__cray_acc.4 = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@bitcasted_dalloc__cray_acc.5 = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@bitcasted_dptr__cray_acc.6 = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc
@bitcasted_bare__cray_acc.7 = private addrspace(1) global ptr addrspace(1) @bare__cray_acc
@bitcasted_dalloc__cray_acc.8 = private addrspace(1) global ptr addrspace(1) @dalloc__cray_acc
@bitcasted_dptr__cray_acc.9 = private addrspace(1) global ptr addrspace(1) @dptr__cray_acc

; Function Attrs: noinline
define amdgpu_kernel void @"resident_$ck_L45_1"(i64 %"$$arg_ptr_acc_d1_t96_t1871") #0 !dbg !16 !scalarlevel !19 !cachelevel !20 !fplevel !19 {
", bb98":
  br label %"file resident_bare.f90, line 45, bb99", !dbg !21

"file resident_bare.f90, line 45, bb99":          ; preds = %", bb98"
  br label %"file resident_bare.f90, line 46, bb100", !dbg !21

"file resident_bare.f90, line 46, bb100":         ; preds = %"file resident_bare.f90, line 45, bb99"
  %r = tail call i64 @__ockl_get_local_size(i32 0), !dbg !22
  %r2 = trunc i64 %r to i32, !dbg !22
  %r3 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !22
  %r4 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !22
  %r5 = mul i32 %r3, %r2, !dbg !22
  %r6 = add i32 %r4, %r5, !dbg !22
  %r7 = zext i32 %r6 to i64, !dbg !22
  %r9 = icmp ugt i32 %r6, 4912, !dbg !22
  br i1 %r9, label %"file resident_bare.f90, line 51, bb105", label %"46utop3", !dbg !22

"46utop3":                                        ; preds = %"file resident_bare.f90, line 46, bb100"
  br label %"file resident_bare.f90, line 46, bb102", !dbg !22

"file resident_bare.f90, line 46, bb102":         ; preds = %"46utop3"
  %r13 = udiv i64 %r7, 289, !dbg !22
  %r15 = mul nsw i64 %r13, -289, !dbg !22
  %r18 = add nsw i64 %r7, %r15, !dbg !22
  %r20 = sdiv i64 %r18, 17, !dbg !22
  %r21 = load ptr addrspace(1), ptr addrspace(1) @dptr__cray_acc, align 8, !dbg !23, !CrayMri !24
  %r22 = ptrtoint ptr addrspace(1) %r21 to i64, !dbg !23
  %r23 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 88), align 8, !dbg !23, !CrayMri !25
  %r25 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 72), align 8, !dbg !23, !CrayMri !26
  %r26 = sub i64 %r20, %r25, !dbg !23
  %r27 = mul i64 %r23, %r26, !dbg !23
  %r28 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 112), align 8, !dbg !23, !CrayMri !27
  %r30 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 96), align 8, !dbg !23, !CrayMri !28
  %r31 = sub i64 %r13, %r30, !dbg !23
  %r32 = mul i64 %r28, %r31, !dbg !23
  %r34 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 64), align 8, !dbg !23, !CrayMri !29
  %r36 = mul nsw i64 %r20, -17, !dbg !23
  %r38 = add nsw i64 %r18, %r36, !dbg !23
  %r39 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dptr__cray_acc, i64 48), align 8, !dbg !23, !CrayMri !30
  %r39.neg = sub i64 0, %r39, !dbg !23
  %r40 = add i64 %r38, %r39.neg, !dbg !23
  %r41 = mul i64 %r34, %r40, !dbg !23
  %r43 = inttoptr i64 %r22 to ptr, !dbg !23
  %0 = getelementptr i32, ptr %r43, i64 %r27, !dbg !23
  %1 = getelementptr i32, ptr %0, i64 %r32, !dbg !23
  %r44 = getelementptr i32, ptr %1, i64 %r41, !dbg !23
  %r45 = addrspacecast ptr %r44 to ptr addrspace(1), !dbg !23
  %r46 = load i32, ptr addrspace(1) %r45, align 4, !dbg !23, !CrayMri !31
  %r47 = icmp eq i32 %r46, 0, !dbg !23
  br i1 %r47, label %"file resident_bare.f90, line 51, bb105", label %", bb103", !dbg !23

", bb103":                                        ; preds = %"file resident_bare.f90, line 46, bb102"
  br label %"file resident_bare.f90, line 48, bb104", !dbg !23

"file resident_bare.f90, line 48, bb104":         ; preds = %", bb103"
  %r51 = inttoptr i64 %"$$arg_ptr_acc_d1_t96_t1871" to ptr addrspace(1), !dbg !32
  %2 = atomicrmw add ptr addrspace(1) %r51, i32 1 syncscope("agent") monotonic, align 4, !dbg !32
  br label %"file resident_bare.f90, line 51, bb105", !dbg !32

"file resident_bare.f90, line 51, bb105":         ; preds = %"file resident_bare.f90, line 48, bb104", %"file resident_bare.f90, line 46, bb102", %"file resident_bare.f90, line 46, bb100"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !33
  br label %"file resident_bare.f90, line 51, bb106", !dbg !33

"file resident_bare.f90, line 51, bb106":         ; preds = %"file resident_bare.f90, line 51, bb105"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !33
  br label %"file resident_bare.f90, line 51, bb107", !dbg !33

"file resident_bare.f90, line 51, bb107":         ; preds = %"file resident_bare.f90, line 51, bb106"
  ret void, !dbg !33
}

declare hidden i64 @__ockl_get_local_size(i32)

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef i32 @llvm.amdgcn.workgroup.id.x() #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare noundef range(i32 0, 1024) i32 @llvm.amdgcn.workitem.id.x() #1

; Function Attrs: convergent nocallback nofree nounwind willreturn
declare void @llvm.amdgcn.s.barrier() #2

; Function Attrs: noinline
define amdgpu_kernel void @"resident_$ck_L53_4"(i64 %"$$arg_ptr_acc_d2_t98_t1881") #0 !dbg !34 !scalarlevel !19 !cachelevel !20 !fplevel !19 {
", bb109":
  br label %"file resident_bare.f90, line 53, bb110", !dbg !35

"file resident_bare.f90, line 53, bb110":         ; preds = %", bb109"
  br label %"file resident_bare.f90, line 54, bb111", !dbg !35

"file resident_bare.f90, line 54, bb111":         ; preds = %"file resident_bare.f90, line 53, bb110"
  %r = tail call i64 @__ockl_get_local_size(i32 0), !dbg !36
  %r2 = trunc i64 %r to i32, !dbg !36
  %r3 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !36
  %r4 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !36
  %r5 = mul i32 %r3, %r2, !dbg !36
  %r6 = add i32 %r4, %r5, !dbg !36
  %r7 = zext i32 %r6 to i64, !dbg !36
  %r9 = icmp ugt i32 %r6, 4912, !dbg !36
  br i1 %r9, label %"file resident_bare.f90, line 59, bb116", label %"54utop3", !dbg !36

"54utop3":                                        ; preds = %"file resident_bare.f90, line 54, bb111"
  br label %"file resident_bare.f90, line 54, bb113", !dbg !36

"file resident_bare.f90, line 54, bb113":         ; preds = %"54utop3"
  %r13 = udiv i64 %r7, 289, !dbg !36
  %r16 = mul nsw i64 %r13, -289, !dbg !36
  %r17 = add nsw i64 %r7, %r16, !dbg !36
  %r19 = sdiv i64 %r17, 17, !dbg !36
  %r20 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 88), align 8, !dbg !37, !CrayMri !38
  %r21 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 112), align 8, !dbg !37, !CrayMri !39
  %r22 = load ptr addrspace(1), ptr addrspace(1) @dalloc__cray_acc, align 8, !dbg !37, !CrayMri !40
  %r23 = ptrtoint ptr addrspace(1) %r22 to i64, !dbg !37
  %r26 = add i64 %r21, -289, !dbg !37
  %r27 = mul i64 %r13, %r26, !dbg !37
  %r29 = add i64 %r7, %r27, !dbg !37
  %r30 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 72), align 8, !dbg !37, !CrayMri !41
  %r32 = mul i64 %r20, %r30, !dbg !37
  %r32.neg = mul i64 %r32, -1, !dbg !37
  %r33 = add i64 %r29, %r32.neg, !dbg !37
  %r36 = add i64 %r20, -17, !dbg !37
  %r37 = mul i64 %r19, %r36, !dbg !37
  %r38 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 48), align 8, !dbg !37, !CrayMri !42
  %r40 = load i64, ptr addrspace(1) getelementptr inbounds nuw (i8, ptr addrspace(1) @dalloc__cray_acc, i64 96), align 8, !dbg !37, !CrayMri !43
  %r42 = mul i64 %r21, %r40, !dbg !37
  %r38.neg = sub i64 0, %r38, !dbg !37
  %r42.neg = mul i64 %r42, -1, !dbg !37
  %.neg = add i64 %r38.neg, %r42.neg, !dbg !37
  %r43 = add i64 %r37, %.neg, !dbg !37
  %r45 = inttoptr i64 %r23 to ptr, !dbg !37
  %0 = getelementptr i32, ptr %r45, i64 %r33, !dbg !37
  %r46 = getelementptr i32, ptr %0, i64 %r43, !dbg !37
  %r47 = addrspacecast ptr %r46 to ptr addrspace(1), !dbg !37
  %r48 = load i32, ptr addrspace(1) %r47, align 4, !dbg !37, !CrayMri !44
  %r49 = icmp eq i32 %r48, 0, !dbg !37
  br i1 %r49, label %"file resident_bare.f90, line 59, bb116", label %", bb114", !dbg !37

", bb114":                                        ; preds = %"file resident_bare.f90, line 54, bb113"
  br label %"file resident_bare.f90, line 56, bb115", !dbg !37

"file resident_bare.f90, line 56, bb115":         ; preds = %", bb114"
  %r53 = inttoptr i64 %"$$arg_ptr_acc_d2_t98_t1881" to ptr addrspace(1), !dbg !45
  %1 = atomicrmw add ptr addrspace(1) %r53, i32 1 syncscope("agent") monotonic, align 4, !dbg !45
  br label %"file resident_bare.f90, line 59, bb116", !dbg !45

"file resident_bare.f90, line 59, bb116":         ; preds = %"file resident_bare.f90, line 56, bb115", %"file resident_bare.f90, line 54, bb113", %"file resident_bare.f90, line 54, bb111"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !46
  br label %"file resident_bare.f90, line 59, bb117", !dbg !46

"file resident_bare.f90, line 59, bb117":         ; preds = %"file resident_bare.f90, line 59, bb116"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !46
  br label %"file resident_bare.f90, line 59, bb118", !dbg !46

"file resident_bare.f90, line 59, bb118":         ; preds = %"file resident_bare.f90, line 59, bb117"
  ret void, !dbg !46
}

; Function Attrs: noinline
define amdgpu_kernel void @"resident_$ck_L61_7"(i64 %"$$arg_dvmbr_p13_t1891", i64 %"$$arg_dvmbr_p15_t1902", i64 %"$$arg_dvmbr_p17_t1913", i64 %"$$arg_ptr_acc_bare_t100_t1924", i64 %"$$arg_ptr_acc_d3_t102_t1935") #0 !dbg !47 !scalarlevel !19 !cachelevel !20 !fplevel !19 {
", bb120":
  br label %"file resident_bare.f90, line 61, bb121", !dbg !48

"file resident_bare.f90, line 61, bb121":         ; preds = %", bb120"
  br label %"file resident_bare.f90, line 59, bb122", !dbg !48

"file resident_bare.f90, line 59, bb122":         ; preds = %"file resident_bare.f90, line 61, bb121"
  %r = tail call i64 @__ockl_get_local_size(i32 0), !dbg !49
  %r6 = trunc i64 %r to i32, !dbg !49
  %r7 = tail call i32 @llvm.amdgcn.workgroup.id.x(), !dbg !49
  %r8 = tail call i32 @llvm.amdgcn.workitem.id.x(), !dbg !49
  %r9 = mul i32 %r7, %r6, !dbg !49
  %r10 = add i32 %r8, %r9, !dbg !49
  %r11 = zext i32 %r10 to i64, !dbg !49
  %r13 = icmp ugt i32 %r10, 4912, !dbg !49
  br i1 %r13, label %"file resident_bare.f90, line 67, bb127", label %"62utop3", !dbg !49

"62utop3":                                        ; preds = %"file resident_bare.f90, line 59, bb122"
  br label %"file resident_bare.f90, line 62, bb124", !dbg !49

"file resident_bare.f90, line 62, bb124":         ; preds = %"62utop3"
  %r17 = udiv i64 %r11, 289, !dbg !49
  %r20 = mul nsw i64 %r17, -289, !dbg !49
  %r21 = add nsw i64 %r11, %r20, !dbg !49
  %r23 = sdiv i64 %r21, 17, !dbg !49
  %r26 = shl nsw i64 %r23, 2, !dbg !50
  %r28 = sub i64 %r26, %"$$arg_dvmbr_p13_t1891", !dbg !50
  %r40 = inttoptr i64 %"$$arg_ptr_acc_bare_t100_t1924" to ptr, !dbg !50
  %0 = getelementptr i32, ptr %r40, i64 %r28, !dbg !50
  %.idx = mul i64 %"$$arg_dvmbr_p17_t1913", -1764, !dbg !50
  %1 = getelementptr i8, ptr %0, i64 %.idx, !dbg !50
  %.idx52 = mul nuw nsw i64 %r17, 608, !dbg !50
  %2 = getelementptr i8, ptr %1, i64 %.idx52, !dbg !50
  %3 = getelementptr i32, ptr %2, i64 %r11, !dbg !50
  %r41.idx = mul i64 %"$$arg_dvmbr_p15_t1902", -84, !dbg !50
  %r41 = getelementptr i8, ptr %3, i64 %r41.idx, !dbg !50
  %r42 = addrspacecast ptr %r41 to ptr addrspace(1), !dbg !50
  %r43 = load i32, ptr addrspace(1) %r42, align 4, !dbg !50, !CrayMri !51
  %r44 = icmp eq i32 %r43, 0, !dbg !50
  br i1 %r44, label %"file resident_bare.f90, line 67, bb127", label %", bb125", !dbg !50

", bb125":                                        ; preds = %"file resident_bare.f90, line 62, bb124"
  br label %"file resident_bare.f90, line 64, bb126", !dbg !50

"file resident_bare.f90, line 64, bb126":         ; preds = %", bb125"
  %r48 = inttoptr i64 %"$$arg_ptr_acc_d3_t102_t1935" to ptr addrspace(1), !dbg !52
  %4 = atomicrmw add ptr addrspace(1) %r48, i32 1 syncscope("agent") monotonic, align 4, !dbg !52
  br label %"file resident_bare.f90, line 67, bb127", !dbg !52

"file resident_bare.f90, line 67, bb127":         ; preds = %"file resident_bare.f90, line 64, bb126", %"file resident_bare.f90, line 62, bb124", %"file resident_bare.f90, line 59, bb122"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !53
  br label %"file resident_bare.f90, line 67, bb128", !dbg !53

"file resident_bare.f90, line 67, bb128":         ; preds = %"file resident_bare.f90, line 67, bb127"
  tail call void @llvm.amdgcn.s.barrier(), !dbg !53
  br label %"file resident_bare.f90, line 67, bb129", !dbg !53

"file resident_bare.f90, line 67, bb129":         ; preds = %"file resident_bare.f90, line 67, bb128"
  ret void, !dbg !53
}

attributes #0 = { noinline "amdgpu-flat-work-group-size"="1,256" "amdgpu-no-completion-action" "kernel" "uniform-work-group-size"="true" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { convergent nocallback nofree nounwind willreturn }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8}
!llvm.dbg.cu = !{!9}
!PDGFunctionMap = !{!11}
!PDGVariableMap = !{!12, !13, !14}
!llvm.ident = !{!15, !15, !15, !15, !15, !15, !15, !15, !15}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !{i32 4, !"Dwarf Version", i32 5}
!2 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{i32 8, !"PIC Level", i32 0}
!5 = !{i32 7, !"openmp", i32 51}
!6 = !{i32 7, !"openmp-device", i32 51}
!7 = !{i32 1, !"ThinLTO", i32 0}
!8 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!9 = distinct !DICompileUnit(language: DW_LANG_Fortran90, file: !10, producer: "Cray Fortran : Version 21.0.2", isOptimized: false, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!10 = !DIFile(filename: "resident_bare.f90", directory: "/lustre/orion/cfd154/scratch/sbryngelson/compiler-bugs-repo/cce/defaultmap-zeroes-resident-arrays")
!11 = !{i32 13, !"resident_$ck_L61_7"}
!12 = !{i32 201, ptr addrspace(1) @bare__cray_acc}
!13 = !{i32 202, ptr addrspace(1) @dalloc__cray_acc}
!14 = !{i32 203, ptr addrspace(1) @dptr__cray_acc}
!15 = !{!"Cray clang version 0.0.0.0  (c3fb8a56d0f4e468a9d0387a93105d6911ac9420)"}
!16 = distinct !DISubprogram(name: "resident_$ck_L45_1", linkageName: "resident_$ck_L45_1", scope: !10, file: !10, line: 45, type: !17, scopeLine: 45, spFlags: DISPFlagDefinition, unit: !9)
!17 = !DISubroutineType(types: !18)
!18 = !{null}
!19 = !{i64 2}
!20 = !{i64 0}
!21 = !DILocation(line: 45, scope: !16)
!22 = !DILocation(line: 46, scope: !16)
!23 = !DILocation(line: 47, scope: !16)
!24 = !{i64 3977139716457}
!25 = !{i64 3955664879977}
!26 = !{i64 3972844749161}
!27 = !{i64 3959959847273}
!28 = !{i64 3968549781865}
!29 = !{i64 3951369912681}
!30 = !{i64 3964254814569}
!31 = !{i64 8254927143273}
!32 = !DILocation(line: 49, scope: !16)
!33 = !DILocation(line: 51, scope: !16)
!34 = distinct !DISubprogram(name: "resident_$ck_L53_4", linkageName: "resident_$ck_L53_4", scope: !10, file: !10, line: 53, type: !17, scopeLine: 53, spFlags: DISPFlagDefinition, unit: !9)
!35 = !DILocation(line: 53, scope: !34)
!36 = !DILocation(line: 54, scope: !34)
!37 = !DILocation(line: 55, scope: !34)
!38 = !{i64 3981434683836}
!39 = !{i64 3985729651133}
!40 = !{i64 4002909520318}
!41 = !{i64 3994319585726}
!42 = !{i64 3990024618430}
!43 = !{i64 3998614553022}
!44 = !{i64 8263517077950}
!45 = !DILocation(line: 57, scope: !34)
!46 = !DILocation(line: 59, scope: !34)
!47 = distinct !DISubprogram(name: "resident_$ck_L61_7", linkageName: "resident_$ck_L61_7", scope: !10, file: !10, line: 61, type: !17, scopeLine: 61, spFlags: DISPFlagDefinition, unit: !9)
!48 = !DILocation(line: 61, scope: !47)
!49 = !DILocation(line: 62, scope: !47)
!50 = !DILocation(line: 63, scope: !47)
!51 = !{i64 8272107012640}
!52 = !DILocation(line: 65, scope: !47)
!53 = !DILocation(line: 67, scope: !47)
