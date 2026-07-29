# CCE 21 silently discards a dynamically-indexed store into a 1-based private array

**Wrong answers, no diagnostic, no crash.** A store to `arr(v)` — where `arr` is a
local array with lower bound 1 and `v` is a runtime value — is dropped from the
generated device code. The array keeps its previous contents and the program
continues.

* **Reported by:** OLCF Frontier, project CFD154
* **Component:** CCE 21 Fortran + AMDGPU back-end (`AMDGPUPromoteAllocaToVector`)
* **Severity:** silent miscompilation — wrong numerical results
* **Affected:** CCE **21.0.2**, gfx90a, OpenACC and OpenMP target offload
* **Not affected:** CCE **19.0.0** (same source, same flags, correct code)

Found in the MFC CFD solver (<https://github.com/MFlowCode/MFC>), where it
corrupted the viscous flux by ~25% of the term and the chemistry results by up
to 1.5e-04 relative — in both cases with no error of any kind.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) — blocks moving Frontier off `cce/19.0.0` |
| Related | [`../private-flat-pointer`](../private-flat-pointer) (also private-array lowering), [`../lld-agpr-mfma-assert`](../lld-agpr-mfma-assert) (the build blocker on the same CCE) |

---

## 1. Files

| file | what it is |
| --- | --- |
| `v_write.f90` | **The reproducer.** 24 lines, pure integer, no floating point. Self-checking. |
| `v_read.f90` | Control: dynamic *load* from the same array. Correct on both compilers. |
| `v_lb0.f90` | Control: same store with lower bound **0**. Correct on both compilers. |
| `v_write-cce21.disasm.txt` | Device disassembly showing the dropped store. |
| `v_write-cce19.disasm.txt` | Device disassembly of the correct CCE 19 code. |
| `extract-device-image.py` | Pulls the embedded AMDGPU ELF out of the executable (see §5). |

## 2. Reproduce

```bash
module reset
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2

ftn --version | head -1      # MUST say 21.0.2 -- see the warning below
ftn -hacc -o v_write v_write.f90
srun -n1 --gpus-per-task 1 ./v_write
```

> **Check the compiler version before believing a PASS.** The obvious one-liner
> `module load cpe/26.03 cce/21.0.2 rocm/7.2.0 craype-accel-amd-gfx90a` **looks
> like it works and does not.** `ftn` keeps dispatching the default CCE (18.0.1
> on Frontier) and the accelerator target is left unset, so `ftn` emits
>
> ```
> ftn-1350 ftn: WARNING in command line
>   Command line option "-hacc" is being ignored because an accelerator
>   target has not been specified.
> ```
>
> builds the reproducer as **host** code, and prints `PASS` — a false negative
> that looks exactly like a fixed compiler. You need `module reset`, then `cpe`,
> then an explicit `module swap cce`. [`../contiguous-mix-dropped-stores/run_versions.sh`](../contiguous-mix-dropped-stores/run_versions.sh)
> already encodes the working recipe. Two cheap confirmations that the
> environment is right: `ftn --version` reports 21.0.2, and the compiler banner
> ends `Target is x86-64 : x86-trento : none : amdgcn-gfx90a` rather than
> `... : none : none`.

### Expected
```
v_write nbad=0 of 64  PASS
```

### Actual, CCE 21.0.2
```
v_write nbad=64 of 64  FAIL
   e.g. j=1 got 0 expected 5
```

CCE 19.0.0 (`module load cpe/25.03 rocm/6.3.1 craype-accel-amd-gfx90a`) prints
`PASS`.

The two controls isolate the trigger: `v_read` passes, so *loads* are fine, and
`v_lb0` — the identical store into an array declared `idx(0:2)` instead of
`idx(3)` — also passes. **The lower bound of 1 is the trigger.**

## 3. The reproducer

```fortran
integer :: idx(3)                     ! lower bound 1
nd = command_argument_count() + 1     ! = 1, opaque to the optimiser
!$acc parallel loop gang vector private(idx)
do j = 1, n
    idx(1) = 0; idx(2) = 0; idx(3) = 0
    idx(nd) = 5*j                     ! <<< this store is discarded
    out(j) = idx(1)                   ! gets 0, not 5*j
end do
```

## 4. Mechanism

For a 1-based array the byte offset of `arr(v)` is `4*v - 4`. CCE 21
canonicalizes the element index as `v + 0x3FFFFFFF`, i.e. `(v-1) + 2^30`. In
**address** arithmetic that is harmless, because
`(e + 2^30)*4 = e*4 + 2^32 ≡ e*4 (mod 2^32)`.

It is *not* harmless once `AMDGPUPromoteAllocaToVector` registerizes the array,
because the dynamic index is then lowered to **equality comparisons**, and
equality does not wrap.

CCE 21 device code (`v_write-cce21.disasm.txt`, kernel `v_write_$ck_L10_1`):

```
s_load_dword       s4, s[0:1], 0x0     ; s4 = nd, runtime value 1
s_cmp_eq_u32       s4, 0xc0000001      ; <<< tests nd + 0x3FFFFFFF == 0
v_cndmask_b32_e32  v2, 0, v2, vcc      ; select 5*j only if that test passed
global_store_dword v[0:1], v2, off     ; out(j)
```

`0xC0000001` is `-0x3FFFFFFF (mod 2^32)`. So the compiler folded *"is the
canonicalized index zero?"* into *"is `nd` equal to `0xC0000001`?"*. But the
condition it needed is `nd - 1 == 0`, i.e. `nd == 1`. The two are equivalent
only under wrapping address arithmetic, never as a predicate. With `nd = 1` the
comparison is false, the select yields `0`, and the store is gone. There is
exactly **one** compare/select for a three-element array, and **zero** scratch
traffic — the array was fully registerized:

| | CCE 19.0.0 | CCE 21.0.2 |
| --- | --- | --- |
| `private_segment_fixed_size` | 16 | **0** |
| scratch `buffer_*` ops | 3 | **0** |
| `s_cmp_eq_u32` / `v_cndmask` | 0 / 0 | 1 / 1 |

CCE 19 keeps `idx` in scratch and emits the honest offset — note the explicit
`-4` for the lower bound, and a real indexed store:

```
v_add_u32_e32      v1, s4, v1
v_add_u32_e32      v1, -4, v1          ; the 1-based adjustment, done in the address
buffer_store_dword v2, v1, s[0:3], 0 offen
```

## 5. Workaround

`-plugin-opt=-disable-promote-alloca-to-vector`, injected into the device link
via the `CRAY_CCE_LLD_ARGS` environment variable. Measured over the whole MFC
program (453 kernels): total scratch +0.5%, `buffer_load`/`buffer_store` count
**identical**, VGPR spills −12%, occupancy unchanged — i.e. near-free.

Controls: `-disable-promote-alloca-to-lds` does **not** fix it, and
`-amdgpu-promote-alloca-to-vector-limit=0` does not either (`0` means "target
default", not "disabled").

**A source-level workaround also works** and is what we shipped: write the
constant index explicitly instead of a computed one. In MFC, replacing
`idx(norm_dir) = idx(norm_dir) + 1` with an `if`/`else` on `norm_dir` that
assigns constant indices fixed every affected test.

### Getting the flag through the Cray driver — a silent-loss trap

`CRAY_CCE_LLD_ARGS` carries more than one `-plugin-opt`, and if the value is set
from a config line that is evaluated through `eval "export $line"` — which is what
MFC's `toolchain/bootstrap/modules.sh` does — **the value must be quoted in the
file**. Unquoted, only the *first* flag survives:

```bash
# quoted -- both flags survive
_entry='CRAY_CCE_LLD_ARGS="-plugin-opt=-mattr=-mai-insts -plugin-opt=-disable-promote-alloca-to-vector"'
eval "export $_entry"
# -> [-plugin-opt=-mattr=-mai-insts -plugin-opt=-disable-promote-alloca-to-vector]

# unquoted -- the second flag is dropped
_entry='CRAY_CCE_LLD_ARGS=-plugin-opt=-mattr=-mai-insts -plugin-opt=-disable-promote-alloca-to-vector'
eval "export $_entry"
# bash: export: `-plugin-opt=-disable-promote-alloca-to-vector': not a valid identifier
# -> [-plugin-opt=-mattr=-mai-insts]
```

The failure is silent in practice: the diagnostic goes to stderr, and loader
output is routinely discarded. The result is that you keep the AGPR *build*
workaround and lose the *correctness* one, which is the worst possible ordering.
Tracked as MFC#1690. Verify with `echo "[$CRAY_CCE_LLD_ARGS]"` after loading — it
must show **both** `-plugin-opt` values.

### Is the flag load-bearing on top of the source patch? Not yet established

The source patch covers only the sites that were found. The question of whether
unpatched sites remain live matters for upstreaming, and there is a suggestive but
**inconclusive** measurement:

Job 5106032 (Frontier, CCE 21.0.2) exported
`CRAY_CCE_LLD_ARGS="-plugin-opt=-disable-promote-alloca-to-vector"`, forced a device
relink, and ran the five regression tests that were failing without it. All five
returned `rc=0` on **both** `--gpu mp` and `--gpu acc` — 10/10.

That is not sufficient to attribute the fix to the flag:

* **The job's own gate is blind.** It checked
  `grep -c 'disable-promote-alloca-to-vector'` against an `mfc.sh test --dry-run`
  log and reported `0`. Independently checked: MFC dry-run logs contain **zero**
  `plugin-opt` lines of any kind (0 occurrences in a 1252-line log), so that gate
  cannot detect the flag whether or not it arrived. It is neither confirmation nor
  refutation.
* **There is no same-session control.** The "5 failures" baseline came from a
  different job in a different tree state, and a tree difference had already been
  identified between the two investigations. A flag-off arm in the same session,
  same relink, is what the comparison needs.

Two things would settle it:

1. **A gate that works.** The flag's effect is directly visible in the device
   image — with `AMDGPUPromoteAllocaToVector` suppressed the array stays in scratch
   and the `s_cmp_eq_u32 sN, 0xc0000001` / `v_cndmask` pair from §4 is absent, with
   scratch `buffer_*` traffic in its place. Extract and disassemble
   (`../lib/extract-device-image.py`, then `llvm-objdump` per the `cce/` README) and
   count the signature in both builds.
2. **A flag-off control arm** in the same session and same tree.

Until then, treat the flag as *the belt-and-braces option that is measured to be
near-free*, not as a demonstrated requirement on top of the source patch.

## 6. Why this is worse than an ordinary miscompilation

**The defect cannot be detected in the generated binary.** A dropped store
leaves no instruction behind, so there is nothing to grep for. We initially
cleared one call site as "benign" precisely because the marker we were looking
for was absent — it was absent *because* the store had already been eliminated.
Any screening for this has to happen at source level.

Two notes for anyone reproducing on a full application rather than this test
case:

* `llvm-objdump` on the **host** executable crashes (`Disassembly not yet
  supported for subtarget`), and forcing `--mcpu=gfx90a` on x86 bytes emits tens
  of thousands of lines of garbage. The device code is an AMDGPU ELF embedded in
  the executable; `extract-device-image.py` finds it by scanning for `\x7fELF`
  with `e_machine == 224` and trims to `e_shoff + e_shnum*e_shentsize`.
* Always check the disassembly is non-empty before believing a zero count.


## Root cause: unsigned division of a negative byte offset

**`AMDGPUPromoteAllocaToVector` converts a negative byte-offset GEP into a vector element
index using an UNSIGNED division.**

CCE lowers a Fortran 1-based dynamic subscript as a *chained* GEP — a typed element GEP,
then a separate byte GEP carrying the `-1` adjustment:

```llvm
%r20 = getelementptr i32, ptr addrspace(5) %idx, i32 %r19   ; + nd elements
%r21 = getelementptr i8,  ptr addrspace(5) %r20, i32 -4     ; - 1 element, as -4 BYTES
store i32 %r16, ptr addrspace(5) %r21
```

Promoting the alloca to `<3 x i32>` requires folding that byte offset back into an element
index. The pass divides by the 4-byte element size **unsigned**:

```
want:  -4 / 4          = -1            -> index = nd - 1        = 0   (correct)
got:   0xFFFFFFFC / 4  = 0x3FFFFFFF    -> index = nd + 0x3FFFFFFF
```

which is exactly what appears in the output:

```llvm
%1 = add i32 1073741823, %r19          ; 1073741823 = 0x3FFFFFFF
%2 = insertelement <3 x i32> %0, i32 %r16, i32 %1
%3 = extractelement <3 x i32> %2, i32 0
```

For `nd = 1` the index is `0x40000000`, far outside a 3-element vector. Per LangRef,
`insertelement` with an out-of-range index yields **poison**, so `%2` is discarded, the
following `extractelement` reads the un-updated `%0`, and the store is gone. No diagnostic,
because from the pass's point of view it emitted a perfectly well-formed `insertelement`.

This explains every observed control:

| arm | GEP shape | result |
| --- | --- | --- |
| `v_write` — 1-based, dynamic **write** | typed GEP + `i8 -4` | **FAIL**, store dropped |
| `v_lb0` — 0-based | no negative byte GEP emitted | PASS |
| `v_read` — 1-based, dynamic **read** | same chain, but `extractelement` poison index | PASS (reads the constant-index element) |

### Minimal IR reproducer

`pa_min.ll` — 14 lines, no Fortran, no MFC:

```console
$ opt -mcpu=gfx90a -passes=amdgpu-promote-alloca -S pa_min.ll
  %1 = add i32 1073741823, %n          ; <-- should be `add i32 %n, -1`
  %2 = insertelement <3 x i32> %0, i32 %val, i32 %1
```

Any negative byte-offset GEP onto a promotable alloca reproduces it; the 1-based Fortran
subscript is just the common way to generate one.


## Version triage: a regression confined to LLVM 21

The same 14-line `pa_min.ll` through four LLVM releases available on Frontier
(`./triage.sh` reproduces this):

| toolchain | LLVM | result |
| --- | --- | --- |
| ROCm 7.0.2 | 20.0.0 | **not promoted** — alloca and GEPs left intact (safe) |
| **CCE 21.0.2** | **21.1.8** | **promoted with `%n + 0x3FFFFFFF`** — wrong answers |
| ROCm 7.2.0 | 22.0.0 | promoted correctly as `%n - 1` |
| ROCm 7.13.0 | 23.0.0 | promoted correctly as `%n - 1` |

LLVM 20 declines to promote this shape at all, so it cannot get it wrong. LLVM 21 **adds**
the ability to fold a chained byte-offset GEP into a vector index but performs the
byte-to-element conversion unsigned. LLVM 22 fixes the arithmetic.

**CCE 21.0.2 is based on LLVM 21.1.8 — the one release where the capability exists and is
wrong.** The neighbours are AMD forks rather than pristine upstream, so this is strong
evidence rather than proof, but the boundary is sharp and the corrected expression
(`add i32 %n, -1`) is visible in both later versions.

This matters for triage: the fix already exists upstream, so this is a backport rather than
new development. It is also the second CCE 21.0.2 defect found to be fixed between LLVM 21
and 22 — see `../instcombine-phi-addrspace-cast`, which has the same version boundary. Two
independent wrong-answer/abort defects with a common resolution point is an argument for
rebasing CCE onto a later LLVM rather than patching individually.

### Suggested fix

Treat the byte offset as **signed** when converting to an element index, and bail out of
promotion when the offset is not an exact multiple of the element size.

### How to get the IR (this was the hard part)

`-plugin-opt=save-temps` only works when the link is driven by CMake; for a direct
`ftn -o exe file.f90` it emits nothing. CCE instead stores the device IR in a
**`.cray.llvm.offloading`** ELF section of the object file, wrapped in an LLVM
`OffloadBinary` (magic `0x10FF10AD`) with the bitcode at a variable offset. `extract-device-ir.sh`
in this directory automates it:

```console
$ ./extract-device-ir.sh v_write.f90 dev.ll
bitcode at offset 360
wrote dev.ll
```

### Ruled out along the way

A single typed `getelementptr [3 x i32], ptr %a, i32 0, i32 %off` — the shape one would
write by hand — is handled **correctly** by the pass for all of `add nsw %nd, -1`,
`add %nd, -1`, and even `add %nd, 1073741823`. The defect requires the *chained byte-offset*
form that CCE actually emits. Modelling the index arithmetic without the byte GEP does not
reproduce it.

## Counting the marker in a real build

The index-canonicalization signature is the **instruction form**, not the bare
constant:

```bash
grep -cE 's_add_i32 s[0-9]+, s[0-9]+, 0x3fffffff'
grep -cE 'v_add_u32(_e32)? v[0-9]+, 0x3fffffff'
```

`0x3fffffff` also appears as an ordinary operand of `s_mul_i32`, `s_addc_u32` and
`s_subb_u32` in 64-bit address arithmetic. A non-zero count of the bare constant is
**not** evidence of the defect, and a zero count of it is not evidence of its absence.

Two further cautions, both of which produced wrong counts here:

* ROCm 7.2.0's `llvm-objdump` silently emits **nothing** on these images. Use the
  6.3.1 one, or check two disassemblers agree, and always verify the line count is
  non-zero before believing a zero.
* A discarded store leaves **no instruction behind**. Absence of the marker at a call
  site is therefore not evidence the site is safe — it is equally consistent with the
  store having already been eliminated. Screening must happen at source level.
