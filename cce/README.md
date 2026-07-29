# Cray CCE compiler defects

Reproducers for Cray Fortran / CCE defects found on OLCF Frontier (MI250X, gfx90a),
mostly while porting the MFC CFD solver (<https://github.com/MFlowCode/MFC>) across
CCE versions. Each directory is self-contained: reproducer, README with verified
steps, supporting disassembly or bitcode.

Most of these were found moving MFC from **CCE 19.0.0 + ROCm 6.3.1 (`cpe/25.03`)** to
**CCE 21.0.2 + ROCm 7.2.0 (`cpe/26.03`)**. Offload is OpenACC (`-hacc`) and OpenMP
target (`-homp`); both are affected unless noted.


**Background:** [`PIPELINE.md`](PIPELINE.md) documents how CCE lowers Fortran to AMD GPU
code — the front end's own inliner, the `i64` pointer ABI, where the device IR lives and how
to extract it. Several defects below only make sense against that.

## CCE 21.0.2 status at a glance

CCE 21.0.2 states it is *"LLVM 21 base (merges up to Dec 12, 2025 — LLVM version 21.1.8)"*.
Because `llvmorg-21.1.8` is a real upstream tag, every claim below is checkable with
`git merge-base --is-ancestor <commit> llvmorg-21.1.8`.

### Fixes that exist upstream — backport these

| defect | upstream fix | landed | vs CCE cutoff | size |
|---|---|---|---|---|
| [lld-agpr-mfma-assert](lld-agpr-mfma-assert) | [`30007a541493`](https://github.com/llvm/llvm-project/pull/153915) | 2025-08-16 | **4 months before** | 3 lines + test |
| [promote-alloca-dropped-store](promote-alloca-dropped-store) | [`b965f265388a`](https://github.com/llvm/llvm-project/pull/157682) | 2025-09-10 | **3 months before** | `udivrem`→`sdivrem` |
| [instcombine-phi-addrspace-cast](instcombine-phi-addrspace-cast) | [`6d033abb7`](https://github.com/llvm/llvm-project/pull/181064) | 2026-02-15 | 2 months after | 3-line type guard |

**Two of these three were fixed upstream *before* CCE 21.0.2's own merge cutoff and were not
picked up.** Both are small, self-contained, and ship with upstream regression tests. That is a
different problem from "the compiler has bugs" — it suggests the branch is not tracking AMDGPU
back-end fixes.

The AGPR one is the highest-value single change in this directory. Its absence forces
`-mattr=-mai-insts`, which disables AGPRs on gfx90a's unified register file, costing **29x more
scratch** and a **61% slowdown** on MFC's IGR solver. Three lines of upstream code recover it.

### Defects with no upstream fix — these are CCE's own

| defect | layer | mechanism |
|---|---|---|
| [defaultmap-zeroes-resident-arrays](defaultmap-zeroes-resident-arrays) + [omp-defaultmap-scalar-override](omp-defaultmap-scalar-override) | Fortran OpenMP lowering | one defect, two faces: a `defaultmap` clause privatizes a scalar carrying an explicit `map(tofrom:)`; the atomic then targets `addrspace(5)` |
| [defaultmap-overrides-private](defaultmap-overrides-private) | host runtime | *distinct* from the above — device IR is identical across arms; a present-table lookup is issued for an explicitly-`private()` variable |
| [private-flat-pointer](private-flat-pointer) | Fortran front end | private→flat via `ptrtoint`/`zext`/`inttoptr` drops the scratch aperture, so offset 0 is indistinguishable from null. **LLVM is correct here** |
| [explicit-shape-dummy-lost-writes](explicit-shape-dummy-lost-writes) | Fortran front end | no extent emitted for an explicit-shape dummy → 0-byte map → runtime returns the host pointer |
| [inlinenever-ignored-device](inlinenever-ignored-device) | Fortran front end | `!DIR$ INLINENEVER` accepted, then emitted with `alwaysinline` |

### Belongs upstream, not to HPE

| defect | filed |
|---|---|
| [mir-roundtrip-bb-name](mir-roundtrip-bb-name) | [llvm#212785](https://github.com/llvm/llvm-project/issues/212785) — reproduces byte-identically on stock LLVM 22 |

### Closed / historical

| entry | why |
|---|---|
| [cce21-runtime-failures](cce21-runtime-failures) | all 21 failures attributed to the defects above; MFC now passes 627/627 on both backends |
| [lld-infer-address-spaces-cce20](lld-infer-address-spaces-cce20) | CCE 20.x only; not a target |
| [contiguous-mix-dropped-stores](contiguous-mix-dropped-stores) | fixed in CCE 20.0.0 |

### How these were verified

Reproducers are run against every toolchain on the machine — CCE 19.0.0 / 20.0.0 / 20.0.2 /
21.0.0 / 21.0.2 and the ROCm-shipped LLVM 20 / 22 / 23 — so "fixed in LLVM 22" is measured, not
inferred. Where a pass is involved, the triage confirms the pass actually *runs* in the passing
arm (`-debug-pass=Structure`), because a silently dropped pass looks identical to a fix.

`extract-device-ir.sh` (in several entries) pulls the device IR CCE hands to the AMDGPU pipeline
out of the `.cray.llvm.offloading` ELF section — `-plugin-opt=save-temps` does **not** work for a
direct `ftn` invocation, and that was the blocker on IR-level analysis for a long time.


## Current defects

| Directory | Defect | CCE | Severity | Reproducer |
|---|---|---|---|---|
| [`lld-agpr-mfma-assert`](lld-agpr-mfma-assert) | `lld`/`llc` asserts in `AMDGPU Rewrite AGPR-Copy-MFMA` | 21.0.0, 21.0.2 | build blocker | LLVM IR, `llc` |
| [`promote-alloca-dropped-store`](promote-alloca-dropped-store) | Dynamically-indexed store into a 1-based private array is **silently discarded** | 21.0.2 | **wrong answers** | **Fortran, 24 lines** |
| [`omp-defaultmap-scalar-override`](omp-defaultmap-scalar-override) | Explicit `map(to:)` on a scalar overridden by `defaultmap(...:scalar)`; `atomic capture` then hands out duplicate indices | 21.0.2 | **wrong answers** | **Fortran, 30 lines** |
| [`defaultmap-zeroes-resident-arrays`](defaultmap-zeroes-resident-arrays) | Any `defaultmap` clause makes a device-resident array read as **all zeros** inside the region | 21.0.2 | **wrong answers** | **Fortran, 7 files** |
| [`explicit-shape-dummy-lost-writes`](explicit-shape-dummy-lost-writes) | Device writes through an **explicit-shape** dummy with a runtime extent are lost; assumed-shape is correct | 21.0.2, also 19.0.0 | **wrong answers** | **Fortran, 2 files** |
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

Three entries involve `defaultmap` and they are **not** all the same thing:

* `defaultmap-firstprivate` — CCE **19**, `defaultmap(firstprivate:scalar)` fails to
  firstprivate the scalars it covers, giving `NaN`.
* `omp-defaultmap-scalar-override` — CCE **21**, `defaultmap(...:scalar)` overrides an
  *explicit* `map(to:)` on a scalar.
* `defaultmap-zeroes-resident-arrays` — CCE **21**, any `defaultmap` clause makes a
  device-**resident array** read as zeros.

The last two are very likely one defect seen from two angles: in both, the presence of
a `defaultmap` clause breaks data-environment resolution for a variable that another
mechanism should have resolved. The CCE 19 one is separate and runs the opposite way.

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
cce/defaultmap-zeroes-resident-arrays/build_and_run.sh # builds, prints the srun line
cce/contiguous-mix-dropped-stores/build_and_run.sh  # login node, host-only code
```

`private-flat-pointer` has **no good-compiler control** — it affects CCE 19.0.0 and
21.0.2 alike, so there is no version to diff against, and a `PASS` there should raise
suspicion of the toolchain before it raises hope of a fix.

**A comparison is only evidence if the control arm passes.** Two reproducers in this
set were initially got wrong by controls that failed for reasons unrelated to the
defect under test — see the "got wrong twice" section of
[`explicit-shape-dummy-lost-writes`](explicit-shape-dummy-lost-writes). If a control
row fails, fix the control before drawing any conclusion from the failing row.

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
| [test-bug1](archive/acc-declare-cce15/test-bug1) | `allocatable` scalar array | `link` | `parallel loop` + `routine seq` | seq routine writing to `declare link` array called from parallel loop |
| [test-bug2](archive/acc-declare-cce15/test-bug2) | `allocatable` array, non-zero lower bound (`-5:5`) | `link` | `parallel loop` | non-unit lower bound under `declare link` |
| [test-bug3](archive/acc-declare-cce15/test-bug3) | nested allocatable derived type (`outer%inner(i)%data`) | none (manual `enter data`) | `kernels` | 2-level nested struct, element-wise `enter data copyin` |
| [test-bug4](archive/acc-declare-cce15/test-bug4) | derived type with allocatable member, scalar struct | `declare create` on struct | `parallel loop` + `routine seq` | `declare create` on struct + `enter data create` on member + seq routine |
| [test-bug5](archive/acc-declare-cce15/test-bug5) | same as test-bug3, smaller dims (ninner=2, ndat=2) | none | `kernels` | minimal 2-level nested struct reproducer |
| [test-bug6](archive/acc-declare-cce15/test-bug6) | 2-level nested struct, outer is allocatable array | `declare link` on outer | `kernels` | 3-level loop over `outer(k)%inner(i)%data(j)` with `declare link` |
| [test-bug7](archive/acc-declare-cce15/test-bug7) | same as test-bug6, multi-file build | `declare link` on outer | `parallel loop` + `routine seq` (multi-TU) | seq routine + present clause across separate compilation units |
| [test-bug8](archive/acc-declare-cce15/test-bug8) | 2-level nested struct, outer is scalar | `declare create` on outer | `kernels` + `routine seq` | scalar outer struct with `declare create`, seq routine writes member |
| [test-bug9](archive/acc-declare-cce15/test-bug9) | 2-level nested struct, outer is allocatable array | none (declare link commented out) | `kernels` | same as test-bug6 without any declare — tests manual enter data only |
| [test-bug10](archive/acc-declare-cce15/test-bug10) | flat array of derived types (`inner(ninner)%data`) | `declare link` on inner | `kernels default(present)` + `routine seq` | element-wise `enter data` + seq routine + `default(present)` |
| [test-bug11](archive/acc-declare-cce15/test-bug11) | 2-level nested struct, outer is allocatable array | `declare create` on outer | `kernels default(present)` | `declare create` + `default(present)` with nested struct |
| [test-bug12](archive/acc-declare-cce15/test-bug12) | same as test-bug11 | `declare link` on outer | `kernels default(present)` | `declare link` vs `declare create` comparison for test-bug11 |

`archive/` — cases that were fixed in CCE or kept for reference (allocatable derived
types, scalar control cases).


## The 12 `!$acc declare` cases — archived, see [archive/acc-declare-cce15](archive/acc-declare-cce15)

**Moved to [`archive/acc-declare-cce15/`](archive/acc-declare-cce15)** so they are not confused
with the actively tracked port defects. They date from **CCE 15.0.1**, were reported as
`OLCFDEV-1416` / `CAST-31898`, and predate the CCE 19->21 work by years.

**Re-run on CCE 21.0.2 (2026-07-29): inconclusive, and the reason is a defect in the
reproducers themselves.**

| outcome | count | detail |
| --- | --- | --- |
| build + run | 11 | produce output |
| build failure | 1 | `test-bug7` — multi-TU; module compile order, not necessarily a compiler fault |
| **produce no output at all** | 4 | `test-bug6`, `9`, `11`, `12` |

**None of the twelve self-check.** They print values and rely on a human comparing them against
expectation; no expected output is recorded anywhere in the directory. So a re-run establishes
only that they still compile and execute — it cannot say whether the original defects are fixed.
The four silent ones are suspicious but uninterpretable without a reference result.

To make these useful again someone would need to add a pass/fail criterion to each — the
expected values, or a self-checking harness like the newer entries use (`nbad=0 ... PASS`). Until
then their status on any compiler after 15.0.1 is genuinely unknown, and this section should not
be read as "still broken" or "now fixed".

That is worth stating plainly: an unscoreable reproducer is close to no reproducer. The newer
entries in this directory were all written to self-verify for exactly this reason.

## Upstream or Cray-side? Tested attributions

Most entries here assert where the fix belongs. Until now those attributions were *inferred*
— from reading upstream diffs, and from comparing against ROCm's LLVM, whose **assertions are
compiled out** so its clean runs cannot distinguish "fixed" from "not caught".

A stock **`llvmorg-21.1.8`** — CCE 21.0.2's exact base — is now built with
`-DLLVM_ENABLE_ASSERTIONS=ON` at
`/lustre/orion/cfd154/scratch/sbryngelson/llvm-src/build-2118/bin/`. Rebuild it with
`joblogs/resume_llvm2118.sh` (idempotent; refuses to report if assertions came out off).

Every IR-level reproducer run through it, same invocation as CCE:

| entry | CCE 21.0.2 | stock 21.1.8 +assert | attribution |
| --- | --- | --- | --- |
| [`instcombine-phi-addrspace-cast`](instcombine-phi-addrspace-cast) | assert | **assert** | upstream defect — backport is the whole ask |
| [`promote-alloca-dropped-store`](promote-alloca-dropped-store) | wrong index | **wrong index** | upstream defect — backport is the whole ask |
| [`mir-roundtrip-bb-name`](mir-roundtrip-bb-name) | broken | **broken** | upstream (filed llvm#212785) |
| [`private-flat-pointer`](private-flat-pointer) | poisoned store | **poisoned store** | **CCE front end** — see below |
| [`lld-agpr-mfma-assert`](lld-agpr-mfma-assert) | assert | **clean** | **Cray-side trigger** — see below |

Two rows need reading carefully, and both were previously stated wrongly:

**`private-flat-pointer` — agreement *confirms* the front-end attribution.** Its reproducers
are hand-written `.ll` containing the bad pattern CCE's Fortran front end emits (a private
pointer converted to flat without the aperture). Stock LLVM producing the same wild store is
the **expected control**: it shows LLVM faithfully compiles the IR it was given, so the defect
is upstream of the IR — in the front end. A *clean* stock result would have been the surprise.

**`lld-agpr-mfma-assert` — the backport claim did not survive.** Stock 21.1.8 compiles the real
crashing module cleanly, and stays clean when forced to maximum register pressure, with the
pass verified as running and AGPRs verified as allocated. So the dead/PHI valno is produced by
CCE-side register allocation; the missing upstream guard is latent. The entry previously called
the backport "the fix" — it is worth carrying, but claiming upstream reproduces this would be
false.

### What this method cannot reach

The OpenMP and Fortran entries — the whole `defaultmap-*` family,
`omp-defaultmap-scalar-override`, `explicit-shape-dummy-lost-writes`,
`inlinenever-ignored-device`, `contiguous-mix-dropped-stores` — live in CCE's **proprietary
Fortran front end and OpenMP lowering**. There is no upstream counterpart to run them against,
so "does stock LLVM reproduce it?" is not a question that can be asked. For those, the
available controls are the ones each entry already uses: an OpenACC arm beside the OpenMP arm,
an explicit clause beside the `defaultmap` one, and cross-checking against **amdflang**, which
is open source.

`lld-infer-address-spaces-cce20` is testable in principle but needs `ld.lld`, not `llc` — its
README notes the same module through `llc` completes cleanly and proves nothing.

## Hit a link crash?

Start at [`LINK-CRASHES.md`](LINK-CRASHES.md) — an index of every crash seen during the
offload link, keyed by the signature you can grep from a build log, plus a triage procedure
for one that is not yet listed. Link crashes all look alike from outside (`ftn` dies after
"linking", stack dump mentioning `BitcodeCompiler::compile()`) while the underlying defects
are unrelated, so identifying *which* one you have is the first step.

## Running a reproducer: the exit-code convention

Every reproducer that can score itself follows one rule:

> **Exit 0 means reality matched what its README documents.** For an unfixed defect, that
> means the bug still reproduces. Nonzero means something changed and a human should look.

| exit | meaning | what to do |
| --- | --- | --- |
| 0 | as documented — the defect is still present | nothing; this is the steady state |
| 1 | deviation — often a fix, but *verify* before recording one | diff against the committed reference output, then update the README |
| 2 | inconclusive — nothing built, ran, or was found | fix the environment; this is **not** a statement about the compiler |

This is deliberately not "exit 1 = bug found". These files exist to answer *"has the vendor
fixed it yet?"* across compiler upgrades, so the useful signal is **change**, not badness. A
green run after a CCE upgrade means nothing moved; a red run is the thing worth reading.

Exit 2 is separated from 1 on purpose. Most of these need a very specific environment — the
right CCE, `craype-accel-amd-gfx90a` loaded (sometimes even when nothing launches a kernel),
and for the runtime ones a real GPU. A missing module makes a defect *disappear*, which is
indistinguishable from a fix if the harness only has pass/fail. `lib/guard.sh` exists for
this: it checks the environment up front and calls `guard_fatal` rather than letting a run
report a clean bill of health it did not earn.

### Controls are mandatory

Every reproducer here pairs the failing case with at least one control that must come out
**correct** in the same run — an assumed-shape dummy next to the explicit-shape one, an
explicit `private(all)` next to `defaultmap`, an OpenACC arm next to the OpenMP arm. If a
control fails, the harness reports inconclusive instead of claiming a bug.

That rule is not theoretical. Reproducers in this tree were twice recorded as proving
something they did not, because every arm was failing for an environmental reason and the
comparison was vacuous. `contiguous-mix-dropped-stores` also ships a *negative* control: run
it with the `v1_*` sources and it must report FIXED. A harness that cannot produce both
verdicts has not been shown to distinguish them.

### One more way the environment lies: `CRAY_CCE_LLD_ARGS`

Several of these defects have an LLD-level workaround, and MFC's Frontier module file
exports all of them at once:

```
CRAY_CCE_LLD_ARGS="-plugin-opt=-mattr=-mai-insts
                   -plugin-opt=-disable-promote-alloca-to-vector
                   -plugin-opt=-enable-load-in-loop-pre=false"
```

So `source <MFC>/mfc.sh load -c f -m g` — the convenient way to get a working CCE
environment, and what several READMEs here suggest — turns off the very defects you are
trying to observe. `promote-alloca-dropped-store` reports a clean PASS under it.

`guard_lld_clean <substring>...` in `lib/guard.sh` makes an affected reproducer refuse to
run rather than report a false fix. Add a call to it whenever a new entry's defect can be
suppressed by one of these gates.
