# CCE 21: `defaultmap` overrides an explicit `private` clause

**Abort.** A local array that is explicitly listed in a `private(...)` clause on a
`target` construct is looked up in the **present table** anyway when the same
directive carries `defaultmap(present:aggregate)`, and the program dies:

```
ACC: find_in_present_table failed for 'length(:)' (0x4079c0-0x4079d8)
ACC: libcrayacc/acc_runtime.c:856 CRAY_ACC_ERROR - Variable not found in present table
```

A private variable has no business in the present table at all.

* **Reported by:** OLCF Frontier, project CFD154
* **Component:** CCE 21.0.2 Fortran, OpenMP target offload, gfx90a
* **Severity:** abort — loud, not silent, unlike defects 05 and 11
* **Affected:** `-homp`, `defaultmap(present:…)` only; `tofrom` does not surface it
* **Version tested:** `Cray Fortran : Version 21.0.2 (20260604162910_c3fb8a56d0f4e468a9d0387a93105d6911ac9420)`


## Distinct from the other two `defaultmap` entries — this one is host-side

It is tempting to fold this together with `defaultmap-zeroes-resident-arrays` and
`omp-defaultmap-scalar-override`, which are one defect (a `defaultmap` clause privatizing an
explicitly-mapped scalar). **This is a different mechanism**, and the device IR proves it.

Extracted with `../extract-device-ir.sh`, all three arms are identical — same length, no
privatization, no address-space change:

| arm | lines | `$_pvt` allocas | `addrspace(5)` atomics |
| --- | --- | --- | --- |
| `priv_bare` | 92 | 0 | 0 |
| `priv_defaultmap_present` | 92 | 0 | 0 |
| `priv_defaultmap_tofrom` | 92 | 0 | 0 |

The generated device code is the same with and without the clause, so nothing in codegen
explains the abort. The failure is on the **host side**: a present-table lookup is issued for a
variable that appears in an explicit `private()` clause, and `find_in_present_table` fails
because a private variable was never mapped.

Note the direction is the *opposite* of the other two: there, `defaultmap` privatizes something
that should be mapped; here it maps (looks up) something that should be private. Both are
`defaultmap` overriding an explicit clause, which is likely a common root in clause-precedence
handling — but they are not the same code path and should not be merged on the assumption that
one fix covers both.

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../05-omp-atomic-capture-scalar`](../05-omp-atomic-capture-scalar), [`../11-defaultmap-zeroes-resident-arrays`](../11-defaultmap-zeroes-resident-arrays) — very likely the same defect |

## 1. Files

| file | what it is |
| --- | --- |
| `priv_bare.f90` | **Baseline.** `private(length)`, no `defaultmap`. Correct. |
| `priv_defaultmap_present.f90` | **The reproducer.** Identical, plus `defaultmap(present:aggregate)`. Aborts. |
| `priv_defaultmap_tofrom.f90` | Same with `defaultmap(tofrom:aggregate)`. Correct — the category matters. |

Twenty lines each. The array is `real(wp) :: length(3)`, written and read only
inside the loop body, and named in the `private` clause.

## 2. Reproduce

```bash
module reset
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2
ftn --version | head -1        # MUST say 21.0.2

for b in priv_bare priv_defaultmap_present priv_defaultmap_tofrom; do
    ftn -homp -o "$b" "$b.f90"
done

export LD_LIBRARY_PATH="$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
for b in priv_bare priv_defaultmap_present priv_defaultmap_tofrom; do
    srun -n1 --gpus-per-task 1 "./$b"
done
```

All three compile cleanly with no diagnostics.

### Actual

```
##### priv_bare #####
private-array  wrong=0 of 256   PASS

##### priv_defaultmap_present #####
ACC: find_in_present_table failed for 'length(:)' (0x4079c0-0x4079d8) from priv_defaultmap_present.f90:10
ACC: libcrayacc/acc_runtime.c:856 CRAY_ACC_ERROR - Variable not found in present table
srun: error: task 0: Exited with exit code 1

##### priv_defaultmap_tofrom #####
private-array  wrong=0 of 256   PASS
```

The only difference between the passing and aborting programs is the presence of
`defaultmap(present:aggregate)` on the directive.

## 3. Why this is non-conforming

OpenMP specifies `defaultmap` as the fallback for variables that are **not**
otherwise explicitly data-mapped or privatised. `length` is explicitly privatised
on the same directive, so `defaultmap` must not apply to it — and a privatised
variable is never looked up in the present table under any reading.

Note the category dependence: `tofrom:aggregate` is silently tolerated while
`present:aggregate` aborts. That is consistent with `defaultmap` being applied to
`length` in both cases and only the `present` category having a failure mode that
announces itself.

## 4. This is one defect with three faces

| entry | `defaultmap` overrides | symptom |
| --- | --- | --- |
| [05](../05-omp-atomic-capture-scalar) | an explicit `map(to:)` on a scalar | duplicate indices, silent |
| [11](../11-defaultmap-zeroes-resident-arrays) | present-table residency for a resident array | reads zero, silent |
| **13** (this) | an explicit **`private`** clause on a local array | abort, loud |

Three different explicit specifications, all disregarded when a `defaultmap`
clause is present. If that is one bug, one fix addresses all three — and 05 and
11 are the dangerous pair, because they produce wrong answers rather than
stopping.

## 5. How it was found, and a correction worth recording

This surfaced while trying `defaultmap(present:aggregate)` as a candidate fix for
defect 11 in MFC. The abort named `length(:)` at `m_ib_patches.fpp:145`, and it
was initially recorded as *a latent MFC residency bug that the `tofrom` default
had been masking* — the reasoning being that `present` is stricter and had merely
exposed an array MFC never made resident.

That was wrong. `length` is declared `real(wp), dimension(3)` and appears in that
loop's `private` list; it is not resident because it is not supposed to be. The
standalone above reproduces the abort with no application involved.

The mistake was inferring an application bug from a compiler abort without
reading the declaration. Recorded because the same shape of error — treating the
compiler's behaviour as evidence about the program — cost several rounds
elsewhere in this investigation.

## 6. Workaround

Emit no `defaultmap` clause. That is what MFC does now
(`a5565114`), which also fixes defects 05 and 11.
