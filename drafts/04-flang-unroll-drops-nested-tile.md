# DRAFT ISSUE — flang silently drops a nested `tile` inside `unroll`

**Status: SUPERSEDED — partly addressed in llvm#214115, do not file as-is.**

Pre-existing upstream, not introduced by llvm#214115. Surfaced while answering a review request on
that PR for an `unroll full` + `tile` lowering test.

llvm#214115 now adds a `TODO` so the nested construct is diagnosed instead of silently dropped,
plus `flang/test/Lower/OpenMP/Todo/unroll-nested-transform.f90`. The underlying composition is still
unimplemented. If @tblah asks for that TODO to be split into its own patch, this draft becomes that
patch; otherwise file it only as a feature request for generatee chaining.

**Title:** `[flang][OpenMP] A tile construct nested in unroll is silently dropped`

---

When a `tile` construct is nested inside an `unroll`, the tile is discarded. Only the unroll op
reaches the IR.

```fortran
subroutine s
  integer res, i
  !$omp unroll full          ! or bare `unroll`, or `unroll partial(2)`
  !$omp tile sizes(4)
  do i = 1, 100
    res = i
  end do
  !$omp end tile
  !$omp end unroll
end subroutine
```

| outer directive | ops emitted |
|---|---|
| `unroll full` | `omp.unroll_full` only |
| `unroll` | `omp.unroll_heuristic` only |
| `unroll partial(2)` | `omp.unroll_partial` only |
| *(tile alone, control)* | `omp.tile (%grid1, %intratile1) <- (%canonloop) sizes(%c4_i32)` |

The control shows `tile` on its own lowers correctly, so the loss is specific to the nesting. It
affects the two unroll forms that existed before llvm#214115, so it is not new.

## Severity

Not a wrong-answer bug: tiling is semantics-preserving, so dropping it changes performance, not
results. But the directive is silently ignored, with no diagnostic.

## Related

Other compositions are rejected outright with `This construct requires a canonical loop nest`,
which at least fails loudly:

* `!$omp parallel do` + `!$omp unroll full`
* `!$omp do` + `!$omp unroll full`
* `!$omp tile sizes(4)` + `!$omp unroll full` (tile outer)

Only `unroll` outer / `tile` inner is accepted, and that is the case that drops the tile.
`!$omp parallel do` + `!$omp tile` does work (`flang/test/Lower/OpenMP/tile-parallel-do.f90`), so
worksharing-plus-transformation composition is supported in general.
