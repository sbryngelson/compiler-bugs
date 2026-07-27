# Cray CCE 20.0.2: `lld` corrupts the heap in "Infer address spaces" during device LTO

**Status: confirmed on stock upstream MFC, no local patches. Not yet filed with HPE
(the linker asks for a report).**

## Symptom

Every Fortran source compiles — zero `ftn` errors — and the **device LTO link dies**:

```
[100%] Linking Fortran executable simulation
PLEASE submit a bug report to HPE at https://support.hpe.com/ and include the crash backtrace.
Stack dump:
0. Program arguments: /opt/cray/pe/cce/20.0.2/cce-clang/x86_64/bin/lld -flavor gnu
   --no-undefined -shared -plugin-opt=mcpu=gfx90a
   -plugin-opt=-disable-promote-alloca-to-lds -plugin-opt=defaults=cray
   -plugin-opt=O2 -plugin-opt=save-temps
   -o .../simulation-cce-openmppost_lld.amdgpu .../simulation-cce-openmp-pre-llc.bc
1. Running pass 'Function Pass Manager' on module 'ld-temp.o'.
2. Running pass 'Infer address spaces' on function '@"s_cbc$m_cbc_$ck_L596_13"'
malloc_consolidate(): unaligned fastbin chunk detected
```

Heap corruption inside the `Infer address spaces` pass, on a device kernel outlined from
`src/simulation/m_cbc.fpp:596`.

## This is not caused by anything in MFC

Run as a controlled pair on the same compiler, same ROCm, same dependencies, differing
only by one commit:

| build | `INLINENEVER` directives active | result |
|---|---|---|
| with a local macro change that activates 51 `!DIR$ INLINEALWAYS`/`INLINENEVER` directives | 4 | crash |
| **control — stock upstream master, that commit reverted** | **0** | **same crash, same pass** |

Both `rc=143`, both 0 compile errors, both `Running pass 'Infer address spaces'`. See
`artifacts/crash_control_plain_master.txt`. The control was run specifically because the
local change alters device codegen and could plausibly have been the trigger; it is not.

## Only the optimising LTO pipeline is affected

`artifacts/opt_level_sweep.txt` — replaying the saved bitcode through `lld` at each device
LTO level:

```
cce/20.0.2 O2  -> CRASH  Infer address spaces
cce/20.0.2 O1  -> CRASH  Infer address spaces
cce/20.0.2 O0  -> OK
```

CCE 21.x behaves the same way (`O2` and `O1` crash, `O0` links), though in a different
pass. So both defects live in the optimising device-LTO pipeline, and `O0` is the only
level that survives.

Appending `-plugin-opt=O0` *after* the driver's `-plugin-opt=O2` overrides it and links
when `lld` is invoked by hand. **But there is no supported way to get it there through the
Cray driver**, so this is a diagnostic result, not a usable workaround:

| attempt | what happens |
|---|---|
| `-Wl,-plugin-opt=O0` | goes to the **host** linker (GNU `ld`) -> `ld: bad -plugin-opt option` |
| `-Wc,-plugin-opt=O0` | documented as "arguments to the device linker", but actually reaches **`llvm-link`** -> `llvm-link: Unknown command line argument '-plugin-opt=O0'` |
| PATH shim in front of `lld` | the driver invokes `lld` by **absolute path** (`/opt/cray/pe/cce/20.0.2/cce-clang/x86_64/bin/lld`), so it is never consulted |

The practical consequence is that this bug fully blocks the build. The `O0` result is still
useful evidence: it localises the defect to the optimising device-LTO pipeline rather than
to code generation or to MFC's source.

## Relationship to the CCE 21.x bug

This is a *different* crash from `../lld-agpr-mfma-assert/`, in a different pass and on a
different function, but the same category: `lld` failing during AMDGPU device LTO on a
large Fortran offload code.

| CCE | MFC on Frontier (MI250X) |
|---|---|
| 19.0.0 | links and runs, but **silently drops stores** — see `../contiguous-mix-dropped-stores/` |
| 20.0.2 | **cannot link** — this bug |
| 21.0.0, 21.0.2 | **cannot link** — `../lld-agpr-mfma-assert/` |

So on Frontier today there is no CCE that both links this code and computes correct
answers. MFC works around the 19.0.0 miscompile in source and therefore stays on 19.0.0.

## Reproducing

`-plugin-opt=save-temps` is already in the link line, so a failed build leaves the input
bitcode behind and the crash replays standalone:

```bash
lld -flavor gnu --no-undefined -shared -plugin-opt=mcpu=gfx90a \
    -plugin-opt=-disable-promote-alloca-to-lds -plugin-opt=defaults=cray \
    -plugin-opt=O2 -o /tmp/out.amdgpu simulation-cce-openmp-pre-llc.bc
```

To regenerate from scratch:

```bash
git clone https://github.com/MFlowCode/MFC && cd MFC
# toolchain/modules, Frontier line: cpe/25.09 cce/20.0.2 rocm/6.4.2
# and drop rocprofiler-compute from f-gpu (it silently reverts PrgEnv to cce/18.0.1)
source ./mfc.sh load -c f -m g
./mfc.sh build -t simulation --gpu mp
```

Bitcode is not committed (19 MB). Note that reduction with ROCm's LLVM tools does not
work — see the note in `../lld-agpr-mfma-assert/README.md`: LLVM 22 changed the
`llvm.lifetime.start` signature, so anything round-tripped through them is rejected by
CCE's older LLVM before it reaches the failing pass.
