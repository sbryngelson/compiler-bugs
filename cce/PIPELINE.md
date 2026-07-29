# How CCE lowers Fortran to AMD GPU code, and why it matters for these defects

Notes gathered while root-causing the CCE 21 defects in this directory. Not vendor
documentation — everything here is observed from artifacts CCE actually produces
(`extract-device-ir.sh` pulls the IR; `objdump`/`llvm-readelf` do the rest). Recorded because
several of the defects only make sense once the pipeline is understood, and because it took a
long time to work out.

## The stages

```
 Fortran source
      |
      v
 [1] CCE Fortran front end          <-- proprietary; does its OWN inlining and optimisation
      |                                 emits LLVM IR with Cray-specific metadata
      v
 [2] .cray.llvm.offloading section  <-- device IR, stored in the host .o
      |                                 wrapped in an LLVM OffloadBinary (magic 0x10FF10AD)
      v
 [3] lld + LTO (cce-clang)          <-- CCE's own LLVM 21.1.8; runs the AMDGPU pipeline
      |                                 controlled by CRAY_CCE_LLD_ARGS
      v
 AMDGPU code object (gfx90a)
```

**Stage 1 is where several defects live, and it is invisible to every LLVM-level flag.** By the
time anything reaches stage 3, decisions taken in stage 1 are already baked into the IR.

### Getting the IR out (stage 2)

`-plugin-opt=save-temps` works only when the link is driven by CMake. For a direct
`ftn -o exe file.f90` it silently produces nothing. The IR is always retrievable from the object
file, though:

```bash
ftn -hacc -c foo.f90 -o foo.o
llvm-objcopy --dump-section=.cray.llvm.offloading=off.bin foo.o
# OffloadBinary header, then bitcode at a variable offset:
python3 -c "d=open('off.bin','rb').read(); i=d.find(b'BC\xc0\xde'); open('dev.bc','wb').write(d[i:])"
llvm-dis dev.bc -o dev.ll
```

`extract-device-ir.sh` in several entries automates this. Unblocking IR-level analysis this way
is what turned four "silent wrong answers, no mechanism" entries into precise diagnoses.

## What CCE's device IR looks like

### Kernels are outlined and named by source line

```llvm
define amdgpu_kernel void @"s_driver$m_kernel_$ck_L20_1"(...)
define amdgpu_kernel void @"s_driver$m_kernel_$ck_L20_1_cce$noloop$form"(...)
```

`<routine>$<module>_$ck_L<line>_<n>` — plus a `_cce$noloop$form` variant emitted alongside the
main kernel. Basic blocks are named from source too: `"file f.f90, line 12, bb99"`, and
sometimes just `", bb71"`.

> Those block names are why [`mir-roundtrip-bb-name`](mir-roundtrip-bb-name) exists: the MIR
> printer emits them unquoted, and the embedded comma makes MIR that `llc` cannot re-parse. Filed
> upstream as [llvm#212785](https://github.com/llvm/llvm-project/issues/212785).

### Pointers are passed to kernels as `i64`, not as pointers

```llvm
define amdgpu_kernel void @"s_driver$m_kernel_$ck_L20_1"(
    i64 %"$$arg_dvmbr_p2_...",      ; dope-vector members
    i64 %"$$arg_ptr_acc_x_...",     ; the array base
    i32 %"$$_arg_acc_seat_n_...")   ; scalars by value
```

Every pointer argument arrives as an integer, and each use site materialises it independently:

```llvm
%r60 = inttoptr i64 %"$$arg_ptr_acc_x..." to ptr addrspace(1)   ; global
%r34 = inttoptr i64 %"$$arg_ptr_acc_x..." to ptr                ; generic
```

**The same argument becomes both a global and a generic pointer, in the same module.** A trivial
14-line kernel contains 6 `inttoptr`; a real MFC kernel contains 69.

> This is the enabling condition for
> [`instcombine-phi-addrspace-cast`](instcombine-phi-addrspace-cast). LLVM's
> `foldIntegerTypedPHI` exists specifically to fold PHIs whose incoming values feed `inttoptr` —
> exactly the shape this ABI produces everywhere. GVN unifies two loads of the same address, the
> PHI ends up mixing `ptr` and `ptr addrspace(1)`, and the fold builds a `bitcast` across address
> spaces. The upstream fix ([`6d033abb7`](https://github.com/llvm/llvm-project/pull/181064)) adds
> a type check before accepting a `ptrtoint` source as an available value.
>
> It is also why [`private-flat-pointer`](private-flat-pointer) happens: when the front end wants
> a flat pointer from a private one it writes `inttoptr(zext(ptrtoint p5))` rather than
> `addrspacecast`, losing the scratch aperture.

The pattern is consistent: **CCE prefers integer/pointer round-trips where clang would use typed
pointers and `addrspacecast`.** That is legal IR, but it walks into every mid-end transform that
reasons about `inttoptr` provenance.

### Cray-specific metadata

| metadata | apparent role |
| --- | --- |
| `!CrayMri` | memory-reference identity, attached to loads/stores |
| `!cray.depth` | loop nesting depth |
| `!scalarlevel`, `!cachelevel`, `!fplevel` | per-function optimisation levels |
| `!looptrips`, `!autoprefetch` | loop trip counts and prefetch hints |
| `!PDGFunctionMap` | maps a tag to each device symbol, e.g. `!{i32 4, !"s_leaf$m_kernel_"}` |

## The front end inlines before LLVM sees anything

This is the finding with the widest consequences.

Compile the same source at each optimisation level and count calls in the **pre-LTO** device IR:

| `-O` | calls to the leaf routine | leaf body copies |
| --- | --- | --- |
| 0 | **1** | 0 |
| 1 | 0 | 0 |
| 2 | 0 | 5 |
| 3 | 0 | 5 |

At `-O1` and above the leaf is already inlined *before any LLVM pass runs*. A standalone
definition is still emitted, carrying `alwaysinline`, but nothing calls it — it is a leftover.

Two consequences:

1. **`!DIR$ INLINENEVER` cannot work on device routines**, because the front end's own inliner
   discards it. See [`inlinenever-ignored-device`](inlinenever-ignored-device) — the same
   directive *is* honoured for host code in the same compilation, which is what makes it a
   defect rather than an unimplemented feature.
2. **No LLVM-level flag can restore the call.** `--always-inline`, attribute rewriting,
   `-plugin-opt` knobs — all of them operate on IR in which the inlining has already happened.
   Verified: substituting `noinline` for `alwaysinline` in the IR changes nothing, because there
   is no call site left to preserve.

This is why the InstCombine case-optimisation abort had to be worked around with a program-wide
`-plugin-opt` flag instead of a one-line source annotation. The obvious narrow fix — stop
inlining the one routine that creates the bad PHI — is unavailable by construction.

## Practical consequences

* **A source-level "don't inline this" fix is not available on CCE device code.** Budget for a
  compiler flag, or for restructuring so the problematic pattern never forms.
* **Expect `inttoptr`-related mid-end bugs.** The device ABI makes them likely. Two of the
  defects here are in that family.
* **Reproduce at IR level, not source level.** The front end's transformations mean the IR often
  looks nothing like the Fortran. Three of these entries were misdiagnosed at source level first;
  reading the actual IR settled each of them in minutes.
* **When comparing compilers, verify the pass actually ran.** `-debug-pass=Structure`: a silently
  dropped pass and a fixed bug look identical from the outside.
