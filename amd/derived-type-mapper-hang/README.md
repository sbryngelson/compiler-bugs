# amdflang: per-component default mapper for a flat derived type → offload runtime hang

Target: gfx90a (MI250X, MI210). Compiler: amdflang 23.0.0git (therock-afar 23.2.0, ROCm 7.13).

**Status: OPEN.** Reported: [ROCm/llvm-project#3385](https://github.com/ROCm/llvm-project/issues/3385).

## Bug

flang 23 emits a per-component `.omp_mapper.<type>_omp_default_mapper` for a **flat** derived type
(fixed-size scalar/array components only — no `allocatable`/`pointer` members, i.e. trivially
bit-copyable). A `target` kernel that maps an array of that type invokes the mapper per element at
runtime (`N × #components` component pushes: `targetDataBegin → targetDataMapper → targetDataBegin`,
cycling through present-table lookups / `SourceInfo` parsing / `free`). Over a large array × many
kernel launches this is a multi-minute host busy-loop (99% host CPU, GPU idle) — effectively a hang.

Regression: amdflang 22 (rocm-7.2.0) does **not** emit the mapper and runs fine.

## Reproducer

`repro.f90` — flat 11-component derived type, 20000-element arrays, 500 kernel launches.

```
make        # builds hang + fix (needs -cpp for the -DFIX toggle)
make run
```

`hang` busy-loops (times out); `fix` (adds `defaultmap(present:allocatable)`) returns instantly.

## Signature

```
nm hang | grep -c omp_mapper   # 1  (per-component mapper emitted)
nm fix  | grep -c omp_mapper   # 0  (defaultmap → no map entry → no mapper)
```

`rocgdb -p <pid> -batch -ex 'bt'` on the spinning process (it cycles):

```
#0 free
#1 targetDataBegin
#2 targetDataMapper
#3 targetDataBegin
#4 (anonymous namespace)::processDataBefore
#5 target → __tgt_target_kernel
```

## Scope

- **Target-arch-independent** (host codegen): `--offload-arch=gfx90a|gfx942|gfx950` all emit
  `mapper=1`. Only gfx90a runtime-tested (gfx90a-only AFAR drop).
- **Not node-specific**: reproduced on MI250X (`k004-001`) and MI210 (`k005-003`).

## Workaround

`defaultmap(present:allocatable)` on the kernel — the arrays are treated present with **no map
entry**, so flang emits/invokes no mapper. flang accepts only **one** `defaultmap` clause per
directive, so the multi-clause CCE form
(`defaultmap(tofrom:aggregate) defaultmap(present:allocatable) defaultmap(present:pointer)`) is
rejected.

## Found in

[MFC](https://github.com/mflowcode/mfc), block-structured AMR + immersed-boundary path — an
`allocatable` array of a flat ghost-point type swapped/restored on device each RK stage.
