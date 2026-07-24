# Investigated: not bugs, or not yet established

Recorded so they are not re-derived.

**Private-array promotion cliff above ~16 equations (2026-07-22).** On a WENO5 + HLLC kernel the
private state arrays stop being promoted between NEQ=16 and NEQ=18: scratch appears (296 → 520 B/lane,
+16 B per equation), VGPRs drop 124 → 70 and occupancy *rises* 4 → 7, with `VGPRs Spill: 0` — so it is
not register spilling, the arrays simply live in scratch. Work-normalized throughput drops ~17% across
the transition and stays flat after.

Root cause is `amdgpu-promote-alloca-to-vector-max-regs`, default **32** 32-bit registers:
`[16 x double]` is exactly 32 registers, `[18 x double]` is 36. But raising it is catastrophic —
at NEQ=18, 1121 → 157 Mcell/s; at NEQ=24, 845 → 88 Mcell/s (7x and 9.7x slower). Promotion succeeds
and the values spill anyway, scratch *doubles* to 640 B and occupancy collapses. The default is
protecting the code; the compiler's choice is correct and the ~17% is inherent to the arrays not
fitting a sensible register budget. `-amdgpu-unroll-threshold-private` (to 20000, both pipeline
stages), `-amdgpu-schedule-relaxed-occupancy` and `-amdgpu-schedule-metric-bias=0` are all inert.

**Kernel-environment vs module-global fold asymmetry (2026-07-22).** Forcing
`MayUseNestedParallelism = 0` in `OMPIRBuilder` fixed a small reproducer but not a larger kernel,
while the module-level assume flag fixed both — which looked like a second gap. It is not:
`OpenMPOpt.cpp:3815` unconditionally overwrites the field from its own `NestedParallelism` analysis,
so setting the frontend's initial value is always discarded. Only what the analysis concludes matters,
which is why [llvm#211287](https://github.com/llvm/llvm-project/pull/211287) works.

**Intermittent `ld.lld` crash on a scalar reduction.** Seen once, not reproducible: 0/10 on upstream
flang and 0/10 on AFAR 23.2.1. Not filed.

## Undetermined

**Array-reduction strategy divergence (2026-07-22).** `reduction(+:s)` on `real(8) :: s(N)` in a
`target teams distribute parallel do` lowers three different ways, gfx90a:

| | scratch B/lane | dynamic stack | runtime entries |
|---|---|---|---|
| AFAR 23.2.1 | `8 + 24N` | no | `nvptx_parallel_reduce`, `nvptx_teams_reduce`, `reduction_get_fixed_buffer` |
| ROCm 7.2.0 | `112 + 16N` | **yes** | — |
| upstream `119b31fd3064` | `272 + 40N` | **yes** | `gpu_xteam_reduce_nowait`, `nvptx_parallel_reduce` |

Upstream carries both a large fixed overhead and the steepest per-element cost, but it also reports
*higher* occupancy than AFAR at N=8 (7 vs 5), so it is not clearly worse. The dynamic stack is not a
consequence of the un-inlined outlined region — `-fopenmp-assume-no-nested-parallelism` leaves it in
place. Deciding whether any of this is a bug needs a timing harness, which has not been built. Not
filed.


**AFAR 23.1.0 compiles MFC 3.1x slower than 23.2.1 (2026-07-23).** MFC's `simulation` target,
OpenMP offload for gfx90a, MPI + FFTW, `-j 32`, same node (`k004-009`, MI250X, EPYC 7763, 128 cores),
same source tree, same flags (`-O3 --offload-arch=gfx90a`):

| AFAR drop | `simulation` build |
|---|---|
| 23.2.1 (`7357b5084b`) | 651 s |
| 23.1.0 (`bb5005b6`, Frontier-pinned) | ~2040 s |

Both exit 0. Node and GPU are not the variable: 23.2.1 measured 653 s on an MI210 (`k005-004`)
against 651 s on the MI250X. This explains reports of ~40 minute MFC builds; those are on the older
drop. Nothing to file — the newer drop already fixes it. The lever worth knowing is which drop the
machine gives you (`amdflang --version`; 23.1.0 reports `23.1.0 03/12/26`).

Not localized to a pass. On 23.2.1 the device link is ~450 s of the 651 s (~70%), roughly 60% of it
`OpenMPOptPass`, but the ~1400 s of extra time in 23.1.0 was never attributed — `-time-passes` was
only ever run against 23.2.1.

Swapping drops needs two things beyond `OLCF_AFAR_ROOT`: wipe the CMake staging dir, since the cached
`CMAKE_Fortran_COMPILER` otherwise points at the old drop's `flang` and fails with `undefined symbol`,
and regenerate `$OLCF_AFAR_ROOT/include/mpi/mpi.mod`, since flang `.mod` files are not portable
across drops.

**Link-time levers that do not work (2026-07-23).** Measured against the 23.2.1 device link:
`--lto-partitions` (only affects the parallel codegen tail, not the serial `opt()` before it),
OpenMPOpt sub-transform toggles, Attributor iteration caps, scoping the Attributor to kernels
(469 s vs 463 s), skipping the first of the two module-level OpenMPOpt runs (4% on a production
build), and `-fno-offload-lto` (inert). Fully disabling `OpenMPOpt` does cut the link but costs
**+24% runtime** (2.9350 → 3.6430 ns/gp/eq/rhs, MI210, noise floor 0.44%), so it is not an option.

The one lever that works on a stock toolchain is
`-Xoffload-linker -mllvm=-inline-threshold=150`: **−14% build, runtime-neutral**. Not currently
applied in MFC.

**flang device ThinLTO (2026-07-23).** flang never emits module summaries for device code —
`FrontendActions.cpp` uses `BitcodeWriterPass` with a `// TODO: ThinLTO module summary support is yet
to be enabled.` A local patch (expose `-foffload-lto` to the flang driver, use the offload LTO mode
for device actions, emit `ThinLTOBitcodeWriterPass` + the `EnableSplitLTOUnit` module flag) does
produce summaries, but end-to-end ThinLTO still fails: DeviceRTL entry points are `hidden`
(`define hidden i32 @__kmpc_target_init`) and ThinLTO cannot import hidden symbols across modules.
Not filed.

## Measurement traps hit while doing this work

**Rebuild every binary under test, not just the one you think matters (2026-07-23).** An incremental
`ninja clang` relinks `libLLVMFrontendOpenMP.a` but leaves `mlir-translate`, `fir-opt`, `bbc` and
`tco` pointing at the previous library. Twice this produced confident-looking failures that were
pure build skew: 5 MLIR failures blamed on a patch that actually causes none, and 4 flang CUDA/HLFIR
failures after a branch switch. Build the specific tools the suite invokes before believing a
result.

**Verify against tip, not the local checkout's base (2026-07-23).** The first revision of the
`llvm#211395` fix was verified at `02c51adb8ff2` and was incomplete on tip; upstream CI caught what
local testing could not, because the relevant path does not reproduce at the older base. Fetch
`upstream/main` and re-run before pushing a fix.

**A reproducer that stops crashing does not mean the bug is gone (2026-07-23).** The
`llvm#211385` reproducer builds clean, unpatched, at `d1d3891077f6`, having failed verification at
`119b31fd3064` and `02c51adb8ff2`. The defect is unchanged — the two reduction helpers still carry
61 and 48 `!dbg` scoped to the kernel's subprogram. Only the downstream inlining that exposed it to
the verifier moved. Where the bug is "wrong IR", test the IR; an end-to-end crash is a symptom whose
absence proves nothing.

**Do not `git add -A` in a tree you have been debugging in (2026-07-23).** That put a 334-line
`cmake.log` full of machine-specific paths into `llvm#211543`, and a reviewer had to ask for its
removal. Add files by name, and read `git show --stat` before pushing.

**Check every operand a safety check would have covered (2026-07-23).** The first `llvm#211543`
predicate skipped an aliasing check after proving only the LHS was the private clone. A reviewer
pointed out the RHS could still be rooted in that clone. "These two values cannot alias" was true
and still insufficient, because it constrained one operand of a two-operand op.

**Check the PR's base is actually in `origin/main` before blaming CI (2026-07-23).** Both
`llvm#211137` and `llvm#211543` were branched from commits that are *not* ancestors of
`origin/main` — `aace063fda01` and `02c51adb8ff2` respectively. Neither ever landed, so the branches
sat on bases that do not exist upstream.

The symptom was not "stale branch". On `llvm#211137` it was a **failing FreeBSD libc++ job**, a
target with no connection to a Fortran CMake probe. I had argued the failure could not be mine, on
solid structural grounds: `config-Fortran.cmake` has exactly one include site, guarded by
`if ("flang-rt" IN_LIST LLVM_ENABLE_RUNTIMES OR "openmp" IN_LIST ...)`, and the FreeBSD job
configures `libcxx;libcxxabi;libunwind`, so the changed file is never even read there. That argument
was right about *whose fault it was* and useless for *fixing it*, and I was drifting toward
"flaky, ignore it" — which two other PRs passing the same job already contradicted.

Rebasing onto current main, with a diff verified byte-identical to the pre-rebase one, turned it
green (`Passed (5 minutes, 18 seconds)`).

Two lessons. First, `git merge-base --is-ancestor HEAD^ origin/main` costs nothing and should run
before every push; a bad base produces failures nowhere near the change. Second, proving a failure
is not your fault is not the same as diagnosing it, and "unrelated/flaky" is the most comfortable
wrong answer available — prefer the cheap corrective action that produces a decisive signal.

**`lldb-api` failures in LLVM premerge are noise, and a same-commit re-run proves it (2026-07-23).**
Two PRs that touch no lldb code both went red on lldb:

| PR | files changed | platform | failing test |
|---|---|---|---|
| `llvm#211287` | `OpenMPOpt.cpp`, one `.ll` test | Linux AArch64 | `functionalities/thread/concurrent_events/TestConcurrentSignalWatch.py` |
| `llvm#211566` | `OMPIRBuilder.cpp`, one `.mlir` test | Linux x64 | `python_api/run_locker/TestRunLocker.py` |
| `llvm#211566`, **re-run of the same job on the same commit** | unchanged | Linux x64 | `functionalities/gdb_remote_client/TestGdbClientModuleLoad.py` |

The last row is the one that settles it. Run `30015668667`, job `89234886343` re-run as
`89260689854` at 16:31 on identical source, and a *different* lldb test failed. Nothing
commit-dependent can behave that way, so no property of either patch is implicated.

The three tests are a signal/watchpoint race, a run-locker, and a gdb-remote module load: all
process-control or threading, the parts of lldb most exposed to host timing.

Practical rule: a red `Build and Test <platform>` whose only failure is under `lldb-api`, on a PR
touching neither lldb nor codegen for the host triple, is not evidence against the patch. Confirm by
pulling the failing test name out of the premerge artifacts rather than trusting the job status,
since the job name says nothing about which suite failed. `.ci` uploads
`test-results.*.xml`; extracting `<failure>` entries from them names the test in seconds and
does not require waiting for the run to finish, which is when `gh run view --log` starts working.

**A verification that cannot fail is not a verification (2026-07-24).** While iterating on
`llvm#211543` I repeatedly confirmed the fix with a scratch reproducer, checking that the device IR
contained no `_FortranAAssign`, and got 0 every time. The baseline emits 0 for that file as well:
the check never discriminated, so several rounds of "verified end to end" were vacuous. The patch
was correct, but the evidence offered for it was not evidence.

The real reproducer fails outright without the fix (`ld.lld: error: undefined symbol:
_FortranAAssign`), which is what a counterfactual should look like. Before trusting a check, run it
against the unpatched build once and confirm it actually fails; a green result from a test that
cannot go red says nothing.
