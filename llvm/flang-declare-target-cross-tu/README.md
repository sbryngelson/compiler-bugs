# flang/OpenMP: declare target module variable internalized per-TU

| | |
|---|---|
| Issue | [llvm#214586](https://github.com/llvm/llvm-project/issues/214586) |
| PR | [llvm#214596](https://github.com/llvm/llvm-project/pull/214596) |

A module variable marked `!$omp declare target` is emitted as a fresh `internal` global
initialized to `undef` in every TU that reads it, instead of a reference to the device global the
owning TU defines. A `declare target` routine in another TU therefore reads an uninitialized
private copy, and `target update to(...)` has no effect on what it sees. No diagnostic.

`./run.sh <flang>` builds `mod_a` / `mod_b` / `main` and the same-TU control.

| | cross-TU | same TU |
|---|---|---|
| upstream flang 24.0.0git | **fail** | pass |
| amdflang 22.2.0 / 23.1.0 / 23.2.0 / 23.2.1 | pass | pass |

Reading it directly inside the `target` region also passes; the device-routine indirection is
required. Not syntax (`declare target(x)` and `declare target enter(x)` both fail) and not the
OpenMP level (fails at 31/45/50/52).

## Cause

llvm#208188 internalizes every global without an `omp.declare_target` attribute
(`mlir/lib/Dialect/OpenMP/Transforms/HostOpFiltering.cpp`). A use-associated symbol never gets the
attribute, because both `markDeclareTarget` call sites iterate directives parsed in the current TU.
The `.mod` file records the directive and the symbol keeps its `OmpDeclareTarget` flag, so only the
attachment is missing. The fix marks the declaration in `genOpenMPSymbolProperties`.

Two things that look like fixes and are not:

* Gating the internalization on whether the global still has uses regresses
  `MLIR :: Dialect/OpenMP/host-op-filtering.mlir`, which keeps `addressof` uses alive for map-clause
  lowering while requiring the global to go internal. Use-counting cannot separate the two.
* Gating on `isDeclareTarget()` instead of the initializer body regresses
  `Lower/OpenMP/declare-target-automap.f90`: a main-program declare target global is not yet marked
  when the hook runs, so it gets marked here first with `automap=false` and the directive path then
  skips it.

## Not the same as `../../amd/declare-target-static-tu`

That one was closed working-as-intended: a `declare target` variable has an infinite device
reference count, so `map(to:)` does not re-copy it, while `target update to(...)` does. This
reproducer *uses* `target update to(...)` and still fails, because the global itself is duplicated
per TU rather than the mapping being skipped.
