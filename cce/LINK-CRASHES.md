# Link-time crash index

Every crash we have hit **during the offload link**, keyed by the signature you can grep out
of a build log. The point of this file is triage speed: when a CCE build dies in `lld`, you
should be able to tell in under a minute whether it is something already understood or
something new that needs filing.

Link crashes are worth indexing separately from the rest of this directory because they all
look alike from the outside — `ftn` exits nonzero somewhere after "linking", with a stack
dump mentioning `lld::elf::BitcodeCompiler::compile()` — while the underlying defects are
unrelated and live in different passes.

## Known crashes

| # | signature to grep for | pass | CCE | scope | entry |
|---|---|---|---|---|---|
| 1 | `Attempt to compare reserved index` (`SlotIndexes.h:96`) | `AMDGPU Rewrite AGPR-Copy-MFMA` | 21.x | **blocks all linking** | [`lld-agpr-mfma-assert`](lld-agpr-mfma-assert) |
| 2 | `castIsValid(op, S, Ty) && "Invalid cast"` | `InstCombine` (`foldIntegerTypedPHI`) | 21.0.2 | **blocks case-optimized builds** | [`instcombine-phi-addrspace-cast`](instcombine-phi-addrspace-cast) |
| 3 | heap corruption (`free()`/`munmap_chunk`), no assert text | `Infer address spaces` | 20.x | blocks the build | [`lld-infer-address-spaces-cce20`](lld-infer-address-spaces-cce20) |

One grep covers all three:

```bash
grep -iE 'reserved index|castIsValid|Rewrite AGPR-Copy-MFMA|Infer address spaces|free\(\)|munmap_chunk' build.log
```

### 1. AGPR-Copy-MFMA — dead value numbers

```
llc: llvm/include/llvm/CodeGen/SlotIndexes.h:96: llvm::IndexListEntry*
     llvm::SlotIndex::listEntry() const: Assertion `isValid() &&
     "Attempt to compare reserved index."' failed.
2.   Running pass 'AMDGPU Rewrite AGPR-Copy-MFMA' on function '@...'
```

The pass walks a live interval's value numbers and asks each one for its defining
instruction. For an **unused (dead) valno** or a **PHI def**, `VNI->def` is not a real
instruction slot — it is a reserved index — and `getInstructionFromIndex` trips the assert.
Upstream carries a three-line guard against exactly this, absent from CCE's 21.1.8 base:

```cpp
 for (VNInfo *VNI : LI.vnis()) {
+  if (VNI->isPHIDef() || VNI->isUnused())
+    continue;
   MachineInstr *DefMI = LIS.getInstructionFromIndex(VNI->def);
```

Dead valnos are produced by **live-range splitting**, which only happens under high register
pressure. That is why every mitigation in the entry's attribute table works by *reducing*
pressure: they do not fix the bug, they stop the split that creates the valno to trip over.
It is also why the crash is sensitive to unrelated source changes — the frame and allocation
shift, and the split moves.

**Do not call that guard "the fix"** — see the backport section below. Stock 21.1.8 with
assertions on compiles the real module clean, so the valno that trips the assert is produced
by CCE-side allocation; the guard would make it harmless but the trigger is elsewhere.

### 2. InstCombine invalid cast

```
opt: llvm/lib/IR/Instructions.cpp:...: Assertion `castIsValid(op, S, Ty) && "Invalid cast"'
```

Reproduces in one pass on a 25-line module, no application needed. Note that
`-instcombine-max-num-phis=0` clears it on the real kernel but **not** on the minimal
reproducer, so it is not a fix.

### 3. Infer address spaces — CCE 20.x

Distinguished from 1 and 2 by having **no assertion text**: it manifests as glibc heap
corruption, so grep for `free()` / `munmap_chunk` rather than `Assertion`. CCE 20.x only.

## Triaging a crash that is not in the table

1. **Confirm it is a link crash, not a compile or toolchain failure.** Check what actually
   failed before blaming the compiler:

   | log contains | it is |
   | --- | --- |
   | `BitcodeCompiler::compile`, `lld`, `Running pass ... on module 'ld-temp.o'` | a link crash — continue below |
   | `ftn-` diagnostic with a source line | a front-end error, not this |
   | `pypi`, `client error (Connect)`, `Installation failed` | the Python bootstrap; compute nodes have no outbound network. **Not a compiler result.** |
   | `Invalid cast` during a *case-optimized* build only | probably #2 |

   That third row is not hypothetical — a measurement in this repo was misreported once
   because an empty `UV_CACHE_DIR` forced a PyPI fetch on a compute node and the harness
   announced it as "more kernels crash".

2. **Get the pass and function name.** They are the two most useful lines in the dump:
   ```bash
   grep -E "Running pass|on function" build.log
   ```

3. **Check whether the workaround gates are masking or causing it.** MFC's Frontier module
   file exports three `-plugin-opt`s. Re-run with `unset CRAY_CCE_LLD_ARGS` and compare:
   a crash that only appears *with* them is a different animal from one they suppress. See
   `guard_lld_clean` in `lib/guard.sh`.

4. **Reduce, but verify the reduction.** `llvm-reduce` on the offload module works, with one
   caveat learned the hard way: `-amdgpu-use-amdgpu-trackers=true` clears the reduced AGPR
   module but **not** the unreduced one. A reduction can drop the very thing that makes the
   real function crash, so validate any candidate workaround against the original too.

5. **Only one crash is visible at a time.** `lld` aborts at the first bad function, so a
   clean-looking log after a fix does not mean there was only ever one problem. Expect to
   iterate: fix, relink, see what surfaces next.

6. **Extracting the offload module** is described in [`PIPELINE.md`](PIPELINE.md); the
   `.cray.llvm.offloading` section trick is in each entry's `extract-device-ir.sh`.

## Backport status of the known fixes

Verified against CCE 21.0.2's own base, `llvmorg-21.1.8`
(`git merge-base --is-ancestor <fix> llvmorg-21.1.8`):

| fix | upstream date | in 21.1.8? |
| --- | --- | --- |
| `30007a541493` (#153915) AGPR dead valnos | 2025-08-16 | **no** |
| `b965f265388a` (#157682) GEP offsets signed | 2025-09-10 | **no** |
| `6d033abb71d6` (#181064) InstCombine bitcast guard | 2026-02-15 | **no** |

The first two predate CCE 21.0.2's merge cutoff, so they are **missed backports** rather
than fixes that did not exist yet. The third postdates it.

**But absence of the fix is not the same as presence of the bug.** Tested against stock
`llvmorg-21.1.8` built with assertions on:

| defect | stock 21.1.8 behaviour | reading |
| --- | --- | --- |
| #2 InstCombine invalid cast | **asserts**, same as CCE | genuine upstream defect; backport is the whole ask |
| #1 AGPR dead valno | **clean**, even at max register pressure | the valno is introduced Cray-side; the missing guard is latent upstream |

So for #1 the vendor ask is *two* things — the CCE-side allocation that creates a dead/PHI
valno, plus the upstream guard that would make it harmless — not "you missed a backport".
See that entry for the wording. Claiming upstream reproduces #1 would be false.

Run that check from inside the clone — `llvm-src/llvm-project`, not its parent. Run from the
wrong directory and `--is-ancestor` returns nonzero because the commit cannot be resolved at
all, which reads exactly like "absent" and is not evidence of anything.
