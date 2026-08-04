# Metamorphic OpenMP offload probes

Each probe computes the same result two ways inside one target region and compares them itself.
No external oracle, no predicted value: if the two spellings disagree, the compiler is wrong.

## The bug that made this worth rewriting

The first version of this harness initialised **both** result arrays to `0.0d0`. If the compiler
drops an iteration, neither array is written, both are still zero, and they compare equal. It was
structurally blind to skipped iterations -- which is
[llvm#198621](https://github.com/llvm/llvm-project/issues/198621), the exact bug class it was built
to find. It reported 150/150 PASS on a compiler where that bug is live and proved nothing.

`gen_meta2.py` starts the two arrays at **different** sentinels, so an unwritten element cannot
compare equal, and reports `unwritten` separately from `mismatch` -- a dropped iteration and wrong
arithmetic are different bugs.

**Validate the instrument before trusting it.** On AFAR 23.2.0, where #198621 is live, the control
reproducer fails (`FAIL: 31 of 64`) and the sentinel probes now catch it with numbers matching the
derived formula `N_unwritten = (N - (ceil(N/32) + 31)) * ncols` exactly:

| probe | unwritten | predicted | first bad row |
|---|---|---|---|
| n=64 | 124 | 31 x 4 | 34 |
| n=128 | 372 | 93 x 4 | 36 |

## Results

`gen_meta2.py` -- 252 probes, 7 relations x 3 constructs x 12 sizes, whole-array and slice bodies.
`gen_meta3.py` -- 72 probes covering what a finite-volume solver actually uses: collapse(2)/(3),
reductions, private/firstprivate arrays, nested parallel, simd, allocatable, atomic, complex.

AFAR 23.2.1, `-fopenmp-target-fast`:

| arch | array-op probes | realistic shapes |
|---|---|---|
| gfx90a (MI250X) | 225 pass / 27 fail | 72 / 72 pass |
| gfx942 (MI300X) | 225 pass / 27 fail | 72 / 72 pass |
| gfx950 (MI355X) | 225 pass / 27 fail | 72 / 72 pass |

**All 27 failures on all three architectures fit the #198621 formula**, `mismatch=0`, `ttdpd` only.
No architecture-specific miscompile: MI300X and MI355X behave identically to MI250X.

Upstream flang, gfx90a, 66 of 72 shapes (6 need a device `flang_rt` upstream does not ship, so
`_FortranAAssign` is unresolved): **66 / 66 pass**, with SPMD no-loop mode confirmed active rather
than assumed -- `exec_mode` in the device IR goes 2 to 6 with
`-fopenmp-assume-{teams,threads}-oversubscription`. Upstream reaches no-loop with those two flags
alone; no AMD-only flag is needed.

## Two useful negatives

`where_vs_if` never fails while the three whole-array relations always do, so masked assignment
lowers through a different path than `_FortranAAssign`. That supports the theory that #198621 needs
an opaque runtime call in the loop body, and explains why upstream cannot observe it -- it cannot
link those bodies at all.

Sizes at or below 33 never fail, which the formula predicts.

## Conformance

Non-conforming probes manufacture fake bugs. Every array in a `map` clause has explicit shape and
is never assumed-size; `collapse(N)` loops are perfectly nested; reduction variables are not also
private. Three genuine data races were found and fixed in the round-3 probes before any GPU run: a
shared `zc` scalar and shared inner loop variables `jj` and `j`/`k` inside target regions. All
probes compile and pass on the host first.
