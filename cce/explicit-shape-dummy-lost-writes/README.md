# CCE: device writes through an explicit-shape dummy with a runtime extent are lost

**Wrong answers, no diagnostic, no crash.** A module-resident allocatable array of a
derived type is passed to a routine whose dummy is declared **explicit-shape with a
runtime extent** — `dimension(n_gp)`. Writes performed on the device through that
dummy are not visible on the host afterwards. The identical routine with an
**assumed-shape** dummy — `dimension(:)` — is correct.

* **Component:** CCE Fortran, offload data environment, gfx90a
* **Severity:** silent miscompilation — wrong numerical results
* **Affected:** CCE **21.0.2** and CCE **19.0.0**, under **both** `-homp` and `-hacc`
* **Not a regression:** 19.0.0 and 21.0.2 behave identically

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../promote-alloca-dropped-store`](../promote-alloca-dropped-store), [`../omp-defaultmap-scalar-override`](../omp-defaultmap-scalar-override) — the other silent-wrong-answer defects from the same port |

## Files

| file | what it is |
|---|---|
| `dummyshape.f90` | **The reproducer**, OpenMP target offload. Self-checking, 64 elements. |
| `dummyshape_acc.f90` | The same program in OpenACC. |
| `build_and_run.sh` | Guarded build; prints the `srun` lines. |
| `results/` | The runs quoted below, as captured. |

## The kernel of it

```fortran
type(gp_t), allocatable :: gps(:)
integer :: n_gp
!$omp declare target(gps, n_gp)

subroutine fill_explicit(a)                    ! <<< runtime extent
    type(gp_t), dimension(n_gp), intent(inout) :: a
    !$omp target teams distribute parallel do
    do i = 1, n_gp
        a(i)%loc = [i, 2*i, 3*i]               ! <<< these writes are lost
    end do
end subroutine

subroutine fill_assumed(a)                     ! <<< carries a descriptor
    type(gp_t), dimension(:), intent(inout) :: a
    !$omp target teams distribute parallel do
    do i = 1, size(a)
        a(i)%loc = [i, 2*i, 3*i]               ! <<< correct
    end do
end subroutine
```

## Reproduce

```bash
module reset
module load cpe/26.03 rocm/7.2.0 craype-accel-amd-gfx90a
module swap cce cce/21.0.2
./build_and_run.sh              # verifies the toolchain, then prints the srun lines
```

### Measured

```
                       CCE 21.0.2        CCE 19.0.0
  -homp  explicit      wrong=64 of 64    wrong=64 of 64    FAIL
  -homp  assumed       wrong=0  of 64    wrong=0  of 64    PASS
  -hacc  explicit      wrong=64 of 64    wrong=64 of 64    FAIL
  -hacc  assumed       wrong=0  of 64    wrong=0  of 64    PASS
```

Every element is wrong, not some — the writes do not land anywhere the host can see
them.

## What the mechanism is *not*

`CRAY_ACC_DEBUG=2` shows the data environment is **identical and correct** in both
the failing and the passing case. The dummy is mapped `present` at its full
2560 bytes either way, and the copy-back at the end moves the full 2560 bytes to the
host either way:

```
  explicit (FAIL)                          assumed (PASS)
  present 'a(:)' (2560 bytes)              present 'a(:)' (2560 bytes)
  ...                                      ...
  copy to host, free, update dope vector   copy to host, free, update dope vector
      'gps(:)' (2560 bytes)                    'gps(:)' (2560 bytes)
  End transfer (to host 2560 bytes)        End transfer (to host 2560 bytes)
```

So this is **not** a zero-length map, and the dummy is not being handed a host
address in place of a device one. An earlier note on this reproducer said it was;
that description is not supported by the evidence above and should not be repeated
without re-measuring.

## What does differ

The launch geometry, which points at the loop bound rather than the mapping:

| | kernel | blocks × threads | for a 64-iteration loop |
|---|---|---|---|
| explicit (FAIL) | `dummyshape_$ck_L55_17` | **220 × 256 = 56,320** | wildly oversized |
| assumed (PASS) | `dummyshape_$ck_L53_14_cce$noloop$form` | 1 × 256 | as expected |

The explicit-shape form launches ~880× the needed threads, which is what you would
expect if the trip count derived from the dummy's runtime extent `n_gp` is garbage on
the device — even though `n_gp` itself is mapped and reported `present (4 bytes)`.

**This is the observation, not a root cause.** We have not established what the
kernel actually computes for the bound, nor why *no* element lands correctly rather
than the in-range prefix landing and the rest scribbling out of bounds. Anyone
pursuing this should start by dumping the trip-count computation in the generated
device code for the two forms.

## Workaround

**Declare the dummy assumed-shape**, `dimension(:)`. Measured correct on both
compilers and both offload models. In MFC this is the shape these routines should
have had anyway, since the actual argument is always a whole module allocatable.

## Note on the OpenACC reproducer

`dummyshape_acc.f90` copies results back with `update self` + `exit data delete`
rather than `exit data copyout`. That is deliberate. With `!$acc declare create`
already making `gps` device-resident, an `exit data copyout(gps)` only decrements the
reference count and transfers **0 bytes to the host**, so *both* dummy shapes fail
and the test isolates nothing:

```
ACC:       release present 'gps(:)' (2560 bytes)
ACC: End transfer (to acc 0 bytes, to host 0 bytes)     <<< nothing came back
```

That is a defect in the test, not in the compiler. An earlier draft of this
reproducer had it, and it made OpenACC look broken for both shapes. Fixed here; the
OpenACC rows in the table above are from the fixed version. See
`results/run-acc-fixed-and-mapping-evidence.txt`.
