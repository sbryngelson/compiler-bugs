# Drafts — findings banked for review

Each file is a self-contained draft, ready to be turned into an upstream issue or discarded.
Nothing here has been filed. Status is stated at the top of each.

| # | finding | severity | filed? |
|---|---|---|---|
| 01 | flang ignores the `schedule` clause in device offload | conformance | no |
| 02 | flang: `ordered` not honoured on device, **wrong results** | correctness | no |
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

## Harness lessons that cost time

* Probing a DeviceRTL entry point directly can violate the caller's contract and manufacture a
  failure that is not a compiler bug. `For()` looked broken this way; it is correct under valid
  input. Check the precondition before believing a hit.
* Verify the probe reaches the code under test. The 252 chunked probes passed while never entering
  the chunked path, because the chunk argument was silently zero.
* Overwriting `LD_LIBRARY_PATH` without preserving the previous value made all six mapping probes
  "dump core" at once. Six simultaneous failures is a harness smell, not six bugs.
