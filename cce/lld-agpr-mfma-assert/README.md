# Cray CCE 21.x: `lld` asserts in "AMDGPU Rewrite AGPR-Copy-MFMA" during device LTO

**Status: confirmed on CCE 21.0.0 and 21.0.2. Root-caused — the pass gates on AGPRs being
*allocated* rather than on MFMA being present, and gfx90a's unified register file makes
high-pressure MFMA-free kernels allocate AGPRs. A portable source-level workaround exists
and builds MFC clean on 21.0.2 (see below). Not yet filed with HPE (the linker itself asks
for a report).**

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed — `lld` itself asks for a report at https://support.hpe.com/ |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) — blocks moving Frontier off `cce/19.0.0` |
| Related | [`../lld-infer-address-spaces-cce20`](../lld-infer-address-spaces-cce20) (same class, CCE 20.x), [`../contiguous-mix-dropped-stores`](../contiguous-mix-dropped-stores) (why staying on 19.0.0 is also unsafe), [`../mir-roundtrip-bb-name`](../mir-roundtrip-bb-name) (hit while reducing this) |
| Source | MFC [#1679](https://github.com/MFlowCode/MFC/pull/1679) build; reduced repro in `repro/` |
## Symptom

Every Fortran source compiles — zero `ftn` errors — and then the **device LTO link crashes**:

```
[100%] Linking Fortran executable simulation
lld: /workspace/llvm/include/llvm/CodeGen/SlotIndexes.h:96:
     llvm::IndexListEntry* llvm::SlotIndex::listEntry() const:
     Assertion `isValid() && "Attempt to compare reserved index."' failed.
PLEASE submit a bug report to HPE at https://support.hpe.com/ and include the crash backtrace.

0. Program arguments: /opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/lld -flavor gnu
   --no-undefined -shared -plugin-opt=mcpu=gfx90a
   -plugin-opt=-disable-promote-alloca-to-lds -plugin-opt=defaults=cray
   -plugin-opt=O2 -plugin-opt=save-temps
   -o .../simulation-cce-openmppost_lld.amdgpu .../simulation-cce-openmp-pre-llc.bc
1. Running pass 'CallGraph Pass Manager' on module 'ld-temp.o'.
2. Running pass 'AMDGPU Rewrite AGPR-Copy-MFMA' on function
   '@"s_compute_bubble_ee_source$m_bubbles_ee_$ck_L185_28"'
#18 lld::elf::BitcodeCompiler::compile()
```

Identical on **both** offload backends — OpenMP target offload and OpenACC — same
assertion, same pass, same function. See `artifacts/lld_crash_mp.txt` and
`artifacts/lld_crash_acc.txt`.

## Scope

| lld | `-plugin-opt` | result |
|---|---|---|
| 21.0.2 | `O2` (what the build uses) | **crash** |
| 21.0.2 | `O1` | **crash** |
| 21.0.2 | `O0` | OK |
| 21.0.0 | `O2` | **crash**, same function |

So it is **not** a 21.0.2 regression — the whole 21.x line is affected. Lowering the LTO
optimisation level to `O1` does not avoid it; only `O0` does, which disables device LTO
optimisation and is not viable for production.

CCE 20.0.2 was subsequently built from scratch and fails too, but with a *different*
crash — see `../lld-infer-address-spaces-cce20/`. (Replaying this module through 20.0.2's
`lld` only yields `lld: error: Invalid record`, a bitcode-version mismatch; that is not a
verdict on 20.0.2 and an earlier note treating it as one was wrong.)

No flag disables the pass. `-plugin-opt=-help-hidden` exposes 112 AMDGPU options; the only
MFMA-related one is `--amdgpu-mfma-padding-ratio`, which does not gate this rewrite.

## Standalone reproducer (`repro/`)

CCE 21.0.2 ships its own matching LLVM 21.1.8 **with assertions enabled**, including `llc`,
`llvm-extract`, `llvm-dis` and `llvm-reduce` in `cce-clang/x86_64/bin`. That allows the
crash to be reduced from a 19 MB whole-program link to a **495 KB single-function module**
driven by `llc` alone — no MFC, no build system, no `lld`, no MPI, no GPU:

```
$ ./repro/run.sh
llc: SlotIndexes.h:96: llvm::SlotIndex::listEntry(): Assertion
     `isValid() && "Attempt to compare reserved index."' failed.
2. Running pass 'AMDGPU Rewrite AGPR-Copy-MFMA' on function
   '@"s_compute_bubble_ee_source$m_bubbles_ee_$ck_L185_28"'
```

Backtrace bottoms out in `AMDGPURewriteAGPRCopyMFMAImpl::run(MachineFunction&)`.
The same module at `-O0` does not crash — the pass is only in the optimised regalloc
pipeline.

## Root cause

**The pass gates on AGPRs having been *allocated*, not on MFMA being present.** Upstream
`AMDGPURewriteAGPRCopyMFMA.cpp`:

```cpp
bool AMDGPURewriteAGPRCopyMFMAImpl::run(MachineFunction &MF) const {
  if (!ST.hasGFX90AInsts()) return false;
  // Early exit if no AGPRs were assigned.
  if (!LRM.isPhysRegUsed(AMDGPU::AGPR0)) return false;
  ...
  if (MadeChange) eliminateSpillsOfReassignedVGPRs();
}
```

That is the whole story. gfx90a has a **unified VGPR/AGPR register file**: when a kernel
needs more than 256 VGPRs, the allocator spills into the AGPR half *as ordinary storage*,
with no matrix instruction anywhere in the function. `isPhysRegUsed(AGPR0)` is then true,
the early exit does not fire, and a pass written for MFMA code walks a function that
contains none — asserting in the `LiveIntervals`/`SlotIndexes` bookkeeping underneath
`eliminateSpillsOfReassignedVGPRs()`.

So "MFC contains no MFMA" and "the pass runs on MFC" are not in tension, and the correct
statement of the bug is: *the AGPR-allocated gate is too weak a proxy for the MFMA gate the
pass actually requires.*

### The decisive experiment

Register pressure **is** the trigger — an earlier revision of this file wrongly ruled it
out, because every pressure knob it tried was pushed in the direction of *more* registers
per thread (which increases AGPR use) rather than fewer. Reversing the direction suppresses
the crash outright. All on the reduced 495 KB module via `llc`:

| attribute | direction | result |
|---|---|---|
| `amdgpu-waves-per-eu="1,1"` | low occupancy → **max** registers | **crash** |
| `amdgpu-waves-per-eu="4,4"` / `"8,8"` | high occupancy → fewer registers | **ok** |
| `amdgpu-flat-work-group-size="1,256"` (default) | 256 threads | **crash** |
| `amdgpu-flat-work-group-size="256,256"` | 256 threads | **crash** |
| `amdgpu-flat-work-group-size="1,512"` / `"1,1024"` | more threads → fewer registers each | **ok** |
| `amdgpu-agpr-alloc="0"` (min only) | unbounded max | **crash** |
| `amdgpu-agpr-alloc="0,0"` / `"0,1"` | max capped | **ok** |

Every "ok" row is the same mechanism: cap the per-thread register budget, the allocator
stops reaching into AGPRs, `isPhysRegUsed(AGPR0)` goes false, the pass early-exits.

`optnone` also suppresses it (the pass honours `skipFunction()`), confirming it is confined
to the optimised regalloc pipeline.

## Trigger

Exactly **two** functions in the whole program, both adaptive-`dt` bubble sub-stepping
kernels — the highest-register-pressure code in MFC:

```
m_bubbles_EE.fpp:185   s_compute_bubble_EE_source     (25 privates + copy reduction, collapse(3))
m_bubbles_EL.fpp:633   s_compute_bubble_EL_dynamics   (32 privates + copy reduction)
```

Note that kernel *size* is not the trigger: forcing the inlined sub-step routines to
`INLINENEVER` (shrinking the kernel substantially) still crashes. It is specifically
whether the allocator ends up touching AGPR0.

## Usable workaround

Since `amdgpu-flat-work-group-size` is what OpenMP's `thread_limit` and OpenACC's
`vector_length` lower to, the fix is expressible in **portable source** — no compiler flag,
no build-system hack, no `-plugin-opt` injection (for which no supported path exists, see
`../lld-infer-address-spaces-cce20`):

```fortran
$:GPU_PARALLEL_LOOP(private='[...]', collapse=3, copy='[adap_dt_stop_sum]', &
                    extraOmpArgs='thread_limit(1024)', extraAccArgs='vector_length(1024)')
```

Applied to just those two loops, **MFC builds clean on CCE 21.0.2 under both `--gpu mp` and
`--gpu acc`** — zero `ftn` errors, zero linker crashes, all three executables produced.
This is the first CCE newer than 19.0.0 to link this code at all.

The cost is confined to two kernels that only run for bubble cases with adaptive `dt`:
forcing 1024-thread workgroups lowers their per-thread register budget and trades AGPR
storage for scratch traffic. It is a workaround for a compiler defect, not a tuning choice,
and should be reverted once the gate is fixed upstream.

## Reproducing

The crash is reproducible standalone from the saved bitcode, independent of MFC's build
system — `-plugin-opt=save-temps` is already on, so the failing build leaves it behind:

```bash
lld -flavor gnu --no-undefined -shared -plugin-opt=mcpu=gfx90a \
    -plugin-opt=-disable-promote-alloca-to-lds -plugin-opt=defaults=cray \
    -plugin-opt=O2 -o /tmp/out.amdgpu simulation-cce-openmp-pre-llc.bc
```

To regenerate the input (19 MB `-pre-llc.bc`, plus a 12 MB `...0.5.precodegen.bc` which is
the module immediately before codegen where the pass runs):

```bash
git clone https://github.com/MFlowCode/MFC && cd MFC
# point toolchain/modules at: cpe/26.03 cce/21.0.2 rocm/7.2.0, and drop
# rocprofiler-compute from f-gpu (it silently reverts PrgEnv to cce/18.0.1)
source ./mfc.sh load -c f -m g
./mfc.sh build -t simulation --gpu mp     # or --gpu acc; both crash
# bitcode lands in build/staging/gpu-mp-*/simulation-cce-openmp-pre-llc.bc
```

The 19 MB / 12 MB whole-program bitcode is not committed. It is not needed: `repro/`
contains the reduced 495 KB single-function module that reproduces with `llc` alone.

(An earlier revision of this file claimed no `llvm-extract`/`llc` exists on Frontier. That
was wrong — CCE ships a full matching LLVM 21.1.8 toolchain in `cce-clang/x86_64/bin`; the
mistake was an `ls` glob that missed them. ROCm's LLVM 22 tools *are* unusable here, but
only because LLVM 22 changed the `llvm.lifetime.start` signature, so anything round-tripped
through them is rejected by CCE's older LLVM before reaching the failing pass.)

## Impact

This is what blocks MFC from moving off `cce/19.0.0` on Frontier:

| CCE | links MFC? | correct answers? |
|---|---|---|
| 19.0.0 | yes | **no** — store-dropping IPA bug, `../cce19-ipa-contiguous-mix/` (worked around in MFC source) |
| 20.0.2 | **no** — `../lld-infer-address-spaces-cce20/` | — |
| 21.0.0, 21.0.2 | **not by default** — this bug | — |
| 21.0.2 **+ the `thread_limit`/`vector_length` workaround above** | **yes**, `mp` and `acc` | under test |

The workaround makes 21.0.2 the first CCE newer than 19.0.0 to link this code, so the
practical path off 19.0.0 now exists in source. It is still a defect worth fixing upstream:
any gfx90a Fortran offload code with enough register pressure to spill into AGPRs will hit
this, with no diagnostic pointing at the cause and no supported way to force the device link
to `O0` (see the CCE 20 report).
