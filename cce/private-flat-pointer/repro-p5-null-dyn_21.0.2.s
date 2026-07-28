	.amdgcn_target "amdgcn-amd-amdhsa--gfx90a"
	.amdhsa_code_object_version 6
	.text
	.globl	k                               ; -- Begin function k
	.p2align	8
	.type	k,@function
k:                                      ; @k
; %bb.0:                                ; %entry
	s_load_dwordx4 s[4:7], s[8:9], 0x0
	s_add_u32 s0, s0, s17
	s_addc_u32 s1, s1, 0
	v_mov_b32_e32 v0, 0x3ff00000
	v_mov_b32_e32 v2, 0
	s_waitcnt lgkmcnt(0)
	s_lshl_b64 s[6:7], s[6:7], 3
	s_add_u32 s6, 0, s6
	s_addc_u32 s7, 0, s7
	s_cmp_lg_u64 s[6:7], 0
	s_cselect_b32 s6, s6, -1
	v_mov_b32_e32 v1, s6
	buffer_store_dword v0, v1, s[0:3], 0 offen offset:4
	buffer_store_dword v2, v1, s[0:3], 0 offen
	buffer_load_dword v0, off, s[0:3], 0 glc
	s_waitcnt vmcnt(0)
	buffer_load_dword v1, off, s[0:3], 0 offset:4 glc
	s_waitcnt vmcnt(0)
	global_store_dwordx2 v2, v[0:1], s[4:5]
	s_endpgm
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0
	.amdhsa_kernel k
		.amdhsa_group_segment_fixed_size 0
		.amdhsa_private_segment_fixed_size 96
		.amdhsa_kernarg_size 272
		.amdhsa_user_sgpr_count 14
		.amdhsa_user_sgpr_private_segment_buffer 1
		.amdhsa_user_sgpr_dispatch_ptr 1
		.amdhsa_user_sgpr_queue_ptr 1
		.amdhsa_user_sgpr_kernarg_segment_ptr 1
		.amdhsa_user_sgpr_dispatch_id 1
		.amdhsa_user_sgpr_flat_scratch_init 1
		.amdhsa_user_sgpr_kernarg_preload_length 0
		.amdhsa_user_sgpr_kernarg_preload_offset 0
		.amdhsa_user_sgpr_private_segment_size 0
		.amdhsa_uses_dynamic_stack 0
		.amdhsa_system_sgpr_private_segment_wavefront_offset 1
		.amdhsa_system_sgpr_workgroup_id_x 1
		.amdhsa_system_sgpr_workgroup_id_y 1
		.amdhsa_system_sgpr_workgroup_id_z 1
		.amdhsa_system_sgpr_workgroup_info 0
		.amdhsa_system_vgpr_workitem_id 2
		.amdhsa_next_free_vgpr 3
		.amdhsa_next_free_sgpr 18
		.amdhsa_accum_offset 4
		.amdhsa_reserve_vcc 0
		.amdhsa_reserve_flat_scratch 0
		.amdhsa_float_round_mode_32 0
		.amdhsa_float_round_mode_16_64 0
		.amdhsa_float_denorm_mode_32 3
		.amdhsa_float_denorm_mode_16_64 3
		.amdhsa_dx10_clamp 1
		.amdhsa_ieee_mode 1
		.amdhsa_fp16_overflow 0
		.amdhsa_tg_split 0
		.amdhsa_exception_fp_ieee_invalid_op 0
		.amdhsa_exception_fp_denorm_src 0
		.amdhsa_exception_fp_ieee_div_zero 0
		.amdhsa_exception_fp_ieee_overflow 0
		.amdhsa_exception_fp_ieee_underflow 0
		.amdhsa_exception_fp_ieee_inexact 0
		.amdhsa_exception_int_div_zero 0
	.end_amdhsa_kernel
	.text
.Lfunc_end0:
	.size	k, .Lfunc_end0-k
                                        ; -- End function
	.set k.num_vgpr, 3
	.set k.num_agpr, 0
	.set k.numbered_sgpr, 18
	.set k.private_seg_size, 96
	.set k.uses_vcc, 0
	.set k.uses_flat_scratch, 0
	.set k.has_dyn_sized_stack, 0
	.set k.has_recursion, 0
	.set k.has_indirect_call, 0
	.section	.AMDGPU.csdata,"",@progbits
; Kernel info:
; codeLenInByte = 108
; TotalNumSgprs: 22
; NumVgprs: 3
; NumAgprs: 0
; TotalNumVgprs: 3
; ScratchSize: 96
; MemoryBound: 0
; FloatMode: 240
; IeeeMode: 1
; LDSByteSize: 0 bytes/workgroup (compile time only)
; SGPRBlocks: 2
; VGPRBlocks: 0
; NumSGPRsForWavesPerEU: 22
; NumVGPRsForWavesPerEU: 3
; AccumOffset: 4
; Occupancy: 8
; WaveLimiterHint : 0
; COMPUTE_PGM_RSRC2:SCRATCH_EN: 1
; COMPUTE_PGM_RSRC2:USER_SGPR: 14
; COMPUTE_PGM_RSRC2:TRAP_HANDLER: 0
; COMPUTE_PGM_RSRC2:TGID_X_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Y_EN: 1
; COMPUTE_PGM_RSRC2:TGID_Z_EN: 1
; COMPUTE_PGM_RSRC2:TIDIG_COMP_CNT: 2
; COMPUTE_PGM_RSRC3_GFX90A:ACCUM_OFFSET: 0
; COMPUTE_PGM_RSRC3_GFX90A:TG_SPLIT: 0
	.text
	.p2alignl 6, 3212836864
	.fill 256, 4, 3212836864
	.section	.AMDGPU.gpr_maximums,"",@progbits
	.set amdgpu.max_num_vgpr, 0
	.set amdgpu.max_num_agpr, 0
	.set amdgpu.max_num_sgpr, 0
	.text
	.section	".note.GNU-stack","",@progbits
	.amdgpu_metadata
---
amdhsa.kernels:
  - .agpr_count:     0
    .args:
      - .address_space:  global
        .name:           out
        .offset:         0
        .size:           8
        .value_kind:     global_buffer
      - .name:           idx
        .offset:         8
        .size:           8
        .value_kind:     by_value
      - .offset:         16
        .size:           4
        .value_kind:     hidden_block_count_x
      - .offset:         20
        .size:           4
        .value_kind:     hidden_block_count_y
      - .offset:         24
        .size:           4
        .value_kind:     hidden_block_count_z
      - .offset:         28
        .size:           2
        .value_kind:     hidden_group_size_x
      - .offset:         30
        .size:           2
        .value_kind:     hidden_group_size_y
      - .offset:         32
        .size:           2
        .value_kind:     hidden_group_size_z
      - .offset:         34
        .size:           2
        .value_kind:     hidden_remainder_x
      - .offset:         36
        .size:           2
        .value_kind:     hidden_remainder_y
      - .offset:         38
        .size:           2
        .value_kind:     hidden_remainder_z
      - .offset:         56
        .size:           8
        .value_kind:     hidden_global_offset_x
      - .offset:         64
        .size:           8
        .value_kind:     hidden_global_offset_y
      - .offset:         72
        .size:           8
        .value_kind:     hidden_global_offset_z
      - .offset:         80
        .size:           2
        .value_kind:     hidden_grid_dims
      - .offset:         96
        .size:           8
        .value_kind:     hidden_hostcall_buffer
      - .offset:         104
        .size:           8
        .value_kind:     hidden_multigrid_sync_arg
      - .offset:         112
        .size:           8
        .value_kind:     hidden_heap_v1
      - .offset:         120
        .size:           8
        .value_kind:     hidden_default_queue
      - .offset:         128
        .size:           8
        .value_kind:     hidden_completion_action
      - .offset:         216
        .size:           8
        .value_kind:     hidden_queue_ptr
    .group_segment_fixed_size: 0
    .kernarg_segment_align: 8
    .kernarg_segment_size: 272
    .max_flat_workgroup_size: 256
    .name:           k
    .private_segment_fixed_size: 96
    .sgpr_count:     22
    .sgpr_spill_count: 0
    .symbol:         k.kd
    .uses_dynamic_stack: false
    .vgpr_count:     3
    .vgpr_spill_count: 0
    .wavefront_size: 64
amdhsa.target:   amdgcn-amd-amdhsa--gfx90a
amdhsa.version:
  - 1
  - 2
...

	.end_amdgpu_metadata
