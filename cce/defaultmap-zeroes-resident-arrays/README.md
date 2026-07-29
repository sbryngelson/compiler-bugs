# CCE 21: a `defaultmap` clause privatizes a scalar that carries an explicit `map(tofrom:)`

**Silent wrong answers.** Adding any `defaultmap` clause to a `target` construct causes a
scalar with an **explicit `map(tofrom:)` on the same directive** to be allocated in
thread-private memory instead. Every thread updates its own copy, nothing is written back,
and the host reads the value it started with.

The category named in the clause is **irrelevant**: `defaultmap(tofrom:aggregate)` —
a clause about aggregates — privatizes a mapped **scalar**.

```fortran
d1 = 0
!$omp target teams distribute parallel do collapse(3) map(tofrom: d1)      ! d1 = 982  correct
!$omp target teams distribute parallel do defaultmap(tofrom:aggregate) &
!$omp     defaultmap(present:allocatable) defaultmap(present:pointer) &
!$omp     collapse(3) map(tofrom: d1)                                       ! d1 = 0    WRONG
```

The two directives differ only by the `defaultmap` clauses. `d1` is explicitly mapped in both.

## Mechanism, from the device IR

The counter's atomic update lands in a different address space in each arm:

```llvm
; without defaultmap -- global, the mapped d1
%2 = atomicrmw add ptr addrspace(1) %r51, i32 1 syncscope("agent") monotonic

; with defaultmap -- addrspace(5) is thread-private scratch
%"$_pvt3_d1_t78" = alloca i32, align 4, addrspace(5)
%2 = atomicrmw add ptr addrspace(5) %"$_pvt3_d1_t78", i32 1 syncscope("agent") monotonic
```

`addrspace(5)` is per-thread private memory. The kernel counts correctly; the result has
nowhere to go.

**The arrays are not the problem.** An earlier revision of this entry described the defect as
"a resident array reads as all zeros inside the target region". That framing was wrong — the
device reads the arrays correctly and the count is computed correctly. What fails is the
*write-back of the scalar result*. Corrected after extracting the device IR and diffing the two
arms; the runtime traces are identical apart from allocation addresses, and `CRAY_ACC_DEBUG=3`
shows nothing amiss, because nothing is wrong with the mapping.

## Relationship to `omp-defaultmap-scalar-override`

This is the **same defect**, and this reproducer is the stronger statement of it. There,
`defaultmap(...:scalar)` overrode an explicit `map(to:)` on a scalar — at least the category
matched. Here a `defaultmap` naming only `aggregate`, `allocatable`, and `pointer` privatizes an
explicitly-mapped scalar. The two should be triaged together.

## Reproducing

```console
$ ./extract-device-ir.sh resident_bare.f90        bare_dev.ll
$ ./extract-device-ir.sh resident_defaultmap.f90  dm_dev.ll
$ grep -n 'atomicrmw add' bare_dev.ll dm_dev.ll     # addrspace(1) vs addrspace(5)
$ grep -n '_pvt.*d1'      dm_dev.ll                 # the private alloca, absent in the bare arm
```

`extract-device-ir.sh` pulls the IR out of the `.cray.llvm.offloading` section;
`-plugin-opt=save-temps` does **not** work for a direct `ftn` invocation.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../omp-defaultmap-scalar-override`](../omp-defaultmap-scalar-override) — very likely the same underlying defect, see below. [`../explicit-shape-dummy-lost-writes`](../explicit-shape-dummy-lost-writes) — the crash this one chains into. |

## 1. Files

| file | what it is |
| --- | --- |
| `resident_bare.f90` | **Baseline.** Bare `target teams distribute parallel do`. All three arrays read correctly. |
| `resident_defaultmap.f90` | **The reproducer.** Identical, plus three `defaultmap` clauses. All three read zero. |
| `resident_agg_only.f90` | Bisect: `defaultmap(tofrom:aggregate)` alone. |
| `resident_alloc_only.f90` | Bisect: `defaultmap(present:allocatable)` alone. |
| `resident_ptr_only.f90` | Bisect: `defaultmap(present:pointer)` alone. |
| `control_negative_bounds.f90` | Negative control — negative lower bounds are **not** the trigger. |
| `control_named_exit.f90` | Negative control — a named multi-level `exit` is **not** the trigger. |
| `results/` | Captured runs. |

Each program allocates three arrays — a derived-type **pointer** component, a
derived-type **allocatable** component, and a **bare module array** — fills the
same cells in each on the host, and counts non-zeros twice: once on the host and
once in a device loop. Correct behaviour is `host == device`.


> **Note on `results/`:** the captured runs pre-date a rename and refer to the
> bisect variants by their original names. `dtptr_aggonly` = `resident_agg_only`,
> `dtptr_allocOnly` = `resident_alloc_only`, `dtptr_ptronly` = `resident_ptr_only`.
> The outputs are left exactly as captured rather than edited to match.

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
