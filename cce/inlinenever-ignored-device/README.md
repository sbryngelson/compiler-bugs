# CCE 21: `!DIR$ INLINENEVER` on a device routine is accepted, then overridden with `alwaysinline`

**Silently ineffective directive.** A procedure carrying both a device-routine directive
(`!$acc routine seq`) and `!DIR$ INLINENEVER` is emitted into the device IR with the
**`alwaysinline`** attribute — the opposite of what was requested. The link-time inliner
then inlines it. There is no diagnostic: `ftn` accepts the directive, echoes it in the
listing, and compiles cleanly.

* **Reported by:** OLCF Frontier, project CFD154
* **Component:** CCE 21.0.2, OpenACC/OpenMP offload code generation, gfx90a
* **Severity:** no abort and no wrong answers *on its own* — but it removes the only
  documented lever for working around inlining-triggered backend bugs, and it does so
  without telling the user. See §5: it is what blocks the narrow fix for
  [`../instcombine-phi-addrspace-cast`](../instcombine-phi-addrspace-cast).
* **Version tested:** `Cray Fortran Version 21.0.2 (20260604162910_c3fb8a56d0f4e468a9d0387a93105d6911ac9420)`, ROCm 7.2.0

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | none filed |
| Blocks | [`../instcombine-phi-addrspace-cast`](../instcombine-phi-addrspace-cast) — the source-level workaround for that abort depends on this directive working |

## 1. Files

| file | what it is |
| --- | --- |
| `inlinenever.f90` | self-contained OpenACC reproducer, 35 lines |
| `run.sh` | compiles it and inspects the device image |
| `extract-device-image.py` | pulls the embedded AMDGPU ELF out of the host binary |

## 2. Reproduce

```bash
module load cpe/26.03 cce/21.0.2 rocm/7.2.0 craype-accel-amd-gfx90a
bash run.sh
```

### Actual

```
=== 1. compile: the directive is accepted, no diagnostic ===
rc=0  (0 = accepted; ftn-790 would mean 'unknown directive')
=== 3. is s_leaf a callable device function? ===
device symbols matching s_leaf: 0   (expected >=1 if INLINENEVER were honoured)
=== 4. are there any calls at all in the device image? ===
call instructions: 0   (0 = everything was inlined)
=== 5. the leaf body is present, inlined into the kernel ===
v_ arithmetic ops in kernel: 83
```

`s_leaf` does not exist as a callable device function, there is no call instruction
anywhere in the device image, and the leaf's arithmetic appears inline in the kernel.

### Expected

Either `noinline` in the device IR and an out-of-line device function, **or** a
diagnostic stating that the directive cannot be honoured for device routines.

## 3. The pattern

```fortran
subroutine s_leaf(a, b, c)
!$acc routine seq
!DIR$ INLINENEVER s_leaf
    real(8), intent(in)  :: a, b
    real(8), intent(out) :: c
    c = a*b + a/b
end subroutine
```

called from an `!$acc parallel loop`. Nothing else is required.

## 4. IR-level confirmation

From a production build (MFC), where the same directive is applied to
`s_compute_viscous_stress_tensor`. The Fypp-generated Fortran contains the directive:

```console
$ grep INLINENEVER build/staging/.../fypp/simulation/m_viscous.fpp.f90
!DIR$ INLINENEVER s_compute_viscous_stress_tensor
```

and the pre-LTO device bitcode contains the opposite:

```console
$ llvm-dis -o - build/staging/.../simulation-cce-openmp-pre-llc.bc | grep s_compute_viscous_stress_tensor
define hidden void @"s_compute_viscous_stress_tensor$m_viscous_"(...) #23
$ ... | grep '^attributes #23'
attributes #23 = { ... alwaysinline ... }
```

The caller's IR then contains blocks attributed to the callee's source file — i.e. it
was inlined.

## 5. Why this matters

If device routines must be `alwaysinline` as an implementation constraint of
`routine seq`, that is defensible — but then the directive should be **rejected with a
diagnostic**, not accepted and silently inverted.

**Measured: it is not a constraint.** The same reproducer compiled at lower
optimization levels emits real out-of-line device calls (`s_swappc_b64`), so the
offload model supports them and the compiler simply chooses to inline at `-O2`:

| variant | device calls | `v_` ops in kernel |
| --- | --- | --- |
| no directive | 0 | 83 |
| `!DIR$ INLINENEVER` | 0 | 83 |
| nameless `!DIR$ NOINLINE` at the call site | 0 | 83 |
| `-hipa0` | 0 | 58 |
| `-O2` / `-O3` | 0 | 83 |
| **`-O1`** | **3** | 57 |
| **`-O0`** | **2** | 43 |

Two conclusions. First, inlining device routines is an `-O2`-and-above decision, not a
requirement of `routine seq` — so honouring `INLINENEVER` is implementable, and the
"working as designed" reading does not hold. Second, no spelling of the directive and
no IPA setting changes anything: `INLINENEVER`, the nameless call-site `NOINLINE`, and
`-hipa0` are all bit-identical to having no directive at all. Only the optimization
level moves it, and only by disabling optimization wholesale.

Concretely, this defect converted a one-line fix into a compiler-flag workaround.
[`../instcombine-phi-addrspace-cast`](../instcombine-phi-addrspace-cast) is an abort
caused by inlining a leaf routine into a kernel, where GVN then forms a
`ptr addrspace(1)` PHI that InstCombine mishandles. The obvious narrow fix — mark that
one leaf `INLINENEVER` — was tried and had no effect, for the reason documented here.
Source restructuring was then attempted instead and did not converge (the redundancy
pattern recurs at 5 sites in one routine, 24 in the file), leaving only a program-wide
plugin flag.

In the same application this also silently disabled **51** existing `cray_noinline`
call sites, two of which were added specifically to work around earlier compiler
problems and were therefore not doing what their authors believed.

## 6. Not verified

The reproducer uses OpenACC (`!$acc routine seq`). Whether the OpenMP spelling
(`!$omp declare target`) shows the same behaviour has **not** been tested here.
