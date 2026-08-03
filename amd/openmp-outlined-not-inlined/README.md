# flang/OpenMPIRBuilder: device-outlined target regions left un-inlined → ~2.3x registers, 60% less occupancy

Target: gfx90a (MI250X), also reproduced on gfx942/gfx950. Compiler: upstream flang/clang 24.0.0git
(`llvm/llvm-project @ 119b31fd3`, built with `clang;lld;mlir;flang` + `openmp/offload/flang-rt`
runtimes and an `amdgcn-amd-amdhsa` runtime target).

**Status (2026-08-03): FIXED UPSTREAM.**
[llvm/llvm-project#211287](https://github.com/llvm/llvm-project/pull/211287) was **merged by
@shiltian 2026-08-03 14:21 UTC as
[`4905109b00e6`](https://github.com/llvm/llvm-project/commit/4905109b00e6916a310cf7c521bd8df19c0d4a11)**,
and [#211132](https://github.com/llvm/llvm-project/issues/211132) closed as completed. That is the
fix for the defect described here: the 212 -> 94 VGPRs, 48 B -> 0 scratch, 2 -> 5 occupancy and
1.28-1.47x end-to-end numbers below are what it delivers.

[#211255](https://github.com/llvm/llvm-project/pull/211255) is still open, approved by @arsenm and
awaiting a committer. It is an independent correctness fix rather than a fix for #211132, so this
entry is complete without it.

Original status, kept for the history: the `alwaysinline` fix
[llvm/llvm-project#211136](https://github.com/llvm/llvm-project/pull/211136)
was **closed without merging**, and superseded by two narrower PRs:
[#211255](https://github.com/llvm/llvm-project/pull/211255) — an independent correctness fix, not a
fix for #211132; don't apply the reduced cold-callsite inline threshold in non-callable functions, i.e.
hardware entry points such as GPU kernels, where an out-of-line call is register allocated against the
whole kernel's worst case and so costs the hot path too. Keyed off the existing
`CallingConv::isCallableCC`, so it covers `SPIR_KERNEL` and `PTX_Kernel` as well; an earlier version
added a TTI hook and was rejected in review.
[#211287](https://github.com/llvm/llvm-project/pull/211287) — *fixes* #211132; `AAKernelInfo` resolves
the loop-body callback of the `__kmpc_*_static_loop_*` entries (a direct function operand) instead of
treating it as opaque. Also removes the trigger for
[#198621](https://github.com/llvm/llvm-project/issues/198621) — **but does not fix it**, and #198621
is still open. The DeviceRTL defect behind it is intact upstream, and it still reproduces on
gfx90a/gfx942/gfx950 with the shipping AFAR compilers, which predate #211287. See
`../no-loop-array-ops/`.

Premerge on #211287 has only ever failed on unrelated tests, and never on the same one twice. One
run failed `clang-tidy/infrastructure/update-checks-list.test`, which fails on unmodified `main` and
so fails on every open PR ([#211393](https://github.com/llvm/llvm-project/issues/211393), fix in
[#210574](https://github.com/llvm/llvm-project/pull/210574)). A later run failed
`lldb-api :: functionalities/thread/concurrent_events/TestConcurrentSignalWatch.py`, a signal/
watchpoint race with no OpenMP in the debuggee. The PR changes `OpenMPOpt.cpp` and one `.ll` test and
touches no lldb code, so neither is attributable to it; the lldb flakiness is documented in
`../NOT-BUGS.md` (a same-commit re-run of #211566 failed a different lldb test each time). A note to
that effect is posted on the PR so reviewers do not stall on the red mark.

**Both rebased 2026-07-30** onto `17088c9b104e`, which also cleared that stale red mark:
#211287 `84d1e6330cd3` -> `d689283d035a`, #211255 `1dbe2bd2e4bb` -> `3ab07ee7a223`. Each rebase was
verified content-free against the PR diff first (#211255 moved one hunk header, `@@ -2152` to
`@@ -2151`, because `InlineCost.cpp` shifted a line upstream; the added and removed lines are
identical).

Both branches had been updated by *merging* `main` in rather than rebasing, so their heads were
merge commits, and #211255 sat on `02c51adb8ff2` — the same never-landed commit behind the phantom
FreeBSD failure on #211137. Linear history also makes them squash-merge cleanly. Reviewers were
requested on both at filing (#211287: @abidh, @skatrak, @jdoerfert, @shiltian; #211255: @arsenm,
who reviewed on 07-22 and whose three points were taken the same day), so the eight days of silence
is not a missing-reviewer problem; both were pinged after the rebase.

**Both approved 2026-07-31; #211287 landed 2026-08-03.** @shiltian approved #211287 about ten hours
after the ping and merged it once asked; @arsenm approved #211255, which is still waiting on a
committer. Neither could be self-merged — see the no-commit-access note in
`../runtimes-fortran-modules-triple/README.md`. Both of the merges here followed the same pattern as
#211137: approved and green is not enough, someone has to be asked. Land requests were posted to
both on 2026-08-03 and #211287 was merged the same day.

**A reviewer suggestion sat unapplied for three days on #211255 (2026-08-03).** @arsenm left a
GitHub *suggestion* inline on 07-31 asking for the cheaper predicate first,
`isCallableCC(Caller->getCallingConv()) && isColdCallSite(Call, CallerBFI)` rather than the other
order, and had to ask again on 08-03: "Not applied, can you apply this and do whatever clang-format
does with it." The miss was mine — his top-level "description is out of date" comment arrived two
minutes after the suggestion, I answered that one, and never opened the inline thread. **Check the
inline review threads, not just the conversation tab; `gh api repos/:owner/:repo/pulls/N/comments`
lists them.**

The change itself is sound and applied: `isCallableCC` is `constexpr` while `isColdCallSite` runs
BFI block-frequency queries, so the cheap check first short-circuits those away for kernels. Both
predicates are pure, so the result is unchanged and only evaluation order differs. Inline suite
after the swap: 291 passed, 1 expected failure, no failures.

Head is now `143c33a87c5a`, a merge of `main` into the branch made 2026-08-03 to clear a CI failure.
The net diff is unchanged (`InlineCost.cpp +7/-1`, the test `+59/-0`) and CI is green, 11 pass. A
merge commit is harmless here because llvm-project squash-merges, so it never reaches `main`; the
earlier rebases were for a different reason, namely a base that had never landed. That CI failure
was `lldb-api :: tools/lldb-dap/attach/TestDAP_attach.py` timing out at exactly 1200.01s against a
1200s limit, the fourth distinct lldb test to fail across these two PRs, none of which touch lldb.

Two traps while applying it. Running `clang-format -i` on the whole file also reformatted an
unrelated pre-existing line (`onMemAccess(){}`); reverted, since the request was to format the
suggestion, not the file. And copying the edited file from a worktree based on current `main` into
the local tree, which is eight days older, produced build errors at unrelated lines from API drift —
apply the PR patch at the local base and edit on top instead.

## Tracking

| Where | Link / ID |
|-------|-----------|
| llvm/llvm-project | [#211132](https://github.com/llvm/llvm-project/issues/211132) — **closed, completed** |
| Fix PR | [#211287](https://github.com/llvm/llvm-project/pull/211287) — **merged** `4905109b00e6` by @shiltian; resolve the static-loop callback in `AAKernelInfo` |
| Related PR | [#211255](https://github.com/llvm/llvm-project/pull/211255) — cold-callsite threshold in non-callable functions; **approved** @arsenm, green, awaiting a committer |
| Withdrawn | [#211136](https://github.com/llvm/llvm-project/pull/211136) — always-inline device-outlined regions (closed unmerged) |
| Source | [MFC](https://github.com/MFlowCode/MFC) |

## Bug

flang lowers the body of an OpenMP `target teams distribute parallel do` into a separate AMDGPU
device function, and the inliner then declines to fold it back into the kernel:

```
$ flang -fopenmp --offload-arch=gfx90a -O3 outlined_region.f90 -o /dev/null \
    -Xoffload-linker -mllvm=-pass-remarks-missed=inline
'__omp_offloading_..._kern__l23..omp_par.2' not inlined into '__omp_offloading_..._kern__l23'
    because too costly to inline (cost=1280, threshold=495)
```

The outlined device function is then register-allocated and scheduled *without* the enclosing
kernel's occupancy target. clang's device codegen for the identical algorithm ends up fully
inlined. gfx90a, full driver, `-Rpass-analysis=kernel-resource-usage`:

| toolchain | VGPRs | scratch | occupancy |
|---|---|---|---|
| flang 24.0.0git | 212 | 48 B | 2 |
| clang, C equivalent | 80 | 0 | 6 |

The 48 B is the argument struct used to reach the outlined function. In the final post-link device
IR (`0.5.precodegen`) flang leaves one non-intrinsic call and two allocas in the kernel; clang
leaves none of either.

## Root cause

The inline cost of 1280 comes from `OpenMPIRBuilder::applyWorkshareLoopTarget`, taken
unconditionally on device (`if (Config.isTargetDevice()) return applyWorkshareLoopTarget(...)`). It
outlines the loop body and passes `private()` variables by pointer through a struct to
`__kmpc_distribute_for_static_loop_4u`. clang instead emits
`__kmpc_distribute_static_init_4` / `__kmpc_for_static_init_4` with the loop inline. The pointer
indirection keeps the outlined body above the fixed 495 threshold.

The private arrays *do* stay in scratch, but that is not the cause. Same run, `base` vs
`-mllvm -unroll-threshold=3000`: both give 212/48/2, with the `[16 x double]` allocas going 2 → 0.
Promoting the arrays does not move the resource numbers. With the fix the numbers reach 94/0/5
while the arrays remain unpromoted. Also no-ops: `-unroll-threshold` pre-link and LTO,
`-amdgpu-unroll-threshold-private=5000`, `-inline-threshold=5000` and `=100000`.
`-amdgpu-unroll-threshold-private=100` reaches 100 VGPRs but 312 B scratch — trading registers for
scratch, not a fix.

Note `--offload-device-only -S` is *not* representative: clang shows 64 B scratch there vs 0 after a
real link. The linker-wrapper LTO stage is decisive, so all numbers above are full-driver.

## Reproducer

`outlined_region.f90` and its line-for-line C control `outlined_region.c` — identical arithmetic
and loop structure. The kernel is a small register-heavy blob (`[16]` private arrays + a dependent
FP chain) so nothing folds away, mirroring a finite-volume Riemann kernel.

```
./build.sh    # prints per-kernel resource usage for both, plus the inliner miss
```

No compute node needed — the defect is a compile-time inliner decision, visible from
`-Rpass-analysis=kernel-resource-usage` on a login node.

## Root cause

Two earlier attributions here were wrong and are recorded so they are not repeated: it is **not** that
the body is too costly to inline, and it is **not** the by-pointer `private()` struct — that accounts
for 720 of the cost and is irrelevant to the outcome.

flang's device workshare loop passes the loop body to the runtime as a function pointer
(`__kmpc_for_static_loop_4u`, or `__kmpc_distribute_for_static_loop_4u` with `distribute`). OpenMPOpt's
`AAKernelInfo` treats that callback as opaque and records an unknown parallel region, per a TODO at the
site. So `MayUseNestedParallelism` stays 1 in the kernel environment, where clang — which emits the loop
inline with `__kmpc_for_static_init_4` — gets 0. At 1, `config::mayUseNestedParallelism()` does not
fold, the serialized branch of `__kmpc_parallel_60` stays live carrying its own microtask call, and once
that `always_inline` function lands in the kernel there are **two** calls to the outlined region instead
of one. `isSoleCallToLocalFunction` is then false, so `LastCallToStaticBonus` never applies — 15000 × 11
= 165000 on AMDGPU. Same callee, same module:

| | starting inline cost |
|---|---|
| two callsites | −45 |
| one callsite  | **−165045** |

With one callsite it inlines unconditionally and the threshold is irrelevant. The `cost=1280,
threshold=495` above is a symptom of the missing bonus, not the cause.

Controlled pair, same parallel construct, flang, gfx90a:

| construct | runtime loop entry | MayUseNestedParallelism |
|---|---|---|
| `!$omp target parallel`    | none                       | 0 |
| `!$omp target parallel do` | `__kmpc_for_static_loop_4u` | 1 |

## Fix

[llvm/llvm-project#211287](https://github.com/llvm/llvm-project/pull/211287) resolves the callback (a
direct function operand) and consults its `AAKernelInfo`, as the `__kmpc_parallel_60` handling already
does for its parallel-region operand. Result on gfx90a: 212 / 48 B / 2 → **94 / 0 / 5**, matching what
`alwaysinline` achieved. On gfx942 at NEQ=8/16/24: 196/64/2 → 110/0/4, 214/328/2 → 138/0/3,
196/456/2 → 110/392/4.

The withdrawn `alwaysinline` approach ([#211136](https://github.com/llvm/llvm-project/pull/211136)) is
what [ROCm/llvm-project#3485](https://github.com/ROCm/llvm-project/pull/3485) is backing out downstream:
forcing the body inline grows the kernel past the AMDGPU inliner's basic-block budget, so
`__kmpc_target_init` stops being specialized and SPMD kernels inherit a module-wide worst-case
`amdgpu.max_num_vgpr`. Restricting it to the workshare-loop outline and leaving the parallel outline
alone was tried and gives no benefit at all (212/48/2, unchanged), so the two cases cannot be separated
by construct.

## Workaround (no compiler change)

`-fopenmp-assume-no-nested-parallelism`, or `-fopenmp-assume-no-thread-state` — either alone suffices.
Both set a module-level global that short-circuits the check before the kernel environment is read.
Measured against MFC's own flag set (which already carries both oversubscription flags), within a single
job, checksums bit-identical:

| NEQ | gfx90a | gfx942 |
|---|---|---|
| 8  | 1.21x | 1.85x |
| 16 | 1.34x | 2.72x |
| 24 | 1.08x | 1.32x |

Verified not to trigger [#198621](https://github.com/llvm/llvm-project/issues/198621) on AFAR 23.2.0 or
23.2.1, upstream flang, or amdflang 22 (ROCm 7.2.0) — including in the no-`-O` configuration where the
oversubscription pair does fail. Adopted in MFC's `cmake/MFCTargets.cmake`; MFC's golden-file suite is
unchanged by it (568 passed / 21 failed with and without, identical failing set, all pre-existing
`weno_order=7` cases from the AFAR 23.2.x `nuw` miscompile).

## Found in

[MFC](https://github.com/MFlowCode/MFC), a multiphase compressible-flow solver — the WENO + HLLC
finite-volume update on the AMD GPU offload build.
