# Cray CCE compiler defects

Reproducers for Cray Fortran / CCE defects found on OLCF Frontier (MI250X, gfx90a),
mostly while porting the MFC CFD solver (<https://github.com/MFlowCode/MFC>) across
CCE versions. Each directory is self-contained: reproducer, README with verified
steps, supporting disassembly or bitcode.

Most of these were found moving MFC from **CCE 19.0.0 + ROCm 6.3.1 (`cpe/25.03`)** to
**CCE 21.0.2 + ROCm 7.2.0 (`cpe/26.03`)**. Offload is OpenACC (`-hacc`) and OpenMP
target (`-homp`); both are affected unless noted.

## Current defects

| Directory | Defect | CCE | Severity | Reproducer |
|---|---|---|---|---|
| [`lld-agpr-mfma-assert`](lld-agpr-mfma-assert) | `lld`/`llc` asserts in `AMDGPU Rewrite AGPR-Copy-MFMA` | 21.0.0, 21.0.2 | build blocker | LLVM IR, `llc` |
| [`promote-alloca-dropped-store`](promote-alloca-dropped-store) | Dynamically-indexed store into a 1-based private array is **silently discarded** | 21.0.2 | **wrong answers** | **Fortran, 24 lines** |
| [`omp-defaultmap-scalar-override`](omp-defaultmap-scalar-override) | Explicit `map(to:)` on a scalar overridden by `defaultmap(...:scalar)`; `atomic capture` then hands out duplicate indices | 21.0.2 | **wrong answers** | **Fortran, 30 lines** |
| [`explicit-shape-dummy-lost-writes`](explicit-shape-dummy-lost-writes) | Device writes through an **explicit-shape** dummy with a runtime extent are lost; assumed-shape is correct | 19.0.0 **and** 21.0.2 | **wrong answers** | **Fortran, 2 files** |
| [`private-flat-pointer`](private-flat-pointer) | Flat pointer built from a private offset without the aperture; frame offset 0 stores 4 GiB out of bounds | 19.0.0 **and** 21.0.2 | crash | LLVM IR, 15 lines |
| [`lld-infer-address-spaces-cce20`](lld-infer-address-spaces-cce20) | `lld` corrupts the heap in `Infer address spaces` | 20.0.2 | build blocker | whole-program bitcode, `lld` |
| [`contiguous-mix-dropped-stores`](contiguous-mix-dropped-stores) | Stores to a non-`CONTIGUOUS` dummy dropped when the same call also passes a `CONTIGUOUS` one | 19.x only, **fixed in 20.0.0** | **wrong answers** | Fortran, 5 files |
| [`defaultmap-firstprivate`](defaultmap-firstprivate) | `defaultmap(firstprivate:scalar)` does not actually firstprivate the scalars → `NaN` | 19.0.0 | **wrong answers** | Fortran |
| [`mir-roundtrip-bb-name`](mir-roundtrip-bb-name) | MIR round-trip loses a basic-block name | 21.x | tooling | hit while reducing the AGPR bug |
| [`cce21-runtime-failures`](cce21-runtime-failures) | Runtime failures recorded during the 21.0.2 port, attribution pending | 21.0.2 | — | test log |

**Start with `promote-alloca-dropped-store` and `omp-defaultmap-scalar-override`.**
Those are the silent miscompilations — both have short Fortran reproducers, and both
produced wrong numbers a user would have shipped.
`omp-defaultmap-scalar-override` additionally makes the same source correct under
OpenACC and wrong under OpenMP.

Note that `defaultmap-firstprivate` and `omp-defaultmap-scalar-override` are **two
different defects** that happen to involve the same clause, on different CCE major
versions and in opposite directions. Each README says so; do not merge them.

## Running the reproducers

Every entry has a `run.sh` or `build_and_run.sh` that verifies the toolchain before
measuring anything, via [`lib/guard.sh`](lib/guard.sh):

```bash
cce/lld-agpr-mfma-assert/repro/run.sh               # no GPU, no modules needed
cce/private-flat-pointer/run.sh                     # no GPU, no modules needed
cce/lld-infer-address-spaces-cce20/run.sh           # no GPU, no modules needed
cce/promote-alloca-dropped-store/build_and_run.sh   # builds, prints the srun line
cce/omp-defaultmap-scalar-override/build_and_run.sh # builds, prints the srun line
cce/explicit-shape-dummy-lost-writes/build_and_run.sh # builds, prints the srun line
cce/contiguous-mix-dropped-stores/build_and_run.sh  # login node, host-only code
```

Two of these have **no good-compiler control**: `private-flat-pointer` and
`explicit-shape-dummy-lost-writes` affect CCE 19.0.0 and 21.0.2 alike, so there is
no version to diff against. For those, a `PASS` should raise suspicion of the
toolchain before it raises hope of a fix.

### Why the guard exists — read this before trusting a PASS

These reproducers can all produce a **false negative**, and the usual cause is the
module environment. On Frontier:

```bash
module load cpe/26.03 cce/21.0.2 rocm/7.2.0 craype-accel-amd-gfx90a   # LOOKS fine
```

*appears* to work and does not. `ftn` keeps dispatching the system default CCE
(18.0.1) with no accelerator target, so `-hacc` / `-homp` are silently ignored
(`ftn-1350`), the reproducer builds as **host** code, and it prints **PASS** —
indistinguishable from a fixed compiler. Loading order matters:

```bash
module reset
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2
ftn --version | head -1        # must report 21.0.2
```

Each CCE needs its matching `cpe` (25.03 → 19.0.0, 25.09 → 20.0.x, 26.03 → 21.0.x)
and a compatible `rocm` on `LD_LIBRARY_PATH`, or the binary fails to start on
`libamdhip64.so.6`.

The scripts verify rather than assume: wrong `ftn` version, missing accel target, or
a binary with **no embedded AMDGPU image** are all hard errors with the fix printed.
That last check is the strongest one — even if every environment heuristic were
fooled, a host-only build provably contains no GPU code.

**Watch the polarity.** In the miscompilation reproducers, the program printing
`FAIL` is the bug *reproducing*. A `PASS` on an affected compiler means either the
defect is fixed or something in the toolchain is not what you think it is; check the
second before believing the first.

### Two traps worth naming

* **`llc` is not `lld`.** `lld-infer-address-spaces-cce20` reproduces through `lld`
  and **not** through `llc` — the same module through `llc -O2` does full codegen of
  all 453 kernels, with the failing pass in the pipeline, and exits 0. A clean `llc`
  run proves nothing there. (`lld-agpr-mfma-assert`, by contrast, does reproduce
  under `llc`.)
* **Cross-version bitcode does not load.** CCE 21.0.2's LLVM 21.1.8 rejects the
  LLVM-20 module in `lld-infer-address-spaces-cce20` at load
  (`LLVM ERROR: unsupported calling convention`), so it never reaches the pass.
  Absence of a crash there is absence of the *pass*, not evidence of a fix.

## Tooling notes

`llvm-objdump` on the **host** executable crashes (`Disassembly not yet supported for
subtarget`), and forcing `--mcpu=gfx90a` on x86 bytes emits tens of thousands of lines
of garbage. The device code is an AMDGPU ELF embedded in the executable;
[`lib/extract-device-image.py`](lib/extract-device-image.py) finds it by scanning for
`\x7fELF` with `e_machine == 224` and trimming to `e_shoff + e_shnum*e_shentsize`:

```bash
python3 cce/lib/extract-device-image.py ./my_executable dev.elf
/opt/rocm-6.3.1/llvm/bin/llvm-objdump -d --triple=amdgcn-amd-amdhsa --mcpu=gfx90a dev.elf > dis.txt
wc -l dis.txt    # always check this is non-zero before believing a zero count
```

ROCm 7.2.0's `llvm-objdump` silently produces **no output** on these images; use the
6.3.1 one. CCE's own LLVM tools (`llc`, `lld`, `llvm-extract`, `llvm-reduce`) live in
`/opt/cray/pe/cce/<version>/cce-clang/x86_64/bin/` and are **not** on `PATH` after
`module load cce` — use absolute paths.

On Lustre, plain `du` reports allocated blocks and badly understates file sizes; use
`du --apparent-size` or `ls -l`.

---

## Archive: CCE 15.0.1 OpenACC `declare` bugs

An older set, unrelated to the CCE 19→21 port above. Minimal reproducers for OpenACC
bugs in **CCE 15.0.1** on Frontier, all involving `!$acc declare` (link or create) on
module-scope variables and/or nested allocatable derived types. Bug reports:
**OLCFDEV-1416, CAST-31898**. Compile with `ftn -h acc`; run with `srun -n 1 ./test`.

| Dir | Variable type | `declare` clause | Kernel | Issue |
|-----|--------------|------------------|--------|-------|
| test-bug1 | `allocatable` scalar array | `link` | `parallel loop` + `routine seq` | seq routine writing to `declare link` array called from parallel loop |
| test-bug2 | `allocatable` array, non-zero lower bound (`-5:5`) | `link` | `parallel loop` | non-unit lower bound under `declare link` |
| test-bug3 | nested allocatable derived type (`outer%inner(i)%data`) | none (manual `enter data`) | `kernels` | 2-level nested struct, element-wise `enter data copyin` |
| test-bug4 | derived type with allocatable member, scalar struct | `declare create` on struct | `parallel loop` + `routine seq` | `declare create` on struct + `enter data create` on member + seq routine |
| test-bug5 | same as test-bug3, smaller dims (ninner=2, ndat=2) | none | `kernels` | minimal 2-level nested struct reproducer |
| test-bug6 | 2-level nested struct, outer is allocatable array | `declare link` on outer | `kernels` | 3-level loop over `outer(k)%inner(i)%data(j)` with `declare link` |
| test-bug7 | same as test-bug6, multi-file build | `declare link` on outer | `parallel loop` + `routine seq` (multi-TU) | seq routine + present clause across separate compilation units |
| test-bug8 | 2-level nested struct, outer is scalar | `declare create` on outer | `kernels` + `routine seq` | scalar outer struct with `declare create`, seq routine writes member |
| test-bug9 | 2-level nested struct, outer is allocatable array | none (declare link commented out) | `kernels` | same as test-bug6 without any declare — tests manual enter data only |
| test-bug10 | flat array of derived types (`inner(ninner)%data`) | `declare link` on inner | `kernels default(present)` + `routine seq` | element-wise `enter data` + seq routine + `default(present)` |
| test-bug11 | 2-level nested struct, outer is allocatable array | `declare create` on outer | `kernels default(present)` | `declare create` + `default(present)` with nested struct |
| test-bug12 | same as test-bug11 | `declare link` on outer | `kernels default(present)` | `declare link` vs `declare create` comparison for test-bug11 |

`archive/` — cases that were fixed in CCE or kept for reference (allocatable derived
types, scalar control cases).
