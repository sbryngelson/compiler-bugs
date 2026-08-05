# Drafts — findings banked for review

Each file is a self-contained draft, ready to be turned into an upstream issue or discarded.
Nothing here has been filed. Status is stated at the top of each.

| # | finding | severity | filed? |
|---|---|---|---|
| 01 | flang ignores the `schedule` clause in device offload | conformance | **filed llvm#214303** — see `../amd/flang-device-schedule/` |
| 02 | flang: `ordered` not honoured on device, **wrong results** | correctness | **filed llvm#214257, fixed by llvm#214263** — see `../amd/flang-device-ordered/` |
| 03 | AFAR 23.2.1 cannot compile user-defined reductions (version lag, not upstream) | note | n/a |
| 04 | flang silently drops a `tile` nested in `unroll` | conformance | **superseded** -- TODO diagnostic folded into llvm#214115 |

## Areas probed with no defect found

Recorded so the same ground is not re-covered.

| area | probes | result |
|---|---|---|
| reductions: `+ * max min iand ior ieor .and. .or.` x 4 sizes x 2 constructs | 80 | all pass, upstream and AFAR |
| reductions: array, complex, collapse(2), multiple mixed, UDR | 10 | all pass upstream; UDR fails to build on AFAR (draft 03) |
| data mapping: 1D section, 2D column, derived type whole and per-component, allocatable 2D, pointer | 6 | all pass, upstream and AFAR |
| chunked worksharing via `schedule(static,C)` / `dist_schedule` | 252 | all pass -- but see draft 01: the chunk never reaches the runtime, so `NormalizedLoopNestChunked` was never exercised |
| metamorphic realistic shapes (collapse, private/firstprivate arrays, nested parallel, simd, allocatable, atomic, complex) | 72 | all pass on gfx90a/942/950 and upstream |
| sentinel array-op probes | 252 x 3 arches | 27 failures each, all explained by llvm#198621 |

## Existing-issue search (done 2026-08-05)

Drafts 01 and 02 appear genuinely unreported. Searched `llvm/llvm-project` for: `flang schedule
clause target device`, `applyWorkshareLoopTarget`, `flang ordered target offload`, `flang OpenMP
ordered device wrong`, `OpenMP schedule chunk device ignored`, `flang dist_schedule`, `omp ordered
GPU incorrect`, `flang target teams distribute schedule`, `unroll tile nested flang`. Only hits were
llvm#211429 and llvm#211132, both ours and neither about schedule or ordered.

**Every earlier "no existing issue found" in this session was invalid.** `gh search issues` takes
`--repo` as a flag; passing `repo:llvm/llvm-project` inline makes the whole string a repo name and
the API returns an error, which reads as an empty result. Use
`gh search issues --repo llvm/llvm-project "terms"`.

## Open PRs and issues as of 2026-08-05

| PR | subject | state |
|---|---|---|
| [llvm#211255](https://github.com/llvm/llvm-project/pull/211255) | inliner cold-callsite threshold in non-callable functions | approved by @arsenm, green, awaiting a committer |
| [llvm#213980](https://github.com/llvm/llvm-project/pull/213980) | gate `allocate` at OpenMP 5.0 | red by design (83 clang tests); question with @ddpagan / @alexey-bataev on whether clang's pre-5.0 acceptance is deliberate |
| [llvm#214054](https://github.com/llvm/llvm-project/pull/214054) | quote MIR block names | green, awaiting review |
| [llvm#214073](https://github.com/llvm/llvm-project/pull/214073) | DeviceRTL no-loop NumThreads | green, awaiting review |
| [llvm#214115](https://github.com/llvm/llvm-project/pull/214115) | `unroll full` | reviewed by @tblah, three threads answered inline |
| [llvm#214263](https://github.com/llvm/llvm-project/pull/214263) | dispatch loop for device `ordered` | just opened |

Merged this round: [llvm#214012](https://github.com/llvm/llvm-project/pull/214012), which made
lowering diagnose a failed construct decomposition instead of falling through it.

## Harness lessons that cost time

* Probing a DeviceRTL entry point directly can violate the caller's contract and manufacture a
  failure that is not a compiler bug. `For()` looked broken this way; it is correct under valid
  input. Check the precondition before believing a hit.
* Verify the probe reaches the code under test. The 252 chunked probes passed while never entering
  the chunked path, because the chunk argument was silently zero.
* Overwriting `LD_LIBRARY_PATH` without preserving the previous value made all six mapping probes
  "dump core" at once. Six simultaneous failures is a harness smell, not six bugs.
* A reproducer that fails by timing can pass by luck. The `ordered` issue was first filed with a
  port of an upstream test that compares `omp_get_wtime()` values: 16 pass / 4 fail over 20 runs.
  Prefer a reproducer that cannot pass by luck over one that looks more authoritative.
* `gh search issues` takes `--repo` as a flag. Passing `repo:llvm/llvm-project` inline makes the
  whole string a repo name; the API errors and it reads as an empty result. Every "no existing
  issue found" before this was discovered was invalid.
* Rebuilding one target and testing with another produced three separate false results in one
  session: a stale `clang-24`, a stale `bbc`, and a stale `mlir-opt`. `stat` the binary the test
  actually runs.
* Interleave configurations before believing a small performance delta. A sequential measurement
  showed `unroll full` winning upstream; interleaved, the effect vanished.
