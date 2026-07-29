# CCE 21: `!DIR$ INLINENEVER` on a device routine is accepted, then overridden with `alwaysinline`

> **Severity:** **Directive does not prevent device inlining** — and changes address spaces as a side effect  
> **Fix belongs to:** CCE Fortran front end  
> **Status:** Root-caused, and **twice corrected** — see 'What this entry got wrong'. The directive is *not* ignored on device: it defers inlining from `optcg` to LLVM. The routine is still fully inlined, and the resulting memory accesses change from `addrspace(1)` to generic pointers.

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
| Vendor | Filed with OLCF/HPE 2026-07-29 — case ID pending |
| Blocks | [`../instcombine-phi-addrspace-cast`](../instcombine-phi-addrspace-cast) — the source-level workaround for that abort depends on this directive working |

## Files

| file | what it is |
| --- | --- |
| `inlinenever.f90` | self-contained OpenACC reproducer, 35 lines |
| `run.sh` | compiles it and inspects the device image |
| `extract-device-image.py` | pulls the embedded AMDGPU ELF out of the host binary |

## Reproduce

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

## The pattern

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

## IR-level confirmation

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

## The documented behaviour, verbatim

From `man 7 inlinealways` shipped with CPE (`/opt/cray/pe/cce/*/man/man7/inlinealways.7`,
which `inlinenever.7` sources):

```
!DIR$ INLINEALWAYS name[, name] ...
!DIR$ INLINENEVER name[, name] ...

The inline_never directive specifies functions that should not be inlined.
If the directive is placed in the definition of the function, inlining is
never attempted at any call site to name in the entire input file being
compiled.
```

`man 7 intro_directives` further classifies `INLINEALWAYS|INLINENEVER` among directives that
"alter the status of entities" and explicitly **do not apply to particular ranges of code" —
i.e. it is an entity directive naming a procedure, not a call-site range directive.

The reproducer follows this exactly: the directive is placed **in the definition** of `s_leaf`
and names it. Documented result is "never inlined at any call site in the file"; actual result
is `alwaysinline` in the device IR and full inlining at every site.

This rules out the two obvious deflections — wrong spelling and wrong placement. The call-site
placement (directive in the caller rather than the definition) is also documented and was tested
separately with the same null result.

## Why this matters

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

## Not verified

The reproducer uses OpenACC (`!$acc routine seq`). Whether the OpenMP spelling
(`!$omp declare target`) shows the same behaviour has **not** been tested here.


## Scope correction: it works on CPU builds — the defect is device-only

An earlier reading of this entry could suggest `!DIR$ INLINENEVER` is simply broken. It is not.
On a **CPU** Cray build the directive behaves exactly as documented.

`host-cpu-control.f90` is the same leaf/driver pair with no offload directives at all:

```console
$ ftn -O2 -c host.f90        # with !DIR$ INLINENEVER
$ objdump -d host.o | grep call
   7e:  e8 ...  call  83 <s_driver$m_+0x63>      <-- real call, leaf NOT inlined

$ ftn -O2 -c host_nodir.f90  # same source, directive deleted
   (no call from s_driver -- the leaf is inlined away)
```

| build | call to the leaf emitted? |
| --- | --- |
| CPU, with `INLINENEVER` | **yes** — honoured |
| CPU, without | no — inlined, as expected |
| **GPU, device routine, with `INLINENEVER`** | **no — ignored, `alwaysinline` emitted** |

So the defect is specifically: **the directive is honoured for host code and silently discarded
for device routines.** That is a narrower and more precise claim than "the directive does not
work", and it is the one to put to the vendor — a directive that works in one compilation mode
and is silently dropped in another is harder to defend than an unimplemented feature.

It also means that in an application which compiles the same sources for both CPU and GPU, these
directives are **not dead code** — they are load-bearing on the CPU path and inert on the device
path. Removing them because they appear ineffective on GPU would silently change host codegen.


## What this entry got wrong, and the measurement that settled it

This entry has been revised twice. Both earlier readings were produced by comparing IR by eye
and stopping too early.

| revision | claim | why it was wrong |
| --- | --- | --- |
| 1 | "the directive is ignored on device" | based on the `alwaysinline` attribute being present in both arms — true, but not the whole IR |
| 2 | "device IR is semantically identical" | based on `head -24` of a diff. The output was truncated; real differences were further down |
| **3 (current)** | the directive **changes** device output — it moves inlining from `optcg` to LLVM | measured with a validated normalizer and a self-control |

### The actual measurement

Same source, with and without `!DIR$ INLINENEVER`, device path, `-O2`:

| | generic `ptr` loads | `addrspace(1)` loads | `inlinedAt` metadata | calls to the leaf |
| --- | --- | --- | --- | --- |
| **with** the directive | **8** | **0** | 3 | 0 |
| without | 4 | 4 | 0 | 0 |

Both are fully inlined — the directive does **not** achieve what it asks for. But it is not a
no-op either. With it, `optcg`'s early inliner stands down, the routine survives into LLVM IR,
and LLVM's inliner does the work later — visible as `.i` value suffixes and `inlinedAt` debug
metadata. The knock-on effect is that **every access comes out through a generic pointer**
instead of half of them being `addrspace(1)`.

### Why that matters more than the original complaint

Mixed generic / `addrspace(1)` pointers are the trigger for
[`../instcombine-phi-addrspace-cast`](../instcombine-phi-addrspace-cast). So on CCE 21 this
directive plausibly **shifts exposure to a different defect** rather than doing nothing. Anyone
reaching for `cray_noinline` to dodge an inlining-related bug on device should measure the
resulting IR, not assume the directive is inert.

### Reproducing

`../lib/efficacy/efficacy.sh INLINENEVER` runs the with/without comparison on both paths with a
self-control. It reports `differs / differs` — takes effect on both — which is what corrected
this entry. The harness README documents the three normalization bugs that made earlier runs
report the opposite.

## Verdict and exit codes

`run.sh` scores itself from the device image and prints a `VERDICT:` line:

| exit | verdict | meaning |
| --- | --- | --- |
| 0 | BUG PRESENT | no `s_leaf` device symbol **and** no call instructions, but the leaf's arithmetic is in the kernel — it was inlined. The documented state |
| 1 | FIXED | `s_leaf` survives as a callable device function (symbol + call site) — a deviation from the documented state |
| 2 | INCONCLUSIVE / PARTIAL | no arithmetic found at all (nothing built or extracted), or a symbol with no calls |

The arithmetic count is the guard against a false pass. If the device image were empty or
failed to extract, symbols and calls would both be zero — which looks exactly like the bug.
Requiring `v > 0` means a zero/zero verdict only counts when the leaf's work is demonstrably
present in the kernel body.

Measured on CCE 21.0.2:

```
rc=0                                    # directive accepted, no diagnostic
device symbols matching s_leaf: 0       # expected >=1 if honoured
call instructions: 0                    # nothing was left to call
v_ arithmetic ops in kernel: 83         # the body is here, inlined
VERDICT: BUG PRESENT (as documented)                                   # exit 0
```

The `rc=0` in step 1 is half the complaint: `ftn` neither honours `!DIR$ INLINENEVER` on a
device routine nor warns that it is dropping it. An `ftn-790 unknown directive` would at
least be actionable.

See also `host-cpu-control.f90` — the same directive **is** honoured on a host CPU build,
so this is device lowering specifically, not a directive the front end never understood.

Exit codes follow the repo-wide convention: **0 means reality matched this document**
(the defect is still present), nonzero means something changed and needs a human.
See `../README.md`.
