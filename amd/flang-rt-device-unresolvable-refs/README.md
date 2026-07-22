# flang-rt: shipped amdgcn `libflang_rt.runtime.a` has 6 unresolvable references, one structurally unlowerable on AMDGPU

Target: gfx90a (MI250X, MI210). Toolchain: AFAR 23.2.1 (`therock-afar-23.2.1-gfx90a-7.13.0`),
which ships `lib/llvm/lib/clang/23/lib/amdgcn-amd-amdhsa/libflang_rt.runtime.a`.

**Status (2026-07-22): OPEN** — reported downstream as [ROCm#3517](https://github.com/ROCm/llvm-project/issues/3517).

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

## Honest limitation: no minimal reproducer

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

