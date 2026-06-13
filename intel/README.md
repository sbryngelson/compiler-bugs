# Intel GPU OpenMP Target Offload Bug Reproducers

Minimal Fortran reproducers for confirmed bugs in Intel `ifx` OpenMP target offload
on Intel GPU Max 1100 (Ponte Vecchio / PVC).

## Environment

### Hardware
- **GPU**: Intel GPU Max 1100 (Ponte Vecchio / PVC)
- **System**: TAMU ACES cluster, `pvc` partition

### Software stack

| Component | Version |
|-----------|---------|
| `ifx` (Intel Fortran) | 2025.1.1 (20250418) |
| `icx` / `icpx` (Intel C/C++) | 2025.1.1 (20250418) |
| Intel MPI (`mpiifx`, `mpirun`) | 2021.15 (build 20250213) |
| `intel-compilers` module | 2025.1.1 |
| `iimpi` bundle | 2025a |
| `imkl` | 2025.1.0 |
| GCCcore (toolchain base) | 14.2.0 |
| UCX | 1.18.0 |
| Intel compute runtime | 25.18.33578.42 |
| Level Zero (`libze_loader`) | 1.24.0 |

### Module load sequence (EasyBuild/Lmod)

```bash
module load iimpi/2025a        # loads: GCCcore/14.2.0, binutils/2.42, zlib/1.3.1,
                                #        intel-compilers/2025.1.1, numactl/2.0.19,
                                #        UCX/1.18.0, impi/2021.15.0
module load imkl/2025.1.0      # Intel Math Kernel Library (optional for these tests)
```

### Compile command

AOT compilation for PVC via the `ocloc` offline compiler (invoked internally by `ifx`
through `-Xopenmp-target-backend`):

```bash
ifx -fiopenmp                          \
    -fopenmp-targets=spir64_gen        \
    -Xopenmp-target-backend "-device pvc" \
    -O2                                \
    -o <exe> <file>.f90
```

Key flags:
- `-fiopenmp` — enable Intel OpenMP (required for `!$omp` directives)
- `-fopenmp-targets=spir64_gen` — AOT compilation to Intel GPU SPIR-V binary
- `-Xopenmp-target-backend "-device pvc"` — target Intel GPU Max 1100 (PVC)
- `-O2` — optimization level (bugs reproduce at all levels including `-O0`)

> **Note**: `-Xopenmp-target-backend` must be passed as a two-argument pair with the
> value quoted. In shell scripts, use a bash array to preserve the quoting:
> ```bash
> FLAGS=(-fiopenmp -fopenmp-targets=spir64_gen -Xopenmp-target-backend "-device pvc" -O2)
> ifx "${FLAGS[@]}" -o exe file.f90
> ```

Or use the provided `compile_all.sh`.

---

## Bug 1 — `matmul()` inside `!$omp declare target` subroutine gives wrong results

**File**: `bug1_matmul_in_declare_target.f90`

A subroutine marked `!$omp declare target` calls `matmul()` on a module-level
matrix that is also `declare target`. The subroutine is invoked from a GPU kernel.
On CPU the result is correct; on Intel GPU every output element is 0.

**Workaround**: Replace `matmul(A, v)` with explicit dot-product expansion.

```
Expected: PASS
Observed: FAIL (all output elements 0.0)
```

---

## Bug 2 — Allocatable `declare target` module variable inaccessible in `declare target` function

**File**: `bug2_allocatable_declare_target.f90`

An allocatable module-level array marked `!$omp declare target` is allocated on
the host, then copied to device via `!$omp target update to(...)`. Inside a
`!$omp declare target` function the array reads back as all zeros on the device.

The non-allocatable variant (fixed-size array with `declare target`) works correctly.

```
Expected: PASS
Observed: FAIL (all output elements 0.0)
```

---

## Bug 3 — Nested pointer struct mapping causes runtime abort

**Files**: `bug3_nested_pointer_struct_map.f90` (bug), `bug3_workaround.f90` (fix)

A derived type containing an allocatable array of derived types, where each
element has a `pointer` component (`vector_field -> scalar_field -> sf(:,:,:)`),
causes an OpenMP runtime abort when the inner pointer data is mapped without
first mapping the outer containers:

```
omptarget message: explicit extension not allowed: host address specified is
0x... (240 bytes), but device allocation maps to host at 0x... (120 bytes)
```

**Workaround**: Map the struct hierarchy in order — outer struct first, then
attach inner pointers with separate `target enter data` calls:

```fortran
!$omp target enter data map(to: q)             ! 1. outer struct
!$omp target enter data map(to: q%vf)          ! 2. attach allocatable pointer
do i = 1, n
    !$omp target enter data map(to: q%vf(i)%sf)  ! 3. attach inner pointer
end do
```

The workaround is confirmed to work on this compiler/hardware.

```
Expected: PASS
Observed: omptarget runtime abort
```

---

## Bug 4 — Allocatable `declare target` module variable causes GPU segfault

**File**: `bug4_allocatable_declare_target_segfault.f90`

Similar to Bug 2 but with a smaller allocatable array: allocating on host and
doing `!$omp target update to(var)` leaves the device-side pointer null.
Accessing the array in a `declare target` function segfaults on the GPU:

```
Segmentation fault from GPU at 0x0, ctx_id: 1 (CCS) type: 0 (NotPresent),
level: 3 (PML4), access: 0 (Read), banned: 1, aborting.
Abort was called at 288 line in file:
/home/ubit/rpmbuild/BUILD/intel-compute-runtime-25.18.33578.42/shared/source/
os_interface/linux/drm_neo.cpp
```

```
Expected: PASS
Observed: GPU segfault (abort)
```

---

## Summary

| Bug | File | Symptom | Workaround |
|-----|------|---------|------------|
| 1 | `bug1_matmul_in_declare_target.f90` | Wrong result (zeros) | Explicit dot-product expansion instead of `matmul` |
| 2 | `bug2_allocatable_declare_target.f90` | Wrong result (zeros) | Use `target enter data map(to:)` instead of `target update to` |
| 3 | `bug3_nested_pointer_struct_map.f90` | Runtime abort | Ordered 3-level `target enter data` (see `bug3_workaround.f90`) |
| 4 | `bug4_allocatable_declare_target_segfault.f90` | GPU segfault | Use `target enter data map(to:)` instead of `target update to` |

---

## Status in ifx 2026.0.0

Tested with `ifx 2026.0.0 20260331` (Intel oneAPI Toolkit 2026.0.0.198), user-installed
on ACES at `/scratch/user/u.sb27915/intel/oneapi-full/`. Compiled with JIT
(`-fopenmp-targets=spir64`) since `ocloc` is not installed on the PVC compute nodes.
See `run_bugs_2026.sh` for the full test script.

| Bug | ifx 2025.1.1 | ifx 2026.0.0 | Notes |
|-----|-------------|-------------|-------|
| 1 | Wrong result (zeros) | **Hangs** | Failure mode changed — GPU kernel never returns |
| 2 | Wrong result (zeros) | **FIXED** | |
| 3 | Runtime abort | **FIXED** | |
| 4 | GPU segfault | **FIXED** | |

### AOT compilation note

AOT compilation (`-fopenmp-targets=spir64_gen`) requires `ocloc` from the Intel Graphics
Compiler, which is **not installed** on the ACES PVC nodes (confirmed May 2026). Neither
the system `ifx 2025.1.1` nor the user-installed `ifx 2026.0.0` can perform AOT on this
cluster. Use JIT (`-fopenmp-targets=spir64`) or request `intel-ocloc` from HPRC admins.

### Using ifx 2026.0.0 on ACES

Add to your SLURM job script:

```bash
source /scratch/user/u.sb27915/intel/oneapi-full/compiler/2026.0/env/vars.sh
export LD_LIBRARY_PATH="/scratch/user/u.sb27915/intel/oneapi-full/compiler/2026.0/lib:${LD_LIBRARY_PATH}"
```

Then compile with:

```bash
ifx -fiopenmp -fopenmp-targets=spir64 -O2 -o myexe myfile.f90
```
