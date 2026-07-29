# Cray CCE-19: stores to a non-`CONTIGUOUS` dummy are dropped when the same call also passes a `CONTIGUOUS` one

> **Severity:** **Silent wrong answers** (CCE 19.x)  
> **Fix belongs to:** fixed in CCE 20.0.0 — no action needed  
> **Status:** Historical. Worked around in MFC since MFlowCode/MFC#1679; retained because it is the precedent that this defect class does get fixed.

> **Note on scope:** this entry documents a **CCE 19** defect, kept alongside the CCE 21
> entries because it is the reason MFC could not simply stay on 19.0.0 while 21 was
> unusable. It is **fixed in CCE 20.0.0** and absent in 18.x, so it is closed from a
> vendor standpoint — but the workaround is still live in MFC source (PR #1679), and
> anyone reverting that workaround on a CCE 19 toolchain will silently corrupt ghost
> cells again.

Standalone reproducer for a Cray Fortran (CCE 19) host-code miscompile. No OpenMP, no OpenACC,
no GPU kernel — but the `craype-accel-amd-gfx90a` target module must be loaded.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending; **fixed in CCE 20.0.0**, see Versions |
| Source | MFC [#1679](https://github.com/MFlowCode/MFC/pull/1679) |

## Symptom

A procedure takes several assumed-shape `intent(inout)` array dummies. At least one is declared
`contiguous`, at least one is not. The procedure writes to all of them. On return, the writes to
the **non-`contiguous`** dummies are not visible in the caller. The write to the `contiguous`
dummy is fine. No diagnostic is issued.

Every actual argument is a whole contiguous allocatable, every dummy's declared lower bound
equals its actual's (no rebasing), and the program is standard-conforming.

The stores go *nowhere* — they do not land at a shifted address (`results/verbose_default_ipa.txt`):

```
bounds dx/x_cc/x_cb lo:  -3  -3  -4      dummies match the actuals exactly
dx  (146:152) = 7*3.33333333333333355E-3   <- contiguous dummy: written
x_cb(146:152) = 0.48999..., 0.49333..., 0.49666..., 0.49999..., 3*0.
x_cc(146:152) = 0.48833..., 0.49166..., 0.49500..., 0.49833..., 3*0.
nonzero x_cb anywhere above 149: 0        <- not written anywhere
nonzero x_cc anywhere above 149: 0
```

That last count matters. An assumed-shape dummy whose declared lower bound differs from its
actual's rebases, so a naive checker can look at the wrong element and cry miscompile. Counting
nonzeros over the whole array rules that out.

## What controls it

The **caller's** interprocedural-analysis level, not the callee's (`results/ipa_matrix.txt`):

```
callee-ipa / caller-ipa        result
-Oipa0 / default               *** GHOSTS CORRUPTED ***
default / -Oipa0               ghosts OK
default / default              *** GHOSTS CORRUPTED ***
-Oipa0 / -Oipa0                ghosts OK
```

It is the *mixture* of attributes that breaks it. Declaring **every** array dummy `contiguous`
fixes it in all four configurations; declaring **none** of them `contiguous` also fixes it.
Changing the specification-expression bounds (`a(-1 - off%beg:)` -> plain `(:)`) does **not**
fix it, so the bounds form is not the trigger.

`craype-accel-amd-gfx90a` must be loaded. With the accel target unloaded the reproducer passes
even on CCE 19.0.0, despite the code never launching a kernel. Explicit `-h acc` / `-h omp`
flags are *not* needed.

## Minimal form

Four files, mirroring MFC's `m_boundary_common` -> `m_mpi_common` grid-buffer chain: three arrays
(`cell_boundaries`, `cell_centers`, `cell_widths`) forwarded through two frames, with only
`cell_widths` declared `contiguous` in the innermost frame.

| file | role |
|------|------|
| `mod_state.f90` | bounds type, `buff_size`, the three module allocatables |
| `mod_caller.f90` | two forwarding frames; no dummy is `contiguous` |
| `mod_callee.f90` | writes all three; only `cell_widths` is `contiguous` |
| `main.f90` | uniform grid, zeroes the ghost layer, checks it afterwards |
| `v1_callee.f90`, `v1_caller.f90` | the fix: `contiguous` on every array dummy, every frame |
| `main_verbose.f90` | same driver plus the window/nonzero-count diagnostic above |

## Build and run

Login node. Load a working CCE-19 environment — the bare `module load`s miss cpe/pkg-config
paths, so use MFC's loader, which also brings in `craype-accel-amd-gfx90a`:

```bash
source /path/to/MFlowCode-MFC/mfc.sh load -c f -m g
./build_and_run.sh                                  # baseline: 2 of 4 configs corrupted
./build_and_run.sh v1_callee.f90 v1_caller.f90      # fix: all 4 clean
./run_versions.sh                                   # sweep every CCE on the system
```

## Versions

`results/version_matrix.txt`. **Confined to CCE 19.x — fixed in CCE 20.0.0, absent in 18.x:**

```
cce/18.0.1   rocm/6.3.1    baseline=[ghosts OK]                 v1fix=[ghosts OK]
cce/19.0.0   rocm/6.3.1    baseline=[*** GHOSTS CORRUPTED ***]  v1fix=[ghosts OK]
cce/20.0.0   rocm/6.4.2    baseline=[ghosts OK]                 v1fix=[ghosts OK]
cce/20.0.2   rocm/6.4.2    baseline=[ghosts OK]                 v1fix=[ghosts OK]
cce/21.0.0   rocm/7.2.0    baseline=[ghosts OK]                 v1fix=[ghosts OK]
cce/21.0.2   rocm/7.2.0    baseline=[ghosts OK]                 v1fix=[ghosts OK]
```

ROCm is not the variable, controlled both ways:

```
cce/19.0.0 + rocm/6.4.2 (newer)            -> *** GHOSTS CORRUPTED ***
cce/20.0.0 + rocm/6.3.1 (same as 19 used)  -> ghosts OK
```

19.0.0 is the only 19.x on Frontier, so the introduction and fix points are not pinned tighter
than 18.x -> 19.x -> 20.x. Nothing was filed with HPE: it is already fixed two majors on.

Note for the sibling `defaultmap-firstprivate` case, whose README says CCE 20/21 `ftn` was not
functional with the login cpe — that is solvable. Each CCE needs its matching `cpe` (25.03 ->
19.0.0, 25.09 -> 20.0.0, 26.03 -> 21.0.0), a compatible `rocm`, and the rocm lib dir on
`LD_LIBRARY_PATH` or the binary fails to start on `libamdhip64.so.6`. A bare `module swap cce`
reports success while `ftn` keeps dispatching the old version. `run_versions.sh` does this.

## Why it mattered

MFC [#1679](https://github.com/MFlowCode/MFC/pull/1679) changed the grid-buffer halo exchange from
"operate on module arrays directly, take three scalar arguments" to "take the arrays as
assumed-shape dummies", declaring only `cell_widths` `contiguous` so that passing an element to
`MPI_SENDRECV` is a plain address. The ghost values of `x_cb` and `x_cc` were then silently left
unwritten at rank seams. MFC builds WENO reconstruction coefficients from `x_cb` *including* that
ghost range, with `x_cb` differences in the denominators, so every multi-rank case grew a `NaN`
within ~50 steps.

All 11 multi-rank tests failed; all 616 single-rank tests passed — the routine only runs when
`bc_edge >= 0`, i.e. only with a neighbour rank. It hit the Cray **GPU** lanes only, because MFC's
`CMakeLists.txt` applies `-Oipa0` to the whole `simulation` target on Cray CPU but to only four
named files on Cray GPU, and the caller `m_boundary_common.fpp.f90` is not one of them. The CPU
lane therefore compiled the caller with IPA off and passed. AMD flang and NVHPC were unaffected.

Expect this to be fragile under edits. Adding diagnostic `print` statements that read the arrays
in a *different* file — one already compiled `-Oipa0` — made the failing MFC test pass. CCE's IPA
is interprocedural across files, so extra uses in one translation unit change what it does to a
call in another.

## Workaround

Declare every array dummy on the chain `contiguous` (or none of them); do not mix `contiguous`
and non-`contiguous` array dummies in one call under CCE 19. In MFC that was three declaration
lines across `m_boundary_common.fpp` and `m_mpi_common.fpp`; all actual arguments are whole module
allocatables, so the attribute is accurate rather than a lie told to dodge the optimiser.

Verified on Frontier, CCE 19.0.0, both offload backends — all eight multi-rank regression tests
pass under `--gpu mp` and `--gpu acc`, previously all NaN.


## Re-verified on CCE 21.x (2026-07-29)

The reproducer builds and reports `RESULT: ghosts OK` on both **CCE 21.0.0** and **CCE 21.0.2**,
consistent with this being fixed in CCE 20.0.0.

Not re-checked on CCE 19.0.0/20.x: those need the whole programming environment switched
(`cpe/25.03` + `rocm/6.3.1`), not just a `module swap cce`. An attempt that swapped only the
compiler module produced an unusable environment — `ftn --version` returned nothing and every
arm reported a build failure. Recorded so the next person does not read that as a result.

## Verdict and exit codes

`build_and_run.sh` scores itself. It prints a `VERDICT:` line and exits:

| exit | verdict | meaning |
| --- | --- | --- |
| 0 | BUG PRESENT | at least one of the four `-Oipa0` placements corrupted the ghost cells — the documented state |
| 1 | FIXED | every runnable config kept them intact — a deviation from the documented state |
| 2 | INCONCLUSIVE | nothing built or ran — an environment problem, not a compiler result |

Measured on CCE 19.0.0 + `craype-accel-amd-gfx90a`:

```
$ ./build_and_run.sh                            # the bug
-Oipa0 / default     *** GHOSTS CORRUPTED ***
default / -Oipa0     ghosts OK
default / default    *** GHOSTS CORRUPTED ***
-Oipa0 / -Oipa0      ghosts OK
VERDICT: BUG PRESENT (as documented) -- 2/4 configs corrupted the ghost cells.   # exit 0

$ ./build_and_run.sh v1_callee.f90 v1_caller.f90   # the contiguous-everywhere fix
VERDICT: FIXED -- all 4 runnable configs kept the ghost cells intact.            # exit 1
```

The second run is the **negative control**, and it matters: it proves the harness can
actually reach a FIXED verdict rather than being hardwired to report a bug. Run it whenever
you port this reproducer to a new compiler — a harness that only ever prints BUG PRESENT is
indistinguishable from a broken one.

Note which side fixes it. Disabling interprocedural analysis on the **caller** (`default /
-Oipa0`) hides the bug; disabling it on the **callee** alone does not. That is the direction
the bad analysis flows.

Exit codes follow the repo-wide convention: **0 means reality matched this document**
(the defect is still present), nonzero means something changed and needs a human.
See `../README.md`.
