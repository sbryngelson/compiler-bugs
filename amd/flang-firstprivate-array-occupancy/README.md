# AMD flang: `firstprivate` of a small fixed-size array spills to scratch and craters occupancy

Standalone reproducer for an AMD flang (ROCm) OpenMP offload codegen bug.

## Minimal reproducer (2026-07-22)

`firstprivate_one_element.f90` reduces the trigger to a **one-element** `real(8)` array on a
trivial kernel — no register pressure, no `int(2)`, nothing else in the loop. amdflang, AFAR
23.2.1, gfx90a, `-O3`:

```
ScratchSize [bytes/lane]: 35424
Dynamic Stack: True
VGPRs:     .L__omp_offloading_..._k__l11.num_vgpr          <- unresolved
Occupancy: occupancy(8, 8, 512, 8, 8, max(...), max(...))  <- unresolved
```

8 bytes of data, 35424 bytes/lane of scratch, deterministic 20 runs out of 20. The resource
fields degenerate to symbolic expressions because the kernel retains an out-of-line call, so
occupancy is not statically determinable either.

Clause isolation, same kernel, only the clause changed:

| clause | scratch | dynamic stack |
|---|---|---|
| `firstprivate(c)` | **35424** | True |
| `private(c)` | 0 | False |
| `shared(c)` | 0 | False |
| none | 0 | False |
| `firstprivate(n)` (scalar) | 0 | False |

Size sweep: `c(1)` 35424, `c(8)` 35552, `c(16)` 35680 — a fixed ~35.4 KB penalty plus 8 bytes
per element, so the cost is in the copy-in path, not proportional to the data.

Upstream flang at `02c51adb8ff2` does not link the same source at all:
`ld.lld: error: undefined symbol: _FortranAAssign`. Same root cause from the other side.


## Status (2026-07-24): FIXED UPSTREAM by #209539

[#209539](https://github.com/llvm/llvm-project/pull/209539) (@bhandarkar-pranav) **merged
2026-07-24 18:56 UTC** as [`e949b654424b`](https://github.com/llvm/llvm-project/commit/e949b654424beda81ab4db154a72b904c8b32245)
on `main`. It fixes this one layer below my patch, in `fir::AliasAnalysis::alias`: it returns
`NoAlias` for the copy-region mold/private pair and `MayAlias` for POINTER. With that,
`InlineHLFIRAssign`'s existing `aliasRes.isNo()` path inlines the copy on its own and #211543's
special case is redundant. What landed is 65 lines in
`flang/lib/Optimizer/Analysis/AliasAnalysis.cpp`, two new alias-analysis tests
(`alias-analysis-omp-private-copy-region.mlir`, `alias-analysis-omp-private-pointer.mlir` — the
POINTER guard @tblah asked for is in), and a 50-line CHECK update to
`Integration/OpenMP/parallel-private-reduction-worstcase.f90` where the runtime call is now an
inlined loop.

#209539 is the better-layered fix (it covers every consumer of alias analysis, not one call site),
which is why #211543 was offered up in its favour rather than pushed.

**Two loose ends, both mine to close:**

- [#211543](https://github.com/llvm/llvm-project/pull/211543) is still **open** and is now dead
  code. I said on #209539 I would close it once that landed; the merge and my comment crossed
  (@bhandarkar-pranav: "I think I hit merge just as your comment came"). Close it, pointing at
  `e949b654424b`.
- [#203890](https://github.com/llvm/llvm-project/issues/203890) is still **open**. #209539's
  description names only #200922 (now closed by the merge), so GitHub never auto-closed mine. The
  equivalence was measured and reported on the PR (byte-identical binary, table below); close
  #203890 against `e949b654424b` citing that.

Note: an earlier alias-analysis attempt of mine failed by classifying the clone as
`SourceKind::Allocate` (describes the descriptor, not the data). #209539 succeeds by special-casing
the block-arg pair directly instead, and additionally gets the POINTER case right, which the
`SourceKind` route would not have.

**Root cause, upstream.** The `hlfir.assign` in the `omp.private` *copy* region (not the init
region, as written below) has block arguments on both sides, so `fir::AliasAnalysis` returns
`MayAlias`, `ArraySectionAnalyzer` returns `Unknown`, and `InlineHLFIRAssign` declines to expand it.
The copy therefore falls back to `_FortranAAssign`. The operation defines its two copy-region block
arguments to be the original host variable (arg 0) and the memory allocated for the clone (arg 1),
so those two cannot overlap; skipping the aliasing check for the assignment that writes the clone
lets the existing inlining emit a plain element loop.

**The predicate took three revisions to get right.** @Saieiei rejected the first two.

*v1* checked only that the LHS was copy-region argument 1. A copy region's body is unrestricted, so
an assignment whose RHS is rooted in the *clone* would also have skipped the aliasing check and been
lowered as a non-overlapping element loop.

*v2* added a def-chain walk requiring the RHS to be rooted in argument 0, bailing out on the clone,
on values with no defining op, and on ops carrying regions. Still too permissive on two counts:
every *regionless* op counted as provenance-preserving, and `fir.call` is regionless while free to
return unrelated memory through global state; and the LHS test accepted argument 1 of **any** block,
not specifically the entry block's clone argument.

*v3* abandons provenance reasoning entirely and matches only the canonical copy-in that lowering
emits, confirmed by dumping the real IR:

```mlir
^bb0(%orig, %clone):
  %0 = fir.load %orig          // boxed privatizer only
  hlfir.assign %0 to %clone
```

It requires the assignment to be in the **entry block**, the LHS to be exactly
`entry.getArgument(1)`, and the RHS to be either `entry.getArgument(0)` or a single `fir.load` of
it. There is no traversal, so there is no class of operations left to reason about. Anything else
keeps the aliasing check; being conservative costs only the inlining.

Four negative tests pin the holes: `@_QFtestEd` (writes the original), `@_QFtestEe` (RHS loaded from
the clone), `@_QFtestEf` (RHS from `fir.call`), `@_QFtestEg` (LHS is argument 1 of a non-entry
block). The last two were verified to **fail against v2**, so both reviewer objections were
reachable rather than theoretical.

Note on `@_QFtestEg`: v2 accepted it, but it happens to be a self-assignment of the original, so
inlining it would have been benign in that instance. It demonstrates a predicate defect, not a
miscompile. `@_QFtestEf` is the one with real miscompile potential.

*v4* (after @tblah's review) adds a POINTER guard and switches to the named accessors
`getCopyMoldArg()` / `getCopyPrivateArg()`. The POINTER point is a genuine semantic subtlety: a
POINTER firstprivate copies the pointer *association*, not the data, so the mold and clone
descriptors designate the same storage and the copy aliases. #209539 handles this by returning
`MayAlias`; v3 did not handle it at all. It is not reachable today because a POINTER copy region
lowers to `fir.load` + `fir.store`, not `hlfir.assign` (confirmed by dumping the IR), so this pass
never sees it, but the guard keeps it correct if that changes. A fifth negative test `@_QFtestEp`
(POINTER-typed copy region) pins it: it fails without the guard and passes with it.

The lesson generalises twice over. "These two block arguments cannot alias" was true but was not the
whole predicate, because it constrained only one operand of the assignment. And when a safety check
is being skipped on the basis of a pattern, matching the exact pattern the producer emits beats
reasoning about the general case — the general case is where the reviewer keeps finding holes.

Fixing this in `fir::AliasAnalysis` *via `SourceKind`* does not work and was tried first: classifying
the clone block argument as `SourceKind::Allocate` describes the *descriptor*, not the data behind
it, so the query still comes back `MayAlias`. A different alias-analysis route does work, and is what
#209539 does: special-case the copy-region mold/private block-arg pair directly (returning `NoAlias`,
or `MayAlias` for POINTER) rather than going through `SourceKind`.

Measured on gfx90a at `02c51adb8ff2`, one-element `real(8)` array:

| | before | after |
|---|---|---|
| offload link | `undefined symbol: _FortranAAssign` | links |
| `_FortranAAssign` in device IR | 3 (1 decl, 2 calls) | 0 |
| ScratchSize, device compile | 208 B/lane | 112 B/lane |
| result on MI210 | does not link | `2.0`, correct |

check-flang is clean at every revision: 4602 passed at v1; 4608 passed at v2; 4607 passed / 11
expected failures / 0 failures at v3 and v4 on `d1d3891077f6`. (The discovered count is one lower
than v2 only because an unrelated test file from `llvm#211395` was removed from the working tree.)
Every counterfactual, including the v4 POINTER guard, was verified by rebuilding without the check,
not inferred.

### #209539 and #211543 are equivalent in effect (2026-07-24)

Built and measured three ways at `d1d3891077f6`, gfx90a, `-O3`, using
`firstprivate_one_element.f90`:

| build | offload link | binary |
|---|---|---|
| baseline, no patch | `ld.lld: error: undefined symbol: _FortranAAssign` | fails |
| #209539 alone | links | 1241304 bytes |
| #211543 (v4) alone | links | 1241304 bytes |

Byte-identical output, so for this case the two fixes are interchangeable and #211543 adds nothing
over #209539. It also establishes that #209539 closes **#203890** as well as the #200922 it names;
that was reported on #209539, since its description covers only the compile-time regression.

**Measurement error worth recording.** The recent v3/v4 checks used a scratch file
(`fp.f90`, a `firstprivate` + `reduction` kernel) and reported `_FortranAAssign` count 0 as
confirmation. The baseline emits 0 for that file too, so the check never discriminated and those
particular verifications were vacuous. The patches are still correct, as the table above shows, but
it was proved by a test that could not fail rather than one that could. Use
`firstprivate_one_element.f90`, where the counterfactual is an outright link failure.

`211543-inline-firstprivate-copy.patch` tracks the current PR head (v4, `2a8677d01575`).

The kernel still reports `Dynamic Stack: True` after the fix. That is
[#211132](https://github.com/llvm/llvm-project/issues/211132), the un-inlined device-outlined
target region, not this.

**Downstream is unverified.** The ~35 KB/lane spill and occupancy collapse below are the AFAR
manifestation of the same runtime call. The AFAR drop cannot be rebuilt locally, so only the
upstream half of this is measured.

Still reproduces on the 2026-06-12 public ROCm nightly (`therock-dist-linux-gfx90a-7.14.0a20260612`).
AMD's first attempted fix, [llvm/llvm-project#204466](https://github.com/llvm/llvm-project/pull/204466),
only gates the *implicit* firstprivate-promotion path (`resolve-directives.cpp`); this reproducer
uses *explicit* `firstprivate(re)`, which already goes through delayed privatization, and the
array copy-in via `_FortranAAssign` in the privatizer init region — the actual spill — is
untouched by that PR. Verified: building amd-staging + #204466 and re-measuring shows the spill
is byte-for-byte unchanged (1.04 MB code object, 20720 B scratch, 12% occupancy, on vs. off).
AMD (Jonathan03ant) is now routing this to their internal team.

## Tracking

| Where | Link / ID |
|-------|-----------|
| ROCm/llvm-project | [#2909](https://github.com/ROCm/llvm-project/issues/2909) — open; awaiting an AFAR drop with `e949b654424b` |
| llvm/llvm-project | [#203890](https://github.com/llvm/llvm-project/issues/203890) — open, **fixed by `e949b654424b`; close it** |
| llvm/llvm-project | [#200922](https://github.com/llvm/llvm-project/issues/200922) — closed by the merge (the compile-time half, @bhandarkar-pranav's report) |
| **Fix (landed)** | [#209539](https://github.com/llvm/llvm-project/pull/209539) → [`e949b654424b`](https://github.com/llvm/llvm-project/commit/e949b654424beda81ab4db154a72b904c8b32245), merged 2026-07-24 — `fir::AliasAnalysis` returns `NoAlias` for the copy-region pair |
| Fix PR (mine, superseded) | [#211543](https://github.com/llvm/llvm-project/pull/211543) — inline the copy in `InlineHLFIRAssign`; redundant, **still open, close it** |
| Non-fix attempt | [llvm/llvm-project#204466](https://github.com/llvm/llvm-project/pull/204466) — doesn't cover this case |
| Source | MFC [MFlowCode/MFC#1588](https://github.com/MFlowCode/MFC/pull/1588) |
| OLCF Helpdesk | OLCFHELP-26858 |

## Symptom

Putting a small, fixed-size integer array in a `firstprivate` clause on a register-heavy
`target teams distribute parallel do` kernel makes the kernel spill ~35 KB/work-item to
scratch, pins AGPRs at the hardware maximum, and drops occupancy to one wave per SIMD. The
kernel runs ~30-50x slower. Passing the *same two integers* as scalars, or as a plain
`private` array initialized from those scalars, costs nothing.

The arithmetic body is identical in every variant below — the only difference is how the two
small integers reach the kernel. Frontier MI250X (gfx90a), one GCD, `LIBOMPTARGET_KERNEL_TRACE=1`:

```
afar 23.2.0 (04/18/26)        ns/elem   scratch   AGPR  SGPR-spill  VGPR-spill  occ
A  baseline (no clause)        0.135       0 B       0        0           0      50%
B  firstprivate(re)  [int(2)]  6.330   35424 B     256     1155         451      12%   <-- 47x
C  firstprivate(re1, re2)      0.196       0 B       0        0           0      50%
D  firstprivate(re), const idx 6.347   35424 B     256     1155         451      12%   <-- 47x
E  private(repriv)+fp scalars  0.203       0 B       0        0           0      50%
```

`re` is `integer, dimension(2)` holding `[1, 0]`. Eight bytes. The full trace, and the same run
on the older afar 23.1.0 drop, is in `results/kernel_trace.txt`.

## What's broken

It is `firstprivate` of an *array*, specifically — not the dynamic indexing, not the
array-ness, not register pressure in general. A 2x2 over {clause} x {how the array is indexed}
separates the two candidate causes:

|                        | read `re(i)` (dynamic) | read `merge(re(1),re(2),..)` (constant) |
|------------------------|------------------------|------------------------------------------|
| `firstprivate(re)`     | **B: spills, 12% occ** | **D: spills, 12% occ**                   |
| `private`, seeded from `firstprivate` scalars | **E: 0 scratch, 50% occ** | (C: scalars, same — fast) |

- **D** reads the firstprivate array with *constant* indices and is just as broken as B, so the
  dynamic index is not the trigger.
- **E** reads a `private` array with a *dynamic* index and is perfectly fine, so a
  dynamically-indexed private array is not the trigger either.

E is the tell: it expresses the *exact* semantics of `firstprivate(re)` by hand — a per-work-item
private array seeded from the original values (carried in as two `firstprivate` scalars) — and the
compiler lowers that to zero-scratch, full-occupancy code. So the compiler can generate good code
for the semantics; it just doesn't when the clause is written `firstprivate(<array>)`.

The likely mechanism shows up on the older public release. On ROCm 7.2.0 (LLVM 22.0.0git) the
firstprivate-array variants don't even link — the device object references `_FortranAAssign`, the
Fortran runtime's descriptor-assignment helper, which doesn't exist on the device
(`results/rocm-7.2.0-link-failure.txt`):

```
ld.lld: error: undefined symbol: _FortranAAssign
>>> referenced by ...__omp_offloading_..._run_sweep...
```

So the `firstprivate(array)` copy-in is being lowered through the general array-assignment
runtime path instead of a trivial value copy. On 7.2.0 that leaves an undefined device symbol;
on the 23.x drops the helper gets inlined into the kernel as a large scratch-spilling blob. Same
root cause, two surface failures. Scalars and plain private arrays don't take that path.

## Minimal form

One file, `firstprivate_array.f90`, built five ways (exactly one `-DVARIANT_*`). The kernel is a
register-heavy arithmetic blob (~90 private real scalars + a few small private arrays through a
long dependent `sqrt`/`sign`/divide chain so nothing folds away), modelled on a hydrodynamics
Riemann solver. The two integers are consumed as the trip count of an inner sequential loop, the
same way the original code uses them.

The heavy body is load-bearing: the bug needs a kernel already under real register pressure. A
toy kernel that does nothing but copy the array does not show it.

## Build and run

Frontier login node to build, compute node (MI250X, gfx90a) to run:

```bash
./build.sh          # builds fp_A .. fp_E, prints the embedded code-object sizes
sbatch run.sbatch   # runs all five with LIBOMPTARGET_KERNEL_TRACE=1
```

Flags, matching the build that hit this in production:

```
compile: -fopenmp --offload-arch=gfx90a -O3 \
         -fopenmp-assume-threads-oversubscription -fopenmp-assume-teams-oversubscription
link:    -fopenmp --offload-arch=gfx90a
run:     OMP_TARGET_OFFLOAD=MANDATORY  LIBOMPTARGET_KERNEL_TRACE=1
```

`build.sh` also prints the `.llvm.offloading` section size as a quick static fingerprint: the
firstprivate-array variants (B, D) carry a ~37x larger embedded code object than the others
(871,504 vs 23,544 bytes on afar 23.1.0). Read it with the `llvm-objcopy` from the *same* drop —
a mismatched objcopy reports 0.

## Versions

| compiler | firstprivate(array) | scalars / private array |
|----------|---------------------|-------------------------|
| ROCm 7.2.0, LLVM 22.0.0git (public release) | fails to device-link (`_FortranAAssign`) | fine |
| afar 23.1.0, LLVM 23.0.0git (03/12/26)      | links; 20.8 KB scratch, 128 AGPR, 12% occ | fine |
| afar 23.2.0, LLVM 23.0.0git (04/18/26, latest) | links; 35.4 KB scratch, 256 AGPR, 12% occ | fine |

Not a stale-drop artifact — the latest afar drop still has it, with a larger spill than 23.1.0.
Cray `ftn` and `nvfortran` offload builds of the same code are unaffected.

## Workaround

Carry the value in as scalars and `firstprivate` those (variant C), or as a plain `private`
array seeded from firstprivate scalars (variant E). Both are register-resident and full-occupancy.

## Source

Found in MFC (https://github.com/MFlowCode/MFC), a multiphase compressible flow solver. The array
is `Re_size` (`integer, dimension(2)`, the per-phase count of Reynolds-number terms), read as the
trip count of the viscous-stress loop in the HLLC Riemann solver. On the Frontier AMD flang
offload build, `firstprivate(Re_size)` was the only correct way to get the value into the kernel
after a module split (the declare-target read went stale — a separate bug,
`../declare-target-static-tu/`), but it carried a deterministic 3-5x slowdown on the viscous and
IBM GPU benchmarks until we switched to the scalar form. Cray and nvfortran builds were unaffected.

## Cross-toolchain scope (2026-07-22)

The "35 KB of scratch" and the "undefined symbol" are the same defect; which one you get depends
only on whether a device build of flang-rt is installed.

| toolchain | target | result |
|---|---|---|
| AFAR 23.2.1 | gfx90a | links; 35424 B/lane, `Dynamic Stack: True` |
| AFAR 23.2.1 | gfx942 / gfx950 | links; 35360 B/lane (compiles-but-unsupported config) |
| ROCm 7.2.0 amdflang | gfx90a / gfx950 | `ld.lld: undefined symbol: _FortranAAssign` |
| upstream flang @ `02c51adb8ff2` | gfx90a / gfx950 | `ld.lld: undefined symbol: _FortranAAssign` |

Checked against the installs: AFAR ships a stock
`lib/llvm/lib/clang/23/lib/amdgcn-amd-amdhsa/libflang_rt.runtime.a` defining `_FortranAAssign`;
ROCm 7.2.0 defines it only in the x86_64 host runtime; the upstream install has no
`amdgcn-amd-amdhsa` runtime directory. Not arch-specific — gfx90a and gfx950 match per toolchain.

So on stock ROCm 7.2.0 this does not build at all, on either MI250X- or MI355X-class hardware.
That also argues against simply shipping a device build of the host routine: it would link
everywhere and keep the 35 KB. The lowering needs to emit a value copy.

## Root cause (2026-07-22)

**Why the copy goes through `_FortranAAssign`.** The privatizer for a `firstprivate` array is
generated with a *boxed* type even when the array is fixed-shape, contiguous and of trivial element
type. `flang/lib/Lower/Support/Utils.cpp`:

```cpp
bool requiresBox = emitCopyRegion || seqTy.hasUnknownShape() ||
                   seqTy.hasDynamicExtents() ||
                   !fir::isa_trivial(seqTy.getEleTy());
```

`emitCopyRegion` is true exactly for `firstprivate`. This is deliberate:
[llvm#208315](https://github.com/llvm/llvm-project/pull/208315) introduced the unboxing for
`private` and explicitly excluded firstprivate. That matches the measured clause isolation exactly —
`private(c)` costs 0, `firstprivate(c)` costs ~35 KB/lane.

**Removing the exclusion is necessary but not sufficient.** Dropping `emitCopyRegion ||` produces a
clean unboxed privatizer:

```mlir
omp.private {type = firstprivate} @..._firstprivate_1xf64 : !fir.array<1xf64> copy {
^bb0(%arg0: !fir.ref<!fir.array<1xf64>>, %arg1: !fir.ref<!fir.array<1xf64>>):
  hlfir.assign %arg0 to %arg1 : !fir.ref<!fir.array<1xf64>>, !fir.ref<!fir.array<1xf64>>
}
```

but the link still fails: `hlfir.assign` on arrays re-emboxes both sides in HLFIR-to-FIR and calls
the runtime anyway. The inlining branch in `ConvertToFIR.cpp` is guarded on `!lhs.isArray()`, so a
static-shape trivial array copy never takes it. Tested — the change alone does not fix the link
error.

A fix needs both halves: unbox the firstprivate privatizer, *and* have the array copy avoid the
runtime, either by teaching `hlfir.assign` to inline static-shape trivial array assignments or by
having the copy region emit an explicit copy. The second is a general HLFIR change well beyond
OpenMP, so it is not something to patch speculatively.

## Related: the device runtime is not a viable target for this

[`amd/flang-rt-device-unresolvable-refs`](../flang-rt-device-unresolvable-refs)
([ROCm#3517](https://github.com/ROCm/llvm-project/issues/3517)) shows that even where AFAR *does*
ship an amdgcn `libflang_rt.runtime.a`, the archive references six symbols it never defines, and the
chain hangs off `assign.cpp.o` — i.e. `_FortranAAssign` itself — reaching a **variadic**
`flang_rt_verbose_abort` that AMDGPU cannot lower at all.

That is the strongest argument against "just ship a device build of the routine": the routine's own
dependency chain is structurally unlowerable on AMDGPU. The fix has to be in the lowering, so that a
fixed-size array copy never reaches the runtime.

