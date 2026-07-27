# Cray CCE 21.x: `lld` asserts in "AMDGPU Rewrite AGPR-Copy-MFMA" during device LTO

**Status: confirmed on CCE 21.0.0 and 21.0.2. Blocks any GPU-offload build of MFC.
Not yet filed with HPE (the linker itself asks for a report).**

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

## Root cause investigation

Ruled out, each with an experiment rather than by inspection:

| hypothesis | test | result |
|---|---|---|
| MFC's macro change activating 51 `INLINEALWAYS`/`INLINENEVER` directives | full build with the commit reverted (`INLINENEVER count = 0`) | ✗ crashes identically on stock upstream master |
| the `"amdgpu-agpr-alloc"="0"` annotation is mishandled | remove it; set it to `4`; set it to `32` | ✗ crashes in all four variants |
| ordinary register-spill pressure driving AGPR use | add `amdgpu-waves-per-eu=1,1`; `amdgpu-num-vgpr=256`; `amdgpu-flat-work-group-size=1,64` | ✗ all still crash |
| one unlucky kernel, fixable in MFC source | delete the offender, re-run | ✗ a second appears (`s_compute_bubble_el_dynamics`, `m_bubbles_EL.fpp:633`) |

What stands: the pass is [new in LLVM](https://www.mail-archive.com/llvm-branch-commits@lists.llvm.org/msg51361.html)
(PR #145024, "replace VGPR MFMAs with AGPR") and still
[gaining tests for AGPR interference](https://www.mail-archive.com/llvm-branch-commits@lists.llvm.org/msg53713.html)
(PR #149026). **MFC contains no MFMA/matrix instructions at all**, so the pass is asserting
while examining code it should have nothing to transform in. The assertion is a `SlotIndex`
that fails `isValid()` — i.e. something queries an index for an instruction that is not in
the `SlotIndexes` map (typically erased, or newly created without an index), which is
consistent with the pass consulting `LiveIntervals` for a value it has already invalidated.

Pinning the exact statement needs either an LLVM built with `-g` or the upstream source for
`AMDGPURewriteAGPRCopyMFMA.cpp` at CCE 21.0.2's vintage; the shipped `llc` is optimised so
the frame is inlined away.

## Trigger

The named function is the second `GPU_PARALLEL_LOOP` in `s_compute_bubble_EE_source`
(`src/simulation/m_bubbles_EE.fpp:185`) — a very high-register-pressure kernel: 17
privatised scalars/arrays plus a `copy` reduction, over a `collapse(3)` loop nest. That is
consistent with a pass that rewrites AGPR copies running into an invalid slot index during
register allocation.

Note MFC uses no MFMA/matrix instructions at all, so this pass should be inert for it.

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
| 21.0.0, 21.0.2 | **no** — this bug | — |

There is currently no CCE on Frontier that both links this code and computes correct
answers, and no supported way to force the device link to `O0` (see the CCE 20 report).
