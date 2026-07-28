# CCE 21 ignores an explicit `map(to:)` for a scalar when `defaultmap(firstprivate:scalar)` is also present

**Wrong answers, no diagnostic.** A scalar that is *explicitly* data-mapped with
`map(to: count)` is privatised anyway when the same `target` directive carries
`defaultmap(firstprivate:scalar)`. An `!$omp atomic capture` on that scalar then
increments a per-thread copy, so instead of handing out unique indices it hands
the same index to nearly every iteration.

* **Reported by:** OLCF Frontier, project CFD154
* **Component:** CCE 21.0.2 Fortran, OpenMP target offload, gfx90a
* **Severity:** silent miscompilation — a spec-conforming program gets wrong results
* **Affected:** `-homp`. The OpenACC equivalent is correct.
* **Version tested:** `Cray Fortran : Version 21.0.2 (20260604162910_c3fb8a56d0f4e468a9d0387a93105d6911ac9420)`

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../defaultmap-zeroes-resident-arrays`](../defaultmap-zeroes-resident-arrays) — **very likely the same underlying defect**, seen on resident arrays rather than explicitly-mapped scalars. [`../defaultmap-firstprivate`](../defaultmap-firstprivate) — **a different defect**, same clause: there CCE 19 fails to firstprivate scalars covered by `defaultmap` and produces `NaN`; here CCE 21 firstprivates a scalar that was *explicitly* `map`-ed. Do not merge the two. |

## 1. Why we believe this is non-conforming

OpenMP specifies `defaultmap` as the fallback for variables that are **not**
otherwise explicitly data-mapped or privatised. An explicit `map` clause for a
given variable takes precedence. Here the same directive contains both
`defaultmap(firstprivate:scalar)` and `map(to: count)`, and the explicit clause
should win, leaving `count` a single shared object in the device data
environment.

## 2. Files

| file | what it is |
| --- | --- |
| `atomcap_omp_defaultmap.f90` | **The reproducer.** `defaultmap(firstprivate:scalar)` + `map(to: count)`. |
| `atomcap_omp_maponly.f90` | Control: identical but with the `defaultmap` clause deleted. |
| `atomcap_acc.f90` | Control: the OpenACC equivalent, `copyin(count)`. |
| `run-output.txt` | The run below, as captured. |

The two OpenMP sources differ by exactly one clause (and the label string).

## 3. Reproduce

```bash
module reset
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2

ftn --version | head -1      # MUST say 21.0.2 -- see the warning below
ftn -homp -o atomcap_omp_defaultmap atomcap_omp_defaultmap.f90
ftn -homp -o atomcap_omp_maponly    atomcap_omp_maponly.f90
ftn -hacc -o atomcap_acc            atomcap_acc.f90

export LD_LIBRARY_PATH="$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
for b in atomcap_acc atomcap_omp_maponly atomcap_omp_defaultmap; do
    srun -n1 --gpus-per-task 1 "./$b"
done
```

All three compile cleanly with no diagnostics.

> **Check the compiler version before believing a PASS.** The obvious one-liner
> `module load cpe/26.03 cce/21.0.2 rocm/7.2.0 craype-accel-amd-gfx90a` **looks
> like it works and does not.** `ftn` keeps dispatching the default CCE (18.0.1
> on Frontier) and the accelerator target is left unset, so `-homp` / `-hacc` are
> ignored with `ftn-1350 ... an accelerator target has not been specified`, every
> variant builds as **host** code, and they all print `PASS` — a false negative
> that looks exactly like a fixed compiler. You need `module reset`, then `cpe`,
> then an explicit `module swap cce`. [`../contiguous-mix-dropped-stores/run_versions.sh`](../contiguous-mix-dropped-stores/run_versions.sh)
> already encodes the working recipe. Two cheap confirmations that the
> environment is right: `ftn --version` reports 21.0.2, and the compiler banner
> ends `Target is x86-64 : x86-trento : none : amdgcn-gfx90a` rather than
> `... : none : none`.

### Expected

Each of the 4096 iterations captures a distinct value, so `slot` is a
permutation of 1..4096 — no out-of-range values and no duplicates.

### Actual

```
acc copyin (control):     out_of_range=0 (<=0: 0)  duplicates=0     of 4096   PASS
omp map only        :     out_of_range=0 (<=0: 0)  duplicates=0     of 4096   PASS
omp defaultmap+map  :     out_of_range=0 (<=0: 0)  duplicates=4095  of 4096   FAIL
omp map-then-defaultmap:  out_of_range=0 (<=0: 0)  duplicates=4095  of 4096   FAIL
omp tofrom+map      :     out_of_range=0 (<=0: 0)  duplicates=4095  of 4096   FAIL
```

**4095 of 4096 iterations receive a duplicate index.** Adding a `defaultmap`
clause for scalars to a directive that already maps the scalar explicitly is the
only difference between the passing and failing OpenMP runs.

Full variant matrix, all on CCE 21.0.2 / gfx90a, same program otherwise:

| directive form for `count` | unique indices | verdict |
| --- | --- | --- |
| OpenACC `copyin(count)` | 4096 / 4096 | PASS (reference) |
| `map(to:count)`, no `defaultmap` | 4096 / 4096 | **PASS — the only correct OpenMP form** |
| *(nothing: no map, no defaultmap)* | 256 / 4096 | fails, but **conforming** — scalars are firstprivate by default |
| `defaultmap(firstprivate:scalar)` + `map(to:count)` | 1 / 4096 | **FAIL** |
| `map(to:count)` + `defaultmap(firstprivate:scalar)` | 1 / 4096 | **FAIL** — order is irrelevant |
| `defaultmap(tofrom:scalar)` + `map(to:count)` | 1 / 4096 | **FAIL** |
| `defaultmap(firstprivate:scalar)` + `map(tofrom:count)` | 1 / 4096 | **FAIL** |

Reading the matrix:

* **The bare row is conforming, not a bug.** With no clause at all the scalar is
  firstprivate, which is the OpenMP 5.0 default for scalars in a `target`
  region. Included so the defect is not confused with the default.
* **An explicit `map` is honoured — but only when no `defaultmap` for scalars is
  present.** That is the whole defect: `defaultmap` should apply *only* to
  variables that are not explicitly data-mapped, so its presence must not change
  how `count` behaves.
* **Not specific to `firstprivate`, and not fixable from the map side.**
  `defaultmap(tofrom:scalar)` fails, and `map(tofrom:count)` fails. Under
  `defaultmap(tofrom:scalar)` *neither* reading predicts a per-thread result —
  whether the explicit clause wins or the defaultmap wins, the scalar should be
  shared. It is not.
* Note the failing rows collapse to a **single** distinct index across all 4096
  iterations, which is worse than the conforming firstprivate default (256).

### `atomic update` is unaffected — it is `atomic capture` that breaks

The `*_update` variants drop the capture and keep only the increment, on a scalar
mapped `tofrom` with no `defaultmap` clause. Both are correct:

| variant | directive | result |
| --- | --- | --- |
| `atomcap_omp_update.f90` | `!$omp target ... map(tofrom:count)` + `atomic update` | `count=4096 of 4096` **PASS** |
| `atomcap_acc_update.f90` | `!$acc parallel loop copy(count)` + `atomic update` | `count=4096 of 4096` **PASS** |

So the atomic itself is fine on a shared mapped scalar under both models, and the
total is exactly right — which rules out "the atomic is racy" as an explanation and
localises the defect to how `defaultmap` changes the *data environment* of an
explicitly-mapped scalar. These two are controls, not failing cases.

## 4. The kernel of it

```fortran
count = 0
!$omp target teams distribute parallel do defaultmap(firstprivate:scalar) &
!$omp& map(to:count) map(from:slot) private(local_idx)
do i = 1, n
    !$omp atomic capture
    count = count + 1
    local_idx = count
    !$omp end atomic
    slot(i) = local_idx
end do
```

Every value lands in range, so this is not a wild index — each thread simply
counts in its own private copy of `count`.

## 5. How we hit it

MFC (<https://github.com/MFlowCode/MFC>) uses exactly this pattern to allocate
immersed-boundary ghost-point slots. Its macro layer emits
`defaultmap(firstprivate:scalar)` on every OpenMP `target` region and adds
`map(to: count)` from the user's `copyin` list, giving the failing combination.
Under OpenACC the equivalent `copyin(count)` is correct, so the same source is
right on one offload model and wrong on the other:

```
!$acc parallel loop collapse(3) gang vector default(present) ... copyin(count, count_i, glb_bounds)
!$omp target teams distribute parallel do defaultmap(firstprivate:scalar) ... map(to:count, count_i, glb_bounds)
```

**Attribution — please read this before weighting the report.** We found this
defect while chasing a segfault in the same routine, and it is tempting to
present it as the cause. It is not, and we have measured that:

* Removing `defaultmap(firstprivate:scalar)` from our macro layer — verified
  absent in the regenerated OpenMP source for both build configurations — leaves
  the application segfault **bit-identical**, same faulting kernel
  (`s_find_ghost_points$m_ibm_$ck_L627_31`) and same fault address
  (`0x155552eb3000`) across two separately-built binaries.
* So the immersed-boundary aborts in our application have some other cause,
  still open at the time of writing.

What we are reporting is therefore the **standalone defect in §3**, which is
fully reproduced and does not depend on our application at all. Its consequence
in MFC is that the ghost-point slot allocation is silently wrong — a real
correctness bug we have to fix regardless — but it is not the crash that led us
here, and we would rather say so than overstate the impact.

## 6. Workaround

**Drop the `defaultmap(<category>:scalar)` clause.** That is the only working
form we found — changing the explicit map's category does not help
(`map(tofrom:)` fails too), and neither does reordering.

Dropping it is semantically free: the matrix in §3 shows that with no clause at
all, scalars are already firstprivate, which is what
`defaultmap(firstprivate:scalar)` was asking for. So the clause only restates
the OpenMP 5.0 default while breaking every explicitly-mapped scalar in the same
region.

This is what we did in MFC — removed the clause from the CCE branch of the
OpenMP loop-directive emitter, leaving the other compilers' branches alone. The
AMD branch already omitted it.
