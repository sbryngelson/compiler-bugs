# Cray CCE 15.0.1 Fortran + OpenACC Bugs

Minimal reproducers for OpenACC bugs in Cray CCE 15.0.1 on OLCF Frontier (MI250X).
All cases involve `!$acc declare` (link or create) on module-scope variables and/or
nested allocatable derived types. Bug reports: **OLCFDEV-1416, CAST-31898**.

Compile with `ftn -h acc`; run with `srun -n 1 ./test`.

---

| Dir | Variable type | `declare` clause | Kernel | Issue |
|-----|--------------|------------------|--------|-------|
| test-bug1 | `allocatable` scalar array | `link` | `parallel loop` + `routine seq` | seq routine writing to `declare link` array called from parallel loop |
| test-bug2 | `allocatable` array, non-zero lower bound (`-5:5`) | `link` | `parallel loop` | non-unit lower bound under `declare link` |
| test-bug3 | nested allocatable derived type (`outer%inner(i)%data`) | none (manual `enter data`) | `kernels` | 2-level nested struct, element-wise `enter data copyin` |
| test-bug4 | derived type with allocatable member, scalar struct | `declare create` on struct | `parallel loop` + `routine seq` | `declare create` on struct + `enter data create` on member + seq routine |
| test-bug5 | same as test-bug3, smaller dims (ninner=2, ndat=2) | none | `kernels` | minimal 2-level nested struct reproducer |
| test-bug6 | 2-level nested struct, outer is allocatable array | `declare link` on outer | `kernels` | 3-level loop over `outer(k)%inner(i)%data(j)` with `declare link` |
| test-bug7 | same as test-bug6, multi-file build | `declare link` on outer | `parallel loop` + `routine seq` (multi-TU) | seq routine + present clause across separate compilation units |
| test-bug8 | 2-level nested struct, outer is scalar | `declare create` on outer | `kernels` + `routine seq` | scalar outer struct with `declare create`, seq routine writes member |
| test-bug9 | 2-level nested struct, outer is allocatable array | none (declare link commented out) | `kernels` | same as test-bug6 without any declare — tests manual enter data only |
| test-bug10 | flat array of derived types (`inner(ninner)%data`) | `declare link` on inner | `kernels default(present)` + `routine seq` | element-wise `enter data` + seq routine + `default(present)` |
| test-bug11 | 2-level nested struct, outer is allocatable array | `declare create` on outer | `kernels default(present)` | `declare create` + `default(present)` with nested struct |
| test-bug12 | same as test-bug11 | `declare link` on outer | `kernels default(present)` | `declare link` vs `declare create` comparison for test-bug11 |

## Archived cases

`archive/` — cases that were fixed in CCE or kept for reference (allocatable derived types, scalar control cases).
