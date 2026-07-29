# CCE 21: device writes through an explicit-shape dummy with a runtime extent are lost under OpenMP

> **Severity:** **Silent wrong answers** — device writes never reach the host  
> **Fix belongs to:** CCE Fortran front end  
> **Status:** Root-caused: no extent is emitted for an explicit-shape dummy, so the implicit map is 0 bytes and the runtime returns the host pointer.

**Wrong answers, no diagnostic, no crash.** A module-resident allocatable array of a
derived type is passed to a routine whose dummy is declared **explicit-shape with a
runtime extent** — `dimension(n_gp)`. Under OpenMP target offload, writes performed on
the device through that dummy are not visible on the host afterwards. The identical
routine with an **assumed-shape** dummy — `dimension(:)` — is correct, and so is the
identical program under OpenACC.

* **Component:** CCE Fortran, OpenMP target offload data environment, gfx90a
* **Severity:** silent miscompilation — wrong numerical results
* **Affected:** `-homp`. The OpenACC equivalent is correct.
* **Versions:** CCE 21.0.2; the OpenMP failure also reproduces on CCE 19.0.0

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with HPE/Cray 2026-07-28 — case ID pending |
| MFC issue | [MFlowCode/MFC#1684](https://github.com/MFlowCode/MFC/issues/1684) |
| Related | [`../defaultmap-zeroes-resident-arrays`](../defaultmap-zeroes-resident-arrays) — in the application these two chain: a `defaultmap` clause makes the marker array read empty, the ghost-point count returns 0, and the zero-length allocation is what this defect's explicit-shape dummy then receives |

## Files

| file | what it is |
|---|---|
| `dummyshape.f90` | **The reproducer**, OpenMP target offload. Self-checking, 64 elements. |
| `dummyshape_acc_fixed.f90` | **The OpenACC control.** Passes on both dummy shapes — this is what makes the defect OpenMP-specific rather than "explicit-shape dummies are unreliable". |
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

### Measured — CCE 21.0.2 / ROCm 7.2.0, gfx90a

| model | dummy | wrong | result |
|---|---|---|---|
| OpenMP | `dimension(:)` | 0 / 64 | PASS |
| OpenMP | `dimension(n_gp)` | **64 / 64** | **FAIL** |
| OpenACC | `dimension(:)` | 0 / 64 | PASS |
| OpenACC | `dimension(n_gp)` | 0 / 64 | PASS |

Every element is wrong in the failing row, not some — the writes do not land anywhere
the host can see them. The OpenMP failure also reproduces on **CCE 19.0.0**, so the
OpenMP side is not a 21.x regression.

## Why the OpenACC control matters, and how it was got wrong twice

A model-to-model comparison is only evidence **if the control arm passes**. This
reproducer had two successive OpenACC controls that failed for reasons unrelated to
the defect, and each time the failure looked like "OpenACC is affected too":

1. **`exit data copyout` after `declare create`.** With `gps` already device-resident,
   `exit data copyout(gps)` only decrements the reference count and transfers **0 bytes
   to the host**, so nothing came back and both dummy shapes failed.
2. **`declare create(gps, n_gp)` on the allocatable.** Replacing the copy-back with
   `update self` fixed symptom 1 but not the cause: `declare create` on an allocatable
   establishes the device descriptor at module scope, *before* the array has an extent,
   so the later `enter data copyin(gps)` finds it present and moves **0 bytes**. The
   trace shows it plainly — `allocate 'gps(:)' (2560 bytes)` followed by
   `End transfer (to acc 0 bytes)`. The explicit arm still failed, and that failure was
   an artifact of this mapping, not of the dummy shape.

`dummyshape_acc_fixed.f90` keeps `declare create` for the **scalar only** and maps the
array **once, after allocation**:

```fortran
!$acc declare create(n_gp)
...
allocate (gps(n_gp))
!$acc update device(n_gp)
!$acc enter data copyin(gps)     ! allocate, copy to acc 'gps(:)' (2560 bytes)
```

With that, both OpenACC arms pass and the OpenMP-only asymmetry is established.

## What the mechanism is *not*

**Not a zero-length map, and not a host address handed back in place of a device one.**
`CRAY_ACC_DEBUG=2` on the OpenMP program shows the data environment is identical and
correct in both the failing and the passing case — the dummy is mapped `present` at its
full 2560 bytes either way, and the copy-back moves the full 2560 bytes to the host
either way:

```
  explicit (FAIL)                          assumed (PASS)
  present 'a(:)' (2560 bytes)              present 'a(:)' (2560 bytes)
  copy to host, free, update dope vector   copy to host, free, update dope vector
      'gps(:)' (2560 bytes)                    'gps(:)' (2560 bytes)
  End transfer (to host 2560 bytes)        End transfer (to host 2560 bytes)
```

**Not the launch geometry.** The explicit-shape form launches `blocks:220 threads:256`
— 56,320 threads for a 64-iteration loop — against `1 × 256` for the assumed-shape
form, and an earlier revision of this file offered that as the smoking gun. It is not:
the **passing** OpenACC explicit-shape arm launches `blocks:220 threads:256` too. The
oversized grid is how CCE lowers this loop form, not a symptom of the defect.

So no mechanism is established here. What is established is the behaviour, its
model-dependence, and two hypotheses that are ruled out.

## Workaround

**Declare the dummy assumed-shape**, `dimension(:)`. Measured correct under both models.
In MFC this is the shape these routines should have had anyway, since the actual
argument is always a whole module allocatable.


## Root cause: no extent is emitted for the explicit-shape dummy

The two routines differ only in how the dummy is declared, and that changes the **kernel
signature**. Extracted with `./extract-device-ir.sh dummyshape.f90 ds.ll`:

| routine | dummy | kernel arguments |
| --- | --- | --- |
| `fill_assumed` | `dimension(:)` | **4** — base pointer plus descriptor bounds |
| `fill_explicit` | `dimension(n_gp)` | **1** — a bare pointer, nothing else |

```llvm
; assumed-shape: descriptor travels with the argument
define amdgpu_kernel void @"fill_assumed$m_gp_$ck_L39_7"(i64, i64, i64, i64)

; explicit-shape: one pointer, no extent
define amdgpu_kernel void @"fill_explicit$m_gp_$ck_L30_1"(i64 %"$$arg_ptr_acc_a_t25_t561")
  ...
  %r = load i32, ptr addrspace(1) @n_gp__cray_acc   ; loop bound read from the device global
```

Note the kernel *does* obtain the loop count — it reads `n_gp` from device memory — so it
iterates the right number of times. What it never receives is a **device** pointer for `a`.

An explicit-shape dummy carries no descriptor, so the size for the implicit map has to be
computed by the compiler from the declared extent (`n_gp`) at the call site. It is not: the
runtime trace shows the map arriving as **0 bytes** with `DOPE_VECTOR` absent from the flags —

```
'ghost_points_in(:)' (0 bytes)
     flags: ALLOCATE COPY_HOST_TO_ACC ACQ_PRESENT REG_PRESENT     <- no DOPE_VECTOR
     memory not found in present table
     allocate (0 bytes)
     new acc ptr 7fffeb364d90                                     <- a host address
```

With a zero-length allocation there is no device buffer, so the runtime returns the host
address, and the kernel — iterating the correct number of times — writes across the host
pointer from the GPU. Nothing faults on a machine with unified addressing; the writes simply
never appear in the device copy the host later reads back.

**So the chain is:** no descriptor -> compiler emits no extent -> 0-byte map -> no allocation ->
host pointer returned -> device writes lost.

The OpenACC arm is correct because it supplies the bounds, which is what makes this reportable
rather than "explicit-shape dummies are unsupported": the same source construct on the same
compiler and hardware is correct under one offload model and silently wrong under the other.

### Fix

Emit the extent for an explicit-shape dummy — the declared bound is available at the call site
— or reject the construct with a diagnostic. Producing a 0-byte map and continuing is the worst
of the three options, because it fails silently.
