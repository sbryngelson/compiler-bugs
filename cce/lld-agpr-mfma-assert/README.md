# Cray CCE 21.x: `lld` asserts in "AMDGPU Rewrite AGPR-Copy-MFMA" during device LTO

> **Severity:** Abort (blocks all linking)  
> **Fix belongs to:** **Backport [`30007a541493`](https://github.com/llvm/llvm-project/pull/153915)** — 3-line guard, absent from CCE's LLVM 21.1.8 base  
> **Status:** Highest-value fix: the workaround it forces (`-mattr=-mai-insts`) disables AGPRs and costs 29x scratch and 61% on MFC's IGR solver.

**Status: confirmed on CCE 21.0.0 and 21.0.2. Root-caused — the pass gates on AGPRs being
*allocated* rather than on MFMA being present, and gfx90a's unified register file makes
high-pressure MFMA-free kernels allocate AGPRs. A portable source-level workaround exists
and builds MFC clean on 21.0.2 (see below). Not yet filed with HPE (the linker itself asks
for a report).**

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending; `lld` itself asks for a report at https://support.hpe.com/ |
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

`repro/` holds two modules at different reduction depths:

| file | size | what it is |
|---|---|---|
| `crashing_function.bc` | 495 KB | `llvm-extract` of the single crashing function |
| `reduced-667-line.ll` | 50 KB, 667 lines | the same crash after `llvm-reduce`; **textual IR, readable** |

The reduced module is what the measurement tables below were taken on. Its
interestingness test was:

```bash
#!/bin/bash
/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/llc \
  -O2 -mcpu=gfx90a -mtriple=amdgcn-amd-amdhsa "$1" -o /dev/null 2>&1 \
  | grep -q 'Attempt to compare reserved index'
```

**There is no Fortran-level reproducer.** Attempts to synthesise one from the kernel's
apparent characteristics (high register pressure, `!DIR$ INLINENEVER` device calls,
derived-type/`pointer` array indirection, absent `optional` dummies) produced 13 variants,
**none of which reproduce** — the trigger is more specific than those features. Reduction
from MFC source would be the way to get one; not done.

Note the two modules were captured from different builds, so the mangled kernel name
carries a different trailing index (`...$ck_L185_28` vs `...$ck_L185_6`). Same loop, same
source line, same assertion.

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

### `amdgpu-agpr-alloc` semantics, measured

`amdgpu-agpr-alloc` is a **function attribute, not a `cl::opt`**: it is absent from
`llc -help-hidden` (which does list 106 other `amdgpu-` options), and
`llc -amdgpu-agpr-alloc=0` is rejected as an unknown argument. On the reduced module,
whose unconstrained allocation takes 228 AGPRs:

| attribute value | resulting `agpr_count` |
| --- | --- |
| *absent* | 228 |
| `"0"` | 228 |
| `"32"` | 228 |
| `"0,0"` | 0 |
| `"0,1"` | 1 |
| `"1,1"` | 4 |
| `"0,16"` / `"16,0"` | 16 |
| `"0,32"` / `"32,0"` / `"16,32"` / `"32,16"` | 32 |
| `"0,228"` / `"0,300"` | 228 |

So the **single-value form is inert** — `"0"` is behaviourally indistinguishable from
omitting the attribute. The **paired form is an upper bound**, effective cap ≈
`max(lo,hi)` rounded up to the 4-AGPR granule (`"1,1"` → 4). Neither form acts as a floor:
on a low-pressure module every value, including `"8,8"` and `"32,0"`, yields
`agpr_count = 0`.

A capped `amdgpu-agpr-alloc` would be the cleanest thing to request upstream, but the
threshold is tighter than "a cap" — the assertion is avoided only when the resulting
`agpr_count` is **0 or 1**:

| attribute value | effective `agpr_count` | result |
| --- | --- | --- |
| `"0,0"` | 0 | OK |
| `"0,1"` | 1 | OK |
| `"0,2"`, `"0,3"`, `"0,4"`, `"1,1"`, `"1,2"`, `"2,2"`, `"4,4"`, `"0,256"` | ≥ 2 | assert (134) |
| `"0"`, *absent* | unbounded (228 here) | assert (134) |

### Cost of the workgroup-size workaround

`vector_length(N)` / `thread_limit(N)` both lower to
`"amdgpu-flat-work-group-size"="1,N"`, so the cost is measurable directly on the reduced
module. The threshold is sharp and runs *opposite* to intuition — a larger workgroup is
what fixes it:

| `amdgpu-flat-work-group-size` | result | `agpr_count` | `private_segment_fixed_size` | instructions | scratch ops |
| --- | --- | --- | --- | --- | --- |
| `1,64` | assert (134) | – | – | – | – |
| `1,256` (default) | assert (134) | – | – | – | – |
| **`1,512`** | **OK** | **0** | **0** | 1366 | **0** |
| `1,1024` | OK | 0 | 0 | 1739 | 238 |

Note `1,512` needs no scratch at all while `1,1024` spills — so 512 is the cheaper choice
where the launch geometry allows it.

### The `-mai-insts` alternative, and why it is worse

Dropping the MAI subtarget feature at codegen (`-plugin-opt=-mattr=-mai-insts`, injected
via `CRAY_CCE_LLD_ARGS`) also avoids the crash, and was the first workaround used here. It
is **not** codegen-neutral. An earlier note claimed neutrality on the basis of 12 kernels
whose instruction streams were byte-identical both ways; that sample was unrepresentative.
Compiling one whole translation unit (`m_variables_conversion`, ~2.6 MB of IR) with
`llc -O2 -mcpu=gfx90a` both ways:

| | with MAI | `-mattr=-mai-insts` |
| --- | --- | --- |
| max `private_segment_fixed_size` | 256 | 416 |
| `v_accvgpr_*` instructions | 266 | 0 |
| scratch `buffer_load`/`buffer_store` | 200 | 480 |

1,749 lines of assembly differ. Losing the AGPRs drops the unified VGPR cap from 512 to
256, so register pressure moves into scratch — a 2.4× increase in scratch traffic in this
TU, program-wide rather than confined to two kernels.

### …but end to end, `-mai-insts` is the *faster* of the two

The codegen argument above says the geometry workaround should win, because it confines the
penalty to 2 kernels out of 453 instead of taxing the whole program. **Measured head to
head on the same tree, it does not.** MFC benchmark, six cases, `-hacc`, exec seconds:

| case | `-mattr=-mai-insts` | geometry 512 | delta |
| --- | --- | --- | --- |
| `5eq_rk3_weno3_hll` | 50.93 | 51.23 | +0.60% |
| `5eq_rk3_weno3_hllc` | 50.19 | 50.99 | +1.58% |
| `5eq_rk3_weno3_lf` | 50.27 | 50.87 | +1.19% |
| `hypo_hll` | 87.22 | 88.14 | +1.06% |
| `igr` | 17.93 | 18.07 | +0.78% |
| `viscous_weno5_sgb_acoustic` | 52.56 | 52.92 | +0.70% |
| **total** | **309.10** | **312.23** | **+1.01%** |

Geometry-512 is consistently ~1% *slower*, all six cases, same direction. Single runs with
no repeats, but the sign is uniform.

**So `-mai-insts` is what we ship**, and it is also the simpler option — no source change to
the two bubble kernels. Recorded because the register-pressure reasoning is sound and still
predicted the wrong winner: static scratch counts did not translate into runtime.

If the geometry workaround is used anyway, use **512, not 1024** — 1,512 needs no scratch
while 1,1024 spills 238 ops for ~27% more instructions.

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
forcing a larger workgroup lowers their per-thread register budget and trades AGPR storage
for scratch traffic. It is a workaround for a compiler defect, not a tuning choice, and
should be reverted once the gate is fixed upstream.

**Two corrections to the snippet above, both measured after it was written.**

*Use 512, not 1024.* At `1,512` the reduced module needs **no scratch at all**; at `1,1024`
it spills 238 scratch ops for ~27% more instructions. 1024 was chosen for margin after 320
failed, without testing the value in between.

*And this is not actually the configuration we ship.* Benchmarked head to head against
`-mattr=-mai-insts` on the same tree (table under "Cost of the workgroup-size workaround"),
the geometry workaround is **~1% slower across all six benchmark cases**. The
register-pressure argument predicted the opposite and was wrong: confining the penalty to
2 kernels out of 453 did not translate into runtime. MFC ships `-mai-insts`.

The source-level form remains the better answer *in principle* — it needs no `-plugin-opt`
injection, for which no supported path exists — so it is kept here as the portable
workaround. But anyone choosing between them on performance should choose `-mai-insts`.

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
| 19.0.0 | yes | **no** — store-dropping IPA bug, [`../contiguous-mix-dropped-stores`](../contiguous-mix-dropped-stores) (worked around in MFC source) |
| 20.0.2 | **no** — `../lld-infer-address-spaces-cce20/` | — |
| 21.0.0, 21.0.2 | **not by default** — this bug | — |
| 21.0.2 **+ the `thread_limit`/`vector_length` workaround above** | **yes**, `mp` and `acc` | under test |

The workaround makes 21.0.2 the first CCE newer than 19.0.0 to link this code, so the
practical path off 19.0.0 now exists in source. It is still a defect worth fixing upstream:
any gfx90a Fortran offload code with enough register pressure to spill into AGPRs will hit
this, with no diagnostic pointing at the cause and no supported way to force the device link
to `O0` (see the CCE 20 report).

## Measured cost of the `-mattr=-mai-insts` workaround

The `-plugin-opt=-mattr=-mai-insts` workaround is **not free**. On gfx90a the VGPR/AGPR register
file is unified, so disabling MFMA/AGPR instructions removes roughly half the allocator's
budget. Register-hungry kernels then spill to scratch (off-chip) memory.

Measured on MFC's `igr` (Information Geometric Regularization) solver, case-optimized, gfx90a,
comparing CCE 19.0.0 (no workaround needed) against CCE 21.0.2 with the workaround:

| kernel | CCE 19 vgpr / scratch | CCE 21 vgpr / scratch |
| --- | --- | --- |
| `s_igr_riemann_solver ...L829_6` | 224 / 80 | 156 / **544** |
| `s_igr_riemann_solver ...L2168_9` | 204 / **0** | 139 / **448** |
| `s_igr_riemann_solver ...L1700_8` | 202 / **0** | 135 / **448** |
| `s_igr_riemann_solver ...L1319_7` | 165 / **0** | 128 / **448** |
| `s_igr_riemann_solver ...L430_5` | 152 / 80 | 134 / **544** |

Fewer registers used, far more spilling — three kernels go from **zero** scratch to 448 bytes.
The AMDGPU code-object notes corroborate the mechanism: the CCE 19 image carries **516**
`agpr_count` records, the CCE 21 image carries **none**.

End-to-end effect, `grind` (ns/gridpoint/eq/rhs, median of 3, run-to-run variance < 1%):

| case | CCE 19 | CCE 21 + workaround | delta |
| --- | --- | --- | --- |
| `viscous_weno5_sgb_acoustic` | 4.20 | 4.34 | +3.5% |
| `hypo_hll` | 1.80 | 1.87 | +3.6% |
| `ibm` | 5.16 | 5.32 | +3.0% |
| **`igr`** | **2.02** | **3.25** | **+60.8%** |

So the workaround costs ~3% on ordinary kernels and **~61% on the most register-hungry one**,
whose case-optimization benefit also drops from 1.56x to 1.11x.

### Standalone confirmation

`regpressure.f90` + `run_regpressure.sh` demonstrate the mechanism in one file, no MFC required:
eight live 32-element double arrays in an `!$acc routine seq`, compiled with and without the
flag.

| arm | max vgpr | max agpr | max scratch |
| --- | --- | --- | --- |
| baseline | 512 | **256** | **36 B** |
| `-mattr=-mai-insts` | 256 | **none** | **1060 B** |

Without the flag the allocator uses 256 AGPRs as additional register storage and spills almost
nothing. With it, VGPRs cap at 256, AGPRs are unavailable, and scratch grows **29x**. This is
the same signature seen in MFC's `igr` kernels above.

*Note on the MFC-side attribution:* rebuilding `igr` without the flag and re-timing was
attempted and produced no valid result — `CRAY_CCE_LLD_ARGS` reaches `lld` through the
environment and is not part of the build system's configuration hash, so the relink was a no-op
(md5-verified unchanged). The end-to-end 61% figure is therefore correlational; the standalone
table above is the controlled evidence for the mechanism.

**Independent of ROCm version.** The `igr` regression is identical on ROCm 7.0.2 and 7.2.0
(grind 3.27 vs 3.25, within the < 1% run-to-run variance), and the surrounding cases match to
within 0.7%. Since ROCm supplies the runtime and device libraries but CCE's own bundled `lld`
performs the offload link, no ROCm choice recovers the spilling. Recorded because "try a
different ROCm" is the obvious first suggestion and it does not help.

**Why this raises the priority of fixing the assert itself.** `-mai-insts` is currently the only
practical way to link on CCE 21.x, and it is a global flag. A fix that lets AGPRs remain enabled
would recover the spilling; narrowing the workaround (per-TU, or only for the kernels that
trigger the assert) would be the next-best outcome.

## Version triage: LLVM 21-only, and LLVM 22 fixes it

The 667-line reduced reproducer in `repro/` run through every LLVM on the system:

| toolchain | LLVM | AGPR pass runs? | result |
| --- | --- | --- | --- |
| **CCE 21.0.2** | **21.1.8** | yes | **assert, `SlotIndexes.h:96`** (rc=134) |
| ROCm 7.0.2 | 20.0.0 | — | clean |
| ROCm 7.2.0 | 22.0.0 | **yes** (`-debug-pass=Structure` confirms) | **clean** |

```console
$ llc -mcpu=gfx90a -filetype=obj repro/reduced-667-line.ll -o /dev/null
```

The LLVM 22 arm was checked with `-debug-pass=Structure` to confirm
`AMDGPU Rewrite AGPR-Copy-MFMA` is actually in the pipeline — otherwise "clean" would only mean
the pass had been dropped. It runs, and completes. So this is a genuine fix, not a skipped pass.

**Candidate upstream fix, not confirmed:**
[llvm/llvm-project#190719](https://github.com/llvm/llvm-project/pull/190719)
(`b39dfca39`, relanded as `50241dcd0`, 2026-04-21) — *"Fixed verifier crash because of multiple
live range components"* in this pass: after replacing spill instructions the replacement
register may have multiple live range components when the spill slot was stored more than once.

That is the same pass and the same subject matter (spill replacement and live ranges), but the
**symptom differs** — ours is a `SlotIndex::listEntry()` assertion, theirs a machine-verifier
"bad machine code" error. Recorded as a lead, not an identification. The empirical triage above
is the solid part.

## Why this matters more than a link failure

`-mattr=-mai-insts` is the only known way to link on CCE 21.x, and it is **not free**: it
disables AGPRs on gfx90a's unified register file, costing 29x more scratch on register-heavy
kernels and a **61% slowdown** on MFC's IGR solver (measured; see above).

Fixing this assert therefore removes the need for the workaround **and** recovers that
regression. The dependency chain is:

```
AGPR assert  ->  -mattr=-mai-insts  ->  AGPRs unavailable  ->  scratch spilling  ->  igr +61%
```

Since LLVM 22 links this reproducer cleanly with the pass enabled, the fix exists upstream. That
makes this the highest-value backport of the CCE 21 defects: it is the only one whose resolution
also recovers lost performance.

## Is there a narrower workaround than `-mattr=-mai-insts`?

`-mattr=-mai-insts` disables MFMA/AGPR wholesale, which is why it costs 29x scratch and 61% on
IGR. A flag that suppressed only the faulty *pass* would keep AGPRs and avoid that. **There is
no such flag in CCE 21.0.2** — searched and tested:

| attempt | result |
| --- | --- |
| `--amdgpu-enable-rewrite-partial-reg-uses=false` | still asserts (`SlotIndexes.h:96`) |
| `--amdgpu-spill-vgpr-to-agpr=false` | still asserts |
| a pass-level disable flag | **does not exist** in this build — `llc --help-hidden` exposes no `rewrite-agpr` / `copy-mfma` option |
| the pass's debug counter | added upstream by [llvm#189437](https://github.com/llvm/llvm-project/pull/189437) on 2026-04-10, **after** CCE 21.0.2's 2025-12-12 merge cutoff |

So on this compiler the only lever is the `-mattr` one, and its cost is unavoidable. That is
worth stating explicitly, because "just disable the pass" is the obvious first suggestion and it
is not available here.

It also sharpens the ask: **the value of fixing this is not merely that MFC links.** It is that
the fix is the only path to removing a workaround that currently costs 61% on the most
register-hungry kernel in the application. Backporting the LLVM 22 behaviour — or, failing that,
backporting `llvm#189437` so the pass can at least be disabled selectively — both beat the
status quo.

### Upstream state

The pass has several **open** crash reports and fixes in flight, which suggests this area is
still settling:

| PR | state | subject |
| --- | --- | --- |
| [#205962](https://github.com/llvm/llvm-project/pull/205962) | open | overlapping insert crash during rewrite-agpr-copy-mfma |
| [#198472](https://github.com/llvm/llvm-project/pull/198472) | open | crash from virtual register defs not dominating uses |
| [#200126](https://github.com/llvm/llvm-project/pull/200126) | open | `IMPLICIT_DEF` for a reaching def on an unspilled reload |
| [#167347](https://github.com/llvm/llvm-project/pull/167347) | open | verify dominance when rewriting spills to registers |
| [#190719](https://github.com/llvm/llvm-project/pull/190719) / [#193286](https://github.com/llvm/llvm-project/pull/193286) | merged | verifier crash from multiple live range components |

Our reproducer passes on LLVM 22, so whatever is needed is already in that branch; none of the
above has been confirmed as *the* fix, and the merged one (#190719) has a different symptom
(verifier error vs `SlotIndex` assertion). Identifying the precise commit would need a bisect
across LLVM 21.x→22, which needs a build environment not available here.


## Upstream fix identified: `30007a541493` (llvm/llvm-project#153915)

**"AMDGPU: Fix crash in rewrite AGPR copy MFMA pass on dead valnos"**, 2025-08-16. The entire
change to the pass is three lines:

```diff
@@ -147,6 +147,9 @@ bool AMDGPURewriteAGPRCopyMFMAImpl::run(MachineFunction &MF) const {
+      if (VNI->isPHIDef() || VNI->isUnused())
+        continue;
+
```

### Why this is exactly our assertion

`SlotIndexes.h:96` in the 21.1.8 tree is:

```cpp
IndexListEntry* listEntry() const {
  assert(isValid() && "Attempt to compare reserved index.");
  return lie.getPointer();
}
```

A value number marked **unused** (`VNI->isUnused()`) has an *invalid* definition `SlotIndex`.
The pass iterated such a valno and dereferenced its def index, tripping `isValid()`. The guard
skips dead and PHI-defined valnos before that happens.

### Verified against the exact CCE base

CCE 21.0.2 states *"LLVM 21 base (merges up to Dec 12, 2025 — LLVM version 21.1.8)"*, and
`llvmorg-21.1.8` is a tag in upstream, so this is checkable rather than inferred:

```console
$ git merge-base --is-ancestor 30007a541493 llvmorg-21.1.8   # -> false
$ git merge-base --is-ancestor 30007a541493 llvmorg-22.1.0   # -> true
```

**Absent from 21.1.8, present in 22.1.0** — which is precisely the empirical triage above
(asserts on CCE 21.0.2, clean on LLVM 22 with the pass confirmed enabled). Note the fix predates
CCE's own merge cutoff by four months, so it was available and simply not picked up; this is a
missed backport rather than a timing problem.

### The ask, now concrete

**Backport `30007a541493`.** Three lines, self-contained, with an upstream regression test
(`llvm/test/CodeGen/AMDGPU/av-split-dead-valno-crash.ll`). It removes the need for
`-mattr=-mai-insts`, which is the only thing standing between us and the 61% `igr` regression
documented above — making this the highest-value single change of all the CCE 21 defects.

Other commits to this pass in the 21.1.8→22.1.0 window, none of which match this symptom:
`9a293530d989`, `ff5f396dacc8`, `156f3fce5449`, `eefad7438cf1`, `085471d777a2`, `fdede21ddf05`,
`da8f692e3e6e`, `babdad3fdbc6`, `497d648fcc09`, `8a3891ceadad`, `2183846a15a0`.

## Verdicts

This entry has two runnable scripts, scoring two different things. Both exit 0 when the
result matches this document (see `../README.md` for the convention).

| script | what it scores | measured |
| --- | --- | --- |
| `repro/run.sh [ver]` | the **defect**: `llc` asserts in AMDGPU Rewrite AGPR-Copy-MFMA at `-O2`, clean at `-O0` | CCE 21.0.2 → exit 0 |
| `run_regpressure.sh [ver]` | the **cost** of the `-mai-insts` workaround | CCE 21.0.2 → exit 0 |

`repro/run.sh` needs no GPU, no MPI and no build system — only CCE 21.x's own assertion-enabled
`llc`. It checks both reduction depths and both optimization levels, so a clean `-O0` run is
required alongside the `-O2` assert; an unconditional failure would not be this defect.

CCE 19.0.0 and 20.0.2 do not ship the offending pass and compile the module cleanly, so
`./repro/run.sh 20.0.2` reports MISMATCH **by design** — that is the negative control, not a
regression in the harness.

### Why the cost script scores a signature, not the exact integers

`run_regpressure.sh` re-measured on CCE 21.0.2 reproduces README's table exactly:

```
arm        max_vgpr   max_agpr   max_scratch
baseline   512        256        36
noagpr     256        none       1060
```

but it scores the **mechanism** rather than those numbers:

- baseline must use AGPRs as extra register storage (`agpr > 0`),
- `-mai-insts` must leave none available (`agpr = 0`) and cap VGPRs at 256,
- scratch must grow by at least 10× (measured: **29×**, 36 B → 1060 B).

Register allocation is retuned between compiler and ROCm releases, so pinning 512/256/36
would report a "fix" every time the allocator shifted. What must not change is the signature:
if AGPRs became available again, or scratch stopped growing, the workaround stopped costing
what it costs — and that is the thing worth being told about.

The baseline arm explicitly `unset`s `CRAY_CCE_LLD_ARGS`. MFC's module file exports
`-mai-insts`, which is precisely what the baseline is a control for; without the unset both
arms would measure the same thing and the comparison would be vacuous.

## Searching for a cheaper workaround than `-mai-insts`

`-mattr=-mai-insts` is applied **globally, at link time, to every kernel**, to dodge a crash
in one pass. That is what costs `igr` ~61% (29× scratch growth, measured by
`run_regpressure.sh`). This section records a search for something narrower.

### There is no finer-grained flag

| lever | finding |
| --- | --- |
| gfx90a subtarget features (`llc -mattr=help`) | `mai-insts` is the **only** MFMA/AGPR feature. No finer switch exists at this level. |
| `llc --help-hidden`, all `--amdgpu-*` options | no option gates the AGPR-Copy-MFMA pass. Only `--amdgpu-mfma-padding-ratio` mentions MFMA at all. |

Ten `llc` flags were swept against the real crashing module. Nine still assert:
`-amdgpu-attributor-enable=false`, `-amdgpu-enable-rewrite-partial-reg-uses=false`,
`-amdgpu-dce-in-ra=false`, `-amdgpu-schedule-relaxed-occupancy`,
`-amdgpu-schedule-metric-bias=100`, `-amdgpu-enable-pre-ra-optimizations=false`,
`-amdgpu-disable-unclustered-high-rp-reschedule`, `-amdgpu-mfma-padding-ratio=100`.

### The reduced reproducer is not fully faithful — important

`-amdgpu-use-amdgpu-trackers=true` is the one flag that behaves differently, and it is a
trap:

| module | baseline | `-amdgpu-use-amdgpu-trackers=true` |
| --- | --- | --- |
| `repro/reduced-667-line.ll` | assert | **clean** |
| `repro/crashing_function.bc` | assert | **still asserts** |

So `llvm-reduce` dropped something the real function needs to reach the bad path. Any
candidate workaround validated only against `reduced-667-line.ll` can be a false positive —
**check `crashing_function.bc` too**. This is why `repro/run.sh` scores both modules.

### What does work: per-function attributes

Every one of these clears the assert on the **real** `crashing_function.bc`:

| attribute change | result |
| --- | --- |
| `"amdgpu-agpr-alloc"="0"` → `"0,0"` or `"0,1"` | clean |
| `"amdgpu-flat-work-group-size"="1,256"` → `"1,512"` or `"1,1024"` | clean |
| add `"amdgpu-waves-per-eu"="4,4"` or `"8,8"` | clean |

The kernel as emitted carries `"amdgpu-agpr-alloc"="0"` (min only, max unbounded) and
`"amdgpu-flat-work-group-size"="1,256"` — exactly the crashing combination.

These are **per-function**, which is the whole point: `-mai-insts` penalises every kernel in
the program, while an attribute penalises one. If only a handful of kernels crash, the hot
kernels keep their AGPRs and the `igr` regression does not happen.

### The source-level lever

`amdgpu-flat-work-group-size` is reachable from Fortran. Verified on CCE 21.0.2 — an
OpenACC `vector_length(512)` clause produces `.max_flat_workgroup_size: 512` in the emitted
device image, i.e. `"amdgpu-flat-work-group-size"="1,512"`, the variant shown clean above.
The OpenMP equivalent is `thread_limit(512)`.

So the deployable shape is a `vector_length(512)`/`thread_limit(512)` clause on the crashing
kernels, with `-mai-insts` dropped entirely.

### What is still unmeasured

Two things gate this from being a recommendation:

1. **How many kernels are affected is unknown.** `lld` aborts at the *first* bad function, so
   the crash logs in `artifacts/` name exactly one each. The count only emerges by fixing one
   and re-linking, iteratively. If it is a long tail, per-kernel clauses stop being practical.
2. **The performance cost is unmeasured.** `vector_length(512)` doubles the work-group size,
   which changes occupancy and register budget per thread. It is plausibly much cheaper than
   losing AGPRs program-wide, but "plausibly cheaper" is not a measurement — it needs the same
   grind comparison used for the `-mai-insts` cost.

Neither is a reason to prefer `-mai-insts`; both are reasons not to quote a number yet.
