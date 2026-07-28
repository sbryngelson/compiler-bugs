# CCE 21: a `defaultmap` clause makes a resident array read as zero on device

**Wrong answers, no diagnostic.** An array made device-resident with
`declare target` + `target enter data`, populated on the host and pushed with
`target update to`, reads back as **all zeros** inside a `target` region — but
only when the directive carries a `defaultmap` clause. Remove the clause and the
same loop reads the correct values.

* **Component:** CCE 21.0.2 Fortran, OpenMP target offload, gfx90a
* **Severity:** silent miscompilation — a conforming program reads zeros
* **Affected:** `-homp`
* **Version tested:** `Cray Fortran : Version 21.0.2 (20260604162910_c3fb8a56d0f4e468a9d0387a93105d6911ac9420)`

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../omp-defaultmap-scalar-override`](../omp-defaultmap-scalar-override) — very likely the same underlying defect, see below. [`../explicit-shape-dummy-lost-writes`](../explicit-shape-dummy-lost-writes) — the crash this one chains into. |

## 1. Files

| file | what it is |
| --- | --- |
| `resident_bare.f90` | **Baseline.** Bare `target teams distribute parallel do`. All three arrays read correctly. |
| `resident_defaultmap.f90` | **The reproducer.** Identical, plus three `defaultmap` clauses. All three read zero. |
| `dtptr_aggonly.f90` | Bisect: `defaultmap(tofrom:aggregate)` alone. |
| `dtptr_allocOnly.f90` | Bisect: `defaultmap(present:allocatable)` alone. |
| `dtptr_ptronly.f90` | Bisect: `defaultmap(present:pointer)` alone. |
| `control_negative_bounds.f90` | Negative control — negative lower bounds are **not** the trigger. |
| `control_named_exit.f90` | Negative control — a named multi-level `exit` is **not** the trigger. |
| `results/` | Captured runs. |

Each program allocates three arrays — a derived-type **pointer** component, a
derived-type **allocatable** component, and a **bare module array** — fills the
same cells in each on the host, and counts non-zeros twice: once on the host and
once in a device loop. Correct behaviour is `host == device`.

## 2. Reproduce

```bash
module reset
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2
ftn --version | head -1        # MUST say 21.0.2

ftn -homp -o resident_bare       resident_bare.f90
ftn -homp -o resident_defaultmap resident_defaultmap.f90

export LD_LIBRARY_PATH="$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
srun -n1 --gpus-per-task 1 ./resident_bare
srun -n1 --gpus-per-task 1 ./resident_defaultmap
```

Both compile cleanly with no diagnostics.

### Actual

```
##### resident_bare #####
pointer-component     host=982 device=982   PASS
allocatable-component host=982 device=982   PASS
bare module array     host=982 device=982   PASS

##### resident_defaultmap #####
pointer-component     host=982 device=0     FAIL
allocatable-component host=982 device=0     FAIL
bare module array     host=982 device=0     FAIL
```

The only difference between the two programs is this clause text on the loop
directive:

```
defaultmap(tofrom:aggregate) defaultmap(present:allocatable) defaultmap(present:pointer)
```

## 3. Each clause reproduces it on its own

| directive | pointer cmp | alloc cmp | bare array |
| --- | --- | --- | --- |
| bare | 982 | 982 | 982 |
| `defaultmap(tofrom:aggregate)` | **0** | **0** | **0** |
| `defaultmap(present:allocatable)` | **0** | **0** | **0** |
| `defaultmap(present:pointer)` | **0** | **0** | **0** |

So this is not specific to a category, nor to the kind of variable — a bare
module array fails under `defaultmap(present:pointer)`, which does not even name
its category. Any `defaultmap` clause on the directive is sufficient.

Independently re-measured on a clean build (`results/run-verified.txt`,
CCE 21.0.2 / ROCm 7.2.0): every row above reproduces exactly, and both negative
controls pass.

## 4. What it is not

Three constructs were eliminated with standalone tests, all of which **pass**
under OpenMP:

* **Negative lower bounds** (`control_negative_bounds.f90`) — an array declared
  `(-4:11)` in each dimension reads identically to a 1-based equivalent: 170 = 170.
* **Named multi-level `exit`** (`control_named_exit.f90`) — an `exit` out of a
  triple-nested loop from the innermost level: 3684 = 3684.
* **Derived-type pointer components** — `resident_bare.f90` reads all three
  variable kinds correctly without the clause.

## 5. Relationship to the scalar-override defect

This is very likely the same underlying defect as
[`../omp-defaultmap-scalar-override`](../omp-defaultmap-scalar-override), seen from a different angle. There, **any**
`defaultmap(<category>:scalar)` caused an *explicit* `map(to:)` of a scalar to be
disregarded. Here, **any** `defaultmap` causes an array that should resolve from
the *present table* to be disregarded. In both cases the presence of a
`defaultmap` clause breaks data-environment resolution for a variable that
should have been resolved by another mechanism.

If they are one defect, fixing it addresses both.

## 6. How this presented in a real application

MFC (<https://github.com/MFlowCode/MFC>) emits those three clauses on every
OpenMP `target` loop as its translation of OpenACC `default(present)`. The
immersed-boundary marker array is module-level, made resident, and read in a
counting loop that names it in no clause — so it read as empty:

```
host_markers= 4   device_markers= 0
```

measured in the application with the identical loop run both ways. The runtime
trace confirms the data was present and correct: 16,800 bytes transferred to
`acc 7ffea0628000`, and the array's pointer attached to `pointee 7ffea0628000`.

The consequence was not wrong numbers but a crash, via a four-step chain:
markers read empty → ghost-point count returns 0 → zero-length allocation → an
explicit-shape dummy `dimension(num_gps)` receives it and the first device store
faults.

The last link is [`../explicit-shape-dummy-lost-writes`](../explicit-shape-dummy-lost-writes).
Note that its README **disproves** the "maps as 0 bytes and hands back the host
pointer" description that was originally attached to that step: measured with
`CRAY_ACC_DEBUG=2`, the dummy maps correctly at its full size in both the failing
and passing cases. The chain above is still the observed sequence; the mechanism
of its final step is not established.

Deleting the `defaultmap` clauses from that translation fixed all of it: the
four immersed-boundary regression tests plus chemistry and viscous controls went
from 4 failing to **6/6 passing**, with nothing that previously passed regressed.

Confirmed at suite scale (job 5105473, full 627-test regression suite,
CCE 21.0.2 / ROCm 7.2.0, MPI). All CCE `defaultmap` emissions removed from the
OpenMP macro layer:

| backend | before | after |
|---|---|---|
| `--gpu mp` | 566 / 627, **60 exit-134** | **622 / 627, 0 exit-134** |
| `--gpu acc` | 622 / 627 | 622 / 627 (unchanged) |

**Every one of the 60 aborts is eliminated**, and both backends then fail the
identical five tests — all reported as tolerance mismatches, none as crashes.
That change touches every OpenMP `target` loop in the application, which is the
scale the claim needed. The five residuals are a separate question and are *not*
attributed to this defect.

## 7. Workaround

Emit no `defaultmap` clause. In OpenMP 5.0 the defaults it was restating are
already the defaults, so for this application removing it was semantically free
as well as necessary.
