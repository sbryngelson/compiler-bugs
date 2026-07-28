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
| Vendor | none filed |
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
