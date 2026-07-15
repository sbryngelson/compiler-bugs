# AMD flang: whole-array slice assignment into a private array spills to scratch (gfx90a)

Standalone reproducer for an AMD flang (ROCm) OpenMP-offload codegen bug in a WENO-shaped kernel.

## Status: FIXED in AFAR 23.2.0

A runtime-bounded whole-array slice assignment `dst(0:n) = src(:)` inside a register-heavy
`target teams distribute parallel do` kernel spills ~20 KB/work-item to scratch and craters
occupancy — **but only on the AFAR 23.1.0 drop.** The 23.2.0 drop (04/18/26) lowers it cleanly
(0 B scratch). This is the same `_FortranAAssign` device-lowering class as the still-open
[`firstprivate`-array bug](../flang-firstprivate-array-occupancy) (#2909); the *slice-assignment*
path was fixed in 23.2.0, the *firstprivate*-array path was not.

Recorded because Frontier's CI compiler is pinned to the one interim drop (23.1.0) where this path
is implemented-but-spilling, so it bites there and nowhere else.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Related open bug | [ROCm/llvm-project#2909](https://github.com/ROCm/llvm-project/issues/2909) (firstprivate variant, still open) / [llvm#203890](https://github.com/llvm/llvm-project/issues/203890) |
| Source | MFC WENO hybrid path, [MFlowCode/MFC#1628](https://github.com/MFlowCode/MFC/pull/1628) (removed the slice copy) |

## Symptom

MFC's non-case-optimized `s_weno` kernel holds several small per-thread WENO arrays
(`poly/alpha/omega/beta`, sized `0:4`) indexed by a **runtime** loop bound `ns`
(`weno_num_stencils`). The hybrid-WENO "use central weights" path assigned the central weights
with a whole-array slice copy:

```fortran
if (use_central) then
    omega(0:ns) = d_cbL(:, i)        ! runtime-bounded array-slice assignment  <-- spills
else
    ... compute omega from beta ...
end if
v = omega(0)*poly(0) + omega(1)*poly(1)
```

On AFAR 23.1.0 that one slice assignment makes the whole kernel spill ~20 KB/work-item to scratch
and drop occupancy, running the kernel ~6-10x slower. Reconstructing directly from the weights
(`v = d_cbL(0,i)*poly(0) + d_cbL(1,i)*poly(1)`) or filling `omega` with an explicit indexed loop
(`do q = 0, ns; omega(q) = d_cbL(q,i); end do`) costs nothing — same values, no `_FortranAAssign`.

## Version trajectory (`SLICE` variant, sweep kernel, gfx90a, `LIBOMPTARGET_KERNEL_TRACE=1`)

| drop | date | scratch | occupancy | note |
|------|------|---------|-----------|------|
| flang 22 (ROCm 7.2.0) | — | — | — | **won't link**: `undefined symbol: _FortranAAssign` (no device helper) |
| AFAR **23.1.0** | 03/12/26 | **20 736 B** | 12% | spills — Frontier's pinned compiler |
| AFAR **23.2.0** | 04/18/26 | **0 B** | 15% | **fixed** |
| AFAR **23.2.1** | (23.2.0 base) | **0 B** | 15% | fixed |

Same source; only the `SLICE` variant spills, and only on 23.1.0:

| variant (AFAR 23.1.0) | scratch | what differs |
|-----------------------|---------|--------------|
| `NONE` (direct reconstruct) | 0 B | — |
| **`SLICE`** (`omega(0:ns)=d_cbL(:)`) | **20 736 B** | the whole-array slice copy |
| `ONE_SCHEME` | 0 B | fewer weight branches |
| `CONST_NS` (case-opt-like) | 0 B | `ns` a compile constant → arrays right-size, loops unroll |

`CONST_NS` also shows the register-pressure driver: baking `ns` constant drops the kernel from
~90 VGPR to ~32 VGPR on 23.2.1 (what `--case-optimization` does), because the runtime `ns` forces
the `0:4`-sized arrays to stay memory-resident.

## Mechanism

A runtime-bounded array-slice assignment lowers through the Fortran runtime's descriptor-assignment
helper `_FortranAAssign` *inside the device kernel* — the same helper as the `firstprivate`-array
copy-in in #2909. flang 22 has no device `_FortranAAssign` (link error). AFAR 23.1.0 inlines it as a
large scratch-spilling blob. AFAR 23.2.0 lowers the slice path to a plain value copy (no spill). The
scalar-index and explicit-loop forms never take the `_FortranAAssign` path.

## Reproduce

```bash
./build.sh                                          # builds r_NONE, r_SLICE, r_ONE_SCHEME, r_CONST_NS
N=4000 OMP_TARGET_OFFLOAD=MANDATORY LIBOMPTARGET_KERNEL_TRACE=1 ./r_SLICE 2>&1 | grep sweep
# on 23.1.0: scratch:20736 ... occupancy 12%     on 23.2.0+: scratch:0 ... occupancy 15%
```

`weno_slice.f90` is one file, five-variant via `-D`; each builds+links in seconds.

## Workaround (also the MFC fix)

Keep whole-array slice assignments out of hot device kernels: reconstruct directly from the source
array, or copy element-by-element with an explicit indexed loop. Both are byte-for-byte identical to
the slice assignment and neither routes through `_FortranAAssign`. Independently, `--case-optimization`
(compile-time `ns`) removes the underlying register pressure.
