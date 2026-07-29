# CCE 21: InstCombine builds a bitcast between address spaces and asserts

**Compiler abort.** `InstCombine`'s `foldIntegerTypedPHI` reaches a PHI whose incoming
values trace back, through `ptrtoint`/`inttoptr`, to pointers in **two different address
spaces**. It then emits a `bitcast` between them — which is not valid IR, a cast across
address spaces requires `addrspacecast` — and trips an assertion:

```
opt: llvm/lib/IR/Instructions.cpp:3040: static llvm::CastInst*
     llvm::CastInst::Create(llvm::Instruction::CastOps, llvm::Value*, llvm::Type*,
     const llvm::Twine&, llvm::InsertPosition):
     Assertion `castIsValid(op, S, Ty) && "Invalid cast!"' failed.
```

* **Reported by:** OLCF Frontier, project CFD154
* **Component:** CCE 21.0.2, `lld` / LTO device pipeline, gfx90a
* **Severity:** abort — loud, no wrong answers
* **Version tested:** `Cray LLVM 21.0.2 (c3fb8a56d0f4e468a9d0387a93105d6911ac9420) based on LLVM version 21.1.8`

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | Filed with OLCF/HPE 2026-07-29 — case ID pending |
| Related | [`../private-flat-pointer`](../private-flat-pointer) — same mixed-address-space family |

## 1. Files

| file | what it is |
| --- | --- |
| `phi-addrspace.ll` | The reproducer. 25 lines, one function. |
| `run.sh` | Runs the crash, the partial workaround, and the version triage. |

## 2. Reproduce

```bash
/opt/cray/pe/cce/21.0.2/cce-clang/x86_64/bin/opt -passes=instcombine phi-addrspace.ll -o /dev/null
```

One pass, one function, no application and no build system involved.

### Actual

```
2.  Running pass "instcombine<max-iterations=1;verify-fixpoint>" on function "kernel"
    Assertion `castIsValid(op, S, Ty) && "Invalid cast!"' failed.
```

### The pattern

```llvm
%i    = ptrtoint ptr %flat to i64                ; flat, addrspace 0
%as1  = inttoptr i64 %i to ptr addrspace(1)      ; global, addrspace 1
...
%p    = phi ptr addrspace(1) [ %global, %crit_edge ], [ %as1, %cast ]
%pi   = ptrtoint ptr addrspace(1) %p to i64
%pf   = inttoptr i64 %pi to ptr
```

`p0` and `p1` are both 64-bit in this data layout, so the size check passes and
`CreateBitOrPointerCast` chooses `bitcast` — but the address spaces differ, so
`castIsValid` rejects it.

The empty critical-edge block is load-bearing. Branching to `%join` directly from
`%entry` does **not** reproduce, which is worth knowing before simplifying further.

## 3. Version triage

| LLVM | source | result |
| --- | --- | --- |
| 18.0.0 | ROCm 6.3.1 | clean |
| **21.1.8** | **CCE 21.0.2** | **assert** |
| 22.0.0 | ROCm 7.2.0 | clean |

Both neighbours are AMD forks rather than pristine upstream, so this is evidence
rather than proof — but it points at a fix landing upstream between 21 and 22 that
CCE 21.0.2 predates.

## 4. Workaround — partial, and known to be incomplete

`-plugin-opt=-instcombine-max-num-phis=0` ("Maximum number phis to handle in
intptr/ptrint folding") clears the crash on the real application kernel, but
**does not fix the defect**:

| | no flag | `-instcombine-max-num-phis=0` |
| --- | --- | --- |
| this 25-line reproducer | assert | **still asserts** |
| the application kernel it was found in | assert | clean |

So the flag perturbs the multi-PHI walk enough to miss one instance; it does not
disable the faulty fold. Recorded because the obvious reading of the flag name —
"this turns the broken transform off" — is wrong, and acting on it would leave a
latent abort with no diagnostic.

## 5. How it was found

MFC (<https://github.com/MFlowCode/MFC>) hit this linking `simulation` under
`--case-optimization` on Frontier. Only case-optimized builds reach it: baking the
case constants into the binary changes inlining and unrolling enough to form the
PHI. Every other GPU configuration passed its full 627-test suite, so the defect
sat behind a green test matrix.

The reduction path, for anyone doing this again: the CCE link line already passes
`-plugin-opt=save-temps`, so the pre-LTO bitcode is on disk. `llvm-extract` the one
named function out of it, replay the exact pass pipeline from the crash dump with
`opt`, then `llvm-reduce`. CCE ships matching `opt`, `llvm-extract`, `llvm-dis` and
`llvm-reduce` under `cce-clang/x86_64/bin`, which is what makes this work — the ROCm
tools are different LLVM versions and do not reproduce it.

One trap: key the `llvm-reduce` interestingness test on the assertion text, not on a
symbolized stack frame. `foldIntegerTypedPHI` does not always resolve in the dump, so
a test that greps for it rejects the unreduced input as "not interesting".

## 6. Where the PHI comes from — GVN PRE — and the O1/O2 boundary

Independent reduction from the same application, arriving at the same defect from the
module level rather than the function level. Two facts that the minimal `.ll` cannot
show, because they are about *how the input IR is produced*:

**The PHI is created by GVN's partial-redundancy elimination.** Dumping the IR
immediately before the crashing pass shows the offending value with GVN's `.pre`
suffix:

```console
$ opt -mcpu=gfx90a -mattr=-mai-insts -passes='lto<O2>' \
      -print-before=instcombine -filter-print-funcs='s_compute_ib_forces$m_ibm_$ck_L1008_11' \
      simulation-cce-openmp-pre-llc.bc -o /dev/null
...
%r929 = phi ptr addrspace(1) [ %308, %"...m_viscous.fpp, line 1287, bb30.i" ],
                             [ %308, %", bb46.i" ],
                             [ %r929.pre, %"ipa_lb..." ]
```

The incoming blocks are attributed to the *callee* source file, so this is
post-inlining: the leaf is inlined into the kernel, GVN then hoists a redundant
global-pointer load across the `if (any_non_newtonian)` merge, and the resulting
`ptr addrspace(1)` PHI is what the fold mishandles.

**The pipeline boundary corroborates it.** Replaying the LTO pipeline at each level
on the unreduced module:

| pipeline | result |
| --- | --- |
| `lto<O0>` | clean |
| `lto<O1>` | clean |
| **`lto<O2>`** | **assert** |

GVN is an O2-only addition, which is consistent with it being the producer.

**Ruled out** — each still asserts, so none of these is the mechanism, and none is a
usable workaround:

| flag | result |
| --- | --- |
| `-vectorize-slp=false` | still asserts |
| `-vectorize-loops=false` | still asserts |
| `-disable-promote-alloca-to-vector` | still asserts |

That last row matters for this application specifically: the shipped Frontier
configuration already carries `-disable-promote-alloca-to-vector` and
`-mattr=-mai-insts` for two unrelated defects, and the crash line in the build log
shows both present. This is a third, independent bug.

**Consequence for §4.** `-plugin-opt=O1` is a second workaround with the opposite
trade to `-instcombine-max-num-phis=0`: it is not partial — removing GVN removes the
producer, so no kernel can reach the fold — but it drops the whole device LTO
pipeline rather than one fold's walk limit. Neither has a measured performance
number yet. The narrow flag with a filed vendor bug is the better default; O1 is the
fallback if another kernel turns up that the narrow flag misses.

**Why the source-level fix is unavailable here.** The natural narrow fix — mark the
inlined leaf `!DIR$ INLINENEVER` so the PHI never forms — does not work: CCE 21
accepts the directive and then emits the routine with `alwaysinline` anyway. See
`cce/inlinenever-ignored-device` (MFC-side copy: `cce21-bugs/14-...`). That defect is
what forces a flag-based workaround for this one.

## 7. Root cause: CCE materialises the same device global in two address spaces

The two address spaces do not come from the application. **CCE emits two different load
forms for the same device global within a single function**, and GVN then legitimately
unifies them.

Both of these appear in one function, for the same symbol:

```llvm
; generic form — addrspacecast to flat, later laundered back with ptrtoint/inttoptr
%r144.i   = load ptr,              ptr addrspacecast (ptr addrspace(1) @fd_coeff_z__cray_acc to ptr), align 8

; global form — loaded directly in addrspace(1)
%r929.pre = load ptr addrspace(1), ptr addrspace(1) @fd_coeff_z__cray_acc, align 32
```

It is not isolated to one symbol. Counting both forms per module array in the same
function:

| global | `addrspacecast`-to-generic loads | direct `addrspace(1)` loads |
| --- | --- | --- |
| `fd_coeff_x` | 8 | 5 |
| `fd_coeff_y` | 8 | 5 |
| `fd_coeff_z` | 8 | 6 |

The generic-form value is then round-tripped back to global:

```llvm
%307 = ptrtoint ptr %r144.i to i64
%308 = inttoptr i64 %307 to ptr addrspace(1)
```

There are 69 such `inttoptr` in this one function.

**The chain.** Same address, two types → GVN unifies the loads and builds a PHI whose
incoming values are `ptr` and `ptr addrspace(1)` → `foldIntegerTypedPHI` (which exists
precisely to fold PHIs feeding `inttoptr`) tries to reconcile them → `bitcast` across
address spaces → assert.

This makes the defect a **front-end inconsistency feeding a mid-end fold**, not an
application pattern. Using `addrspacecast` rather than `inttoptr(ptrtoint(...))` for the
conversion, or emitting one consistent load form per global, would each break the chain.
Compare [LLVM #33896](https://github.com/llvm/llvm-project/issues/33896) — "InstCombine
cannot blindly assume `inttoptr(ptrtoint x) -> x`".

### Why this matters for triage

**There is no source-level workaround, and this is why.** Three were tried in the
application and all failed, consistently with the above:

| attempt | outcome |
| --- | --- |
| `!DIR$ INLINENEVER` on the inlined leaf | no effect — see [`../inlinenever-ignored-device`](../inlinenever-ignored-device) |
| hoist the duplicated load out of the branch | crash moves to the next of 5 equivalent sites in the routine |
| change the routine's interface to avoid derived-type pointer components | **hypothesis refuted** — the pointer is `fd_coeff_z` itself, not a `%sf` component |

No Fortran construct selects which load form the front end emits for a module array, so
no source change removes the mixed-address-space PHI. That leaves the plugin flags in §4
until this is fixed in the compiler.
