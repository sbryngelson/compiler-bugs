# CCE Fortran front end builds a flat pointer from a private offset without the aperture

> **Severity:** **Silent wrong answers / fault**  
> **Fix belongs to:** CCE front end (LLVM is correct)  
> **Status:** Root-caused: private->flat conversion via `ptrtoint`/`zext`/`inttoptr` drops the scratch aperture, making offset 0 indistinguishable from null.

## Summary

The Cray Fortran front end lowers element access to a **local (private / addrspace(5))
array in a device routine** as

```llvm
%off  = ptrtoint ptr addrspace(5) %a to i32      ; private frame offset
%z    = zext i32 %off to i64
%flat = inttoptr i64 %z to ptr                   ; treated as a FLAT pointer -- aperture NOT or-ed in
%g    = getelementptr double, ptr %flat, i64 %idx
%p5   = addrspacecast ptr %g to ptr addrspace(5)
store double %v, ptr addrspace(5) %p5
```

`%flat` is not a valid flat pointer: the private aperture base is missing, so the
value is just the frame offset. The AMDGPU back end's legal lowering of
`addrspacecast flat -> private` is

```
select(flat == null, ~0 /* the private null sentinel */, trunc flat)
```

For the object at frame offset **0** with element index **0** the flat value is
literally `0`, the null test fires, and the cast yields `0xFFFFFFFF`. That value
is then used as the `offen` voffset of a swizzled MUBUF private-segment store, so
the effective address is `scratch_base + 2^32` — 4 GiB outside the scratch
allocation. Result: `Memory access fault by GPU node-N on address 0x…`,
`HSA_STATUS_ERROR_MEMORY_APERTURE_VIOLATION`, exit 134.

This is **not** a back-end regression. Both CCE 19.0.0 and CCE 21.0.2 miscompile
the pattern identically; they only differ in which instruction expresses the
select. Whether a given build faults is decided purely by whether the front end's
frame layout happens to place an affected array at offset 0.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../promote-alloca-dropped-store`](../promote-alloca-dropped-store) (also private-array lowering, silent rather than fatal) |

## Files

| file | what it is |
|---|---|
| `repro-p5-null-fold.ll` | one alloca (so it lands at frame offset 0) + **constant** index 0 -> the null check folds -> guaranteed wild store. **This is the reproducer.** |
| `repro-p5-null-dyn.ll` | same chain with a **dynamic** index -> the null check survives as a runtime select; wild only when the runtime flat value is 0. This is the shape that appears at hundreds of sites in real MFC device code. |

## Reproduce

The `cce` module does not put `llc` on `PATH`; use absolute paths.

```sh
cd cce/private-flat-pointer

/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/llc -O2 -mcpu=gfx90a \
    repro-p5-null-fold.ll -o repro-p5-null-fold_21.0.2.s
/opt/cray/pe/cce/19.0.0/cce-clang/x86_64/bin/llc -O2 -mcpu=gfx90a \
    repro-p5-null-fold.ll -o repro-p5-null-fold_19.0.0.s

grep -nE 'offen|, -1|cndmask|cselect' repro-p5-null-fold_*.s
```

## Measured output (both are wrong)

CCE **21.0.2** — SALU, constant-folded:

```
s_cmp_lg_u32 0, 0
s_cselect_b32 s4, 0, -1                              ; s4 = 0xFFFFFFFF
v_mov_b32_e32 v1, s4
buffer_store_dword v0, v1, s[0:3], 0 offen offset:4  ; voffset = 0xFFFFFFFF
buffer_store_dword v2, v1, s[0:3], 0 offen
```

CCE **19.0.0** — VALU, not constant-folded but provably the same value:

```
v_mov_b32_e32 v0, 0
v_cmp_ne_u32_e32 vcc, 0, v0                          ; vcc = (0 != 0) = 0, all lanes
v_cndmask_b32_e32 v0, -1, v0, vcc                    ; -> v0 = 0xFFFFFFFF, all lanes
buffer_store_dword v1, v0, s[0:3], 0 offen offset:4  ; voffset = 0xFFFFFFFF
buffer_store_dword v2, v0, s[0:3], 0 offen
```

Note for anyone counting occurrences in a real device image: the CCE 19 form of
the folded poison is a `v_cndmask_b32 …, -1,`, **not** an `s_cselect_b32 sN, 0, -1`.
Grepping only for the SALU form undercounts CCE 19's exposure to zero.

## Ask

Emit `addrspacecast ptr addrspace(5) %a to ptr` (or keep the pointer in
addrspace(5) throughout) instead of `ptrtoint`/`zext`/`inttoptr`, so the private
aperture is present and the flat->private round trip is the identity.

## Real-world instance

MFC (https://github.com/MFlowCode/MFC), Frontier, CCE 21.0.2 + ROCm 7.2.0,
OpenACC offload. `Y_rs` (`real(wp), dimension(1:num_species)`) in
`s_compute_pressure`, `src/common/m_variables_conversion.fpp:97`, assigned at
:137 (`Y_rs(:) = rhoYks(:)/rho`); `s_compute_pressure` is inlined into the
`!$acc parallel loop` kernel at :505
(`s_convert_conservative_to_primitive_variables$m_variables_conversion_$ck_L505_1`).
All chemistry regression tests abort; the same source and case pass under
CCE 19.0.0 only because `Y_rs` was not placed at frame offset 0 there.

## Root cause: offset 0 is made indistinguishable from null — and LLVM is correct

The front end converts a private pointer to flat by hand:

```llvm
%off  = ptrtoint ptr addrspace(5) %a to i32   ; private ptr is a 32-bit scratch OFFSET
%z    = zext i32 %off to i64
%flat = inttoptr i64 %z to ptr                ; "flat pointer" = the bare offset
```

On AMDGPU a private pointer is an offset into the scratch aperture; converting it to flat
requires **adding the aperture base**, which is what `addrspacecast` emits. Zero-extending the
raw offset omits it, so an alloca placed at scratch offset 0 becomes the flat value `0` — which
is indistinguishable from a null flat pointer.

The rest follows from correct LLVM behaviour. `0xFFFFFFFF` is the AMDGPU null sentinel for
`addrspace(5)`, so an `addrspacecast` from flat back to private **must** map null to `-1`. That
lowering is visible in the generated code:

```asm
; repro-p5-null-fold.ll  (the front end's ptrtoint/zext/inttoptr form)
s_cmp_lg_u32 0, 0                                     ; is the offset null?
s_cselect_b32 s4, 0, -1                               ; yes -> -1 (private null)
v_mov_b32_e32 v1, s4
buffer_store_dword v0, v1, s[0:3], 0 offen offset:4    ; indexed store, v1 = 0xFFFFFFFF
```

versus the same operation written correctly (`repro-p5-correct.ll` in this directory):

```asm
; addrspacecast ptr addrspace(5) %a to ptr
buffer_store_dword v0, off, s[0:3], 0 offset:4        ; direct addressing, no index, no cselect
```

**So this is not an LLVM bug.** The `s_cselect ... -1` is the required null-preserving cast; the
back end is faithfully implementing what the IR asks for. The defect is that the IR asks for the
wrong thing.

This also explains the entry's original observation that CCE 19.0.0 and 21.0.2 both emit it and
that whether a build faults depends only on frame layout: the sequence is *always* wrong, but it
only misbehaves when an object actually lands at scratch offset 0. CCE 19 was lucky, not correct.

### Fix

Emit `addrspacecast ptr addrspace(5) %p to ptr` rather than
`inttoptr (zext (ptrtoint %p))`. The control file shows the corrected form is also **better
code** — the null check and the index register both disappear, leaving direct `off` addressing.

### Contrast with the other CCE 21 entries

Unlike `../instcombine-phi-addrspace-cast` (fixed upstream, backport `6d033abb7`) and
`../lld-agpr-mfma-assert` (fixed in LLVM 22), there is **nothing upstream to backport here** —
the LLVM side is correct. This one has to be fixed in CCE's Fortran front end, like
`../promote-alloca-dropped-store`, whose divergence is also CCE-side.
