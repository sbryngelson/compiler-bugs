# Cray CCE 20.0.2: `lld` corrupts the heap in "Infer address spaces" during device LTO

> **Severity:** Abort (heap corruption) — loud, no wrong answers  
> **Fix belongs to:** superseded — CCE 21.x does not exhibit it  
> **Status:** Historical. CCE 20.x is no longer a target; MFC now links and passes 627/627 on CCE 21.0.2. Retained for the record.

**Status: confirmed on stock upstream MFC, no local patches. Reproduces standalone from the
committed bitcode via `lld` alone — no MFC, no build system, no GPU (see Reproducing). Not
yet filed with HPE (the linker asks for a report).**

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending; `lld` itself asks for a report at https://support.hpe.com/ |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) — blocks moving Frontier off `cce/19.0.0` |
| Related | [`../lld-agpr-mfma-assert`](../lld-agpr-mfma-assert) (same class, CCE 21.x), [`../contiguous-mix-dropped-stores`](../contiguous-mix-dropped-stores) |
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

The saved bitcode **is committed here** as `sim-cce20.bc` (16 MB, whole-program
pre-codegen module from a CCE 20.0.2 device link with `-plugin-opt=save-temps`). No MFC
checkout, no build system, no GPU — only CCE 20.0.2's own `lld`:

```bash
cd cce/lld-infer-address-spaces-cce20
/opt/cray/pe/cce/20.0.2/cce-clang/x86_64/bin/lld -flavor gnu --no-undefined -shared \
    -plugin-opt=mcpu=gfx90a -plugin-opt=-disable-promote-alloca-to-lds \
    -plugin-opt=defaults=cray -plugin-opt=O2 -o /tmp/out.amdgpu sim-cce20.bc
```

Verified, exit 134:

```
1. Running pass 'Function Pass Manager' on module 'ld-temp.o'.
2. Running pass 'Infer address spaces' on function '@"s_cbc$m_cbc_$ck_L596_5"'
malloc_consolidate(): unaligned fastbin chunk detected
```

### `llc` does **not** reproduce it — do not use it to conclude the bug is fixed

Running the same module through CCE 20.0.2's `llc` instead of `lld` completes **cleanly**,
and that is a trap worth documenting:

| | `lld -plugin-opt=O2` | `llc -O2` |
|---|---|---|
| exit | **134**, `malloc_consolidate` | **0** |
| wall time | seconds | 1:35 |
| output | — | 151 MB, 1,347,897 lines |
| `.amdhsa_kernel` emitted | — | 453 — the whole program |
| `Infer address spaces` in pipeline | yes | yes (`-debug-pass=Structure`) |
| `s_cbc$m_cbc_$ck_L596_5` processed | yes | yes |

So the `llc` run is not a shallow no-op: it does full codegen of every kernel, with the
named pass in the pipeline and the named function going through it, and still does not
abort. Two reasons:

* `malloc_consolidate()` reports heap corruption *when the allocator next walks the heap*,
  not at the bad write. Whether it trips depends on allocation history, which differs
  completely between `lld`'s LTO pipeline and standalone `llc`. The pass named in the
  message is where the heap happened to be walked.
* `llc -O2` runs the codegen pipeline only. The device link additionally runs the full IPO
  pipeline over the module first, so the IR reaching `Infer address spaces` under `lld` is
  not the IR that reaches it under `llc`.

Use `lld`. A clean `llc` run proves nothing about this defect.

Note also that **CCE 21.0.2 cannot be used to check this module at all** — its LLVM 21.1.8
rejects the LLVM-20 bitcode at load (`LLVM ERROR: unsupported calling convention`, ~19 s),
so it never reaches the pass. That 21.x does not exhibit this crash is established by CCE
21 builds of MFC linking successfully once `../lld-agpr-mfma-assert` is worked around — not
by anything replayable from this artifact.

To regenerate from scratch:

```bash
git clone https://github.com/MFlowCode/MFC && cd MFC
# toolchain/modules, Frontier line: cpe/25.09 cce/20.0.2 rocm/6.4.2
# and drop rocprofiler-compute from f-gpu (it silently reverts PrgEnv to cce/18.0.1)
source ./mfc.sh load -c f -m g
./mfc.sh build -t simulation --gpu mp
```

Note that reduction with ROCm's LLVM tools does not work — see the note in
`../lld-agpr-mfma-assert/README.md`: LLVM 22 changed the `llvm.lifetime.start` signature,
so anything round-tripped through them is rejected by CCE's older LLVM before it reaches
the failing pass.

There is **no reduced reproducer** for this one. The route would be
`llvm-extract --func='s_cbc$m_cbc_$ck_L596_5'` followed by `llvm-reduce` with an
interestingness test grepping for `malloc_consolidate` — the procedure used for
`../lld-agpr-mfma-assert`. Not done. Note it would have to drive `lld`, not `llc`, for the
reasons above, which makes the interestingness test slower and the reduction less
convenient.


## Reproduction scope: needs the full LTO link, not an isolated pass

`sim-cce20.bc` does **not** reproduce the corruption when the pass is run on its own — including
under the very compiler that crashed:

| toolchain | `opt -passes=infer-address-spaces sim-cce20.bc` |
| --- | --- |
| CCE 20.0.0 | clean |
| **CCE 20.0.2** (the crashing version) | **clean** |
| CCE 21.0.0 | clean |
| ROCm LLVM 20 / 22 | clean |

So the bitcode alone is not sufficient. Two reasons, both worth knowing before anyone spends
time on it:

1. The failure is **heap corruption**, not an assertion. Whether it manifests depends on the
   allocator's state — which objects were allocated and freed before the pass ran. `opt` running
   one pass on one module has an entirely different allocation history from `lld` performing a
   full LTO link of the whole program.
2. `lld`'s LTO pipeline runs the pass in a different context (parallel codegen, its own
   allocator traffic) than `opt` does.

Reproducing it therefore requires the original link, not a reduced pass invocation. That is also
why it was never reduced further: heap corruption resists reduction, because shrinking the input
changes the allocation pattern that triggers it.

## Why this is now historical

CCE 20.x was only ever a waypoint. The port went to **CCE 21.0.2**, which does not exhibit this
defect — it has a different device-link failure
([`../lld-agpr-mfma-assert`](../lld-agpr-mfma-assert), an assertion rather than heap corruption),
and with that worked around MFC passes **627/627 on both offload backends**.

Kept because it documents that *no* CCE between 19 and 21 could link MFC — 20.x for this reason,
21.x for the AGPR assert — which is the context for why the port skipped 20.x entirely.
