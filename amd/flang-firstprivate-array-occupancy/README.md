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


## Status: OPEN — not fixed

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
| ROCm/llvm-project | [#2909](https://github.com/ROCm/llvm-project/issues/2909) — open |
| llvm/llvm-project | [#203890](https://github.com/llvm/llvm-project/issues/203890) — open |
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
