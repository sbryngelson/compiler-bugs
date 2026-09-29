# flang-rt: shipped amdgcn `libflang_rt.runtime.a` has 6 unresolvable references, one structurally unlowerable on AMDGPU

Target: gfx90a (MI250X, MI210). Toolchain: AFAR 23.2.1 (`therock-afar-23.2.1-gfx90a-7.13.0`),
which ships `lib/llvm/lib/clang/23/lib/amdgcn-amd-amdhsa/libflang_rt.runtime.a`.

**Status: FIXED UPSTREAM, not in any AFAR drop.** Reported downstream as
[ROCm#3517](https://github.com/ROCm/llvm-project/issues/3517) (2026-07-22). Upstream fix
[llvm#226307](https://github.com/llvm/llvm-project/pull/226307), approved by @jhuber6 and merged
2026-09-29 as `6cd0f021ec73` (a second, empty commit `5274c3a05177` with the same title landed on
top from a retried merge request; it changes nothing). **AFAR 24.3.0 does not carry it and is worse
than 23.2.1**: the default `-O3` build no longer hides the problem, so MFC `simulation` fails to link
out of the box. Patch for existing drops:
[gist](https://gist.github.com/sbryngelson/6d60c1f8edd9d8da6091ae19ee85b18b).

## AFAR 24.3.0 (checked 2026-09-24 to 2026-09-29)

24.3.0's amdgcn archive has the same unresolvable references (`llvm-nm` on
`lib/llvm/lib/clang/24/lib/amdgcn-amd-amdhsa/libflang_rt.runtime.a`: 76 unresolved in total, the same
`DescriptorIoTicket`/`DerivedIoTicket` methods and `flang_rt_verbose_abort` among them). What changed
is that the compiler now reaches them from ordinary code at `-O3`: ALLOCATE of a derived type with
default initialization inside device code goes through `_FortranAAllocatableAllocate` ->
`Initialize` -> the work queue. That gives the minimal reproducer this case lacked (`repro.f90`,
`make run`):

| toolchain | result |
|---|---|
| AFAR 23.2.1 | links, prints `4.` |
| AFAR 24.3.0, stock runtime | 7 `undefined symbol` errors at device link (checked at `-O2` and `--lto-O0`; MFC fails the same way at its default `-O3`) |
| AFAR 24.3.0, patched runtime | links and prints `4.` with the device link at `--lto-O3`, `--lto-O2`, `--lto-O1` and `--lto-O0` |

Control for the last row: the stock runtime at `--lto-O0` fails with `flang_rt_verbose_abort`
undefined, so the variadic call is in the link at that level, and with the patched runtime it
lowers and runs. The codegen error described below (`unsupported call to variadic function`) was
observed on 23.2.1 with C stubs and has not been re-checked there.

**The fix.** The tickets live in `descriptor-io.cpp`, which isn't in `gpu_sources`, but the work
queue still names them. The CUDA PTX library already avoided this with a thin I/O mode
(`RT_CUDA_THIN_IO`). llvm#226307 renames it `RT_THIN_IO`, defines it in `flang/Common/api-attrs.h`
for the native GPU builds (`RT_GPU_TARGET && !defined(RT_DEVICE_COMPILATION)`), keeps the CMake
define for the CUDA PTX library (the regular CUDA library still builds `descriptor-io.cpp` on the
device; llvm#200063 made that split deliberately), and adds `stl-overrides.cpp`, which defines
`flang_rt_verbose_abort`, to `gpu_sources`. On amdgcn the archive gains only that one definition and
loses none; the host archive's symbols are unchanged. Device descriptor/derived-type I/O now stops
with a runtime error instead of failing to link; scalar device `PRINT` is unchanged.

**Patching a drop.** The gist's `patch-afar-flangrt.sh` reads the source commit from
`amdflang --version`, sparse-fetches ROCm/llvm-project at that commit, applies the patch, builds the
amdgcn flang-rt with the drop's own clang (about a minute), and installs it, keeping the original as
`libflang_rt.runtime.a.orig`. With it plus MFC [#1920](https://github.com/MFlowCode/MFC/pull/1920)
(for [flang-absent-optional-map](../flang-absent-optional-map)), MFC's full suite passes on 24.3.0:
723 passed, 0 failed, MI210.

## Bug

The shipped **device** Fortran runtime archive contains references it never defines:

| symbol | undefined | defined |
|---|---|---|
| `Fortran::runtime::io::descr::{Descriptor,Derived}IoTicket<...>::{Begin,Continue}` | **4** | 0 |
| `flang_rt_verbose_abort` — mangled `_Z22flang_rt_verbose_abortPKcz`, i.e. `(const char*, ...)`, **variadic** | **2** | 0 |

Reachability, straight out of the archive:

```
assign.cpp.o   (_FortranAAssign, _FortranACopyInAssign, _FortranACopyOutAssign, ...)
   -> WorkQueue
      -> work-queue.cpp.o   (references the variadic flang_rt_verbose_abort)
```

So the whole chain hangs off ordinary Fortran **array assignment** and **non-contiguous actual
arguments** (copy-in/copy-out) inside `!$omp target` regions.

The two defects fail differently, and the second is the serious one:

1. The undefined `DescriptorIoTicket` symbols are an internal inconsistency — providing them fixes it.
2. `flang_rt_verbose_abort` is **variadic, and AMDGPU cannot lower variadic calls at all**. Defining
   the symbol does not help; the link then fails in codegen instead:

```
ld.lld: error: <unknown>:0:0: in function _ZNSt3__126__throw_bad_variant_accessB9nqn230000Ev void ():
        unsupported call to variadic function _Z22flang_rt_verbose_abortPKcz
```

(verified by supplying trap-stub definitions for all 6 symbols — the undefined-symbol errors go
away and this codegen error replaces them.)

## Consequence: device Fortran is linkable only at `-O3`

Both problems are invisible at `-O3` because full-LTO DCE deletes the unreachable paths before
symbol resolution and before codegen. Lower the optimization and they surface. On a real
application (MFC, 6.4 MB of device bitcode, 70 TUs):

| device link | result |
|---|---|
| default (`-O3`, full LTO) | links |
| `--lto-O1` | **6 undefined symbols** |
| `--lto-O0` | **6 undefined symbols** |
| `--lto-O1` + stub definitions | **`unsupported call to variadic function`** |
| `--lto-O0` + stub definitions | **`unsupported call to variadic function`** |

So reduced-optimization AMD GPU Fortran builds are impossible whenever device code reaches the
assign path. Downstream this forces build systems to hardcode `-O3` for the offload path and ignore
the build type: MFC's `cmake/MFCTargets.cmake` compiles device code at `-O3` unconditionally, and a
`--debug`/`--reldebug` GPU build consequently costs exactly the same link time as release.

Correct linking depending on an optimization pass having run is fragile independently of the
performance consequences.

## Verifying

`verify.sh` reads the shipped archive directly — no GPU, no build, no reproducer:

```
./verify.sh /path/to/amdgcn-amd-amdhsa/libflang_rt.runtime.a [llvm-nm]
```

Output on AFAR 23.2.1:

```
  DescriptorIoTicket     undefined=4  defined=0
  flang_rt_verbose_abort undefined=2  defined=0   (=> (const char*, ...) => VARIADIC)
  members referencing flang_rt_verbose_abort:
    edit-output.cpp.o
    work-queue.cpp.o
  members pulling WorkQueue (and their _Fortran* entry points):
    assign.cpp.o -> _FortranAAssign _FortranAAssignExplicitLengthCharacter
                    _FortranAAssignPolymorphic _FortranAAssignTemporary
                    _FortranACopyInAssign _FortranACopyOutAssign
```

Use a `llvm-nm` at least as new as the archive's producer — ROCm 7.2.0's `llvm-nm` (LLVM 22) cannot
read AFAR's LLVM-23 bitcode and silently reports **zero** symbols
(`Unknown attribute kind (105)`), which looks like a clean archive.

## Honest limitation: no minimal reproducer (23.2.1)

Superseded on 24.3.0, where `repro.f90` fails at the default optimization level; see above. The
23.2.1 notes are kept as they were.

The static defect is exact and verifiable from the archive, but we could **not** reduce the *dynamic*
failure. Five candidate reproducers all link cleanly at `--lto-O1` on gfx90a: a trivial
`target teams distribute parallel do`; assumed-shape (descriptor) dummies with `NORM2`, whole-array
assignment and an array constructor; a derived-type assignment; a strided section passed to a
contiguous explicit-shape dummy (this one does pull `_FortranACopyOutAssign`); and a derived type with
an allocatable component. At small scale DCE removes the path even at `-O1`. The failure was observed
only at application scale.

The archive contents stand on their own regardless — the 6 unresolvable references and the variadic
call are properties of the shipped binary, not of any particular program.

## Related

Stock **ROCm 7.2.0 ships no `amdgcn-amd-amdhsa` flang_rt archive at all**, so `_FortranAAssign` is
simply unlinkable there — see `amd/flang-firstprivate-array-occupancy/`
([ROCm#2909](https://github.com/ROCm/llvm-project/issues/2909),
[llvm#203890](https://github.com/llvm/llvm-project/issues/203890)). This report covers the opposite
case: AFAR *does* ship the archive, and what it ships cannot be linked below `-O3`.

## Related: what reaches this chain

[`amd/flang-firstprivate-array-occupancy`](../flang-firstprivate-array-occupancy)
([llvm#203890](https://github.com/llvm/llvm-project/issues/203890),
[ROCm#2909](https://github.com/ROCm/llvm-project/issues/2909)) is one concrete way ordinary Fortran
lands on `_FortranAAssign` inside a `target` region: `firstprivate` of a fixed-size array is boxed by
the privatizer and its copy-in lowers to the runtime assign. On stock ROCm 7.2.0 and upstream flang
that is an undefined-symbol link error; on AFAR, where the archive exists, it costs ~35 KB/lane.

