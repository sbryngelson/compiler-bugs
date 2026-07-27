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

CCE 20.x is untested here: its `lld` rejects 21.x-produced bitcode with
`lld: error: Invalid record`, so testing it requires a full rebuild rather than replaying
the saved module. (An earlier note claiming "20.0.2 → error" as a *result* was wrong — that
was this bitcode-version mismatch, not a verdict on 20.0.2.)

No flag disables the pass. `-plugin-opt=-help-hidden` exposes 112 AMDGPU options; the only
MFMA-related one is `--amdgpu-mfma-padding-ratio`, which does not gate this rewrite.

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

The bitcode itself is not committed here (19 MB / 12 MB).

Reduction was attempted and does **not** work on-system. ROCm 7.2.0 does ship
`llvm-extract` / `llvm-reduce` / `opt` (AMD LLVM 22.0.0git) in
`/opt/rocm-7.2.0/lib/llvm/bin`, and `llvm-extract --func=...` does cut the module from
19 MB to 576 KB. But anything round-tripped through those tools is rejected by CCE's
older LLVM for an unrelated reason:

```
Intrinsic has incorrect argument type!  ptr @llvm.lifetime.start.p5
```

LLVM 22 changed that intrinsic's signature, so the extracted module fails in the `verify`
pass rather than reaching the AGPR rewrite — it is not a valid reproducer. Reducing this
properly needs an LLVM matching CCE 21's vintage (~LLVM 19/20). Until then the full
`-pre-llc.bc` is the reproducer.

## Impact

This is what blocks MFC from moving off `cce/19.0.0` on Frontier. CCE 19.0.0 carries the
store-dropping IPA bug in `../cce19-ipa-contiguous-mix/`, so the two known-good options are
currently: stay on a compiler with a silent wrong-answer bug, or move to 21.x and be unable
to link. CCE 20.x is the obvious middle ground and is being evaluated.
