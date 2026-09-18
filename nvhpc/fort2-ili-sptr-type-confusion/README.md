# nvfortran `-mp=gpu`: fort2 indexes the ILI table with a symbol number → front-end segfault

Compiler: nvfortran 24.9 through 26.5, reduced on 25.5, verified on 25.11 and 26.5. Clean on 24.5.
Target cc80, but the crash is in host-side front-end code and no device code is reached.

**Status: ROOT-CAUSED TO ONE MISSING OPCODE CHECK. FILED 2026-09-18**.

> **Response:** I was able to reproduce your observations and opened a report with engineering. It’s number TPR#38992. When I hear back from engineering, I’ll let you know! I imagine that it’s too late in the cycle to make it into the upcoming 26.9, but perhaps the next release will have the fix in it! I’ll let you know when I know more. [see here](https://forums.developer.nvidia.com/t/nvfortran-mp-gpu-fort2-segfaults-on-a-target-teams-loop-is-alloc-indexes-the-ili-table-with-a-symbol-number-24-9-through-26-5/383574)

Present in 26.5, the newest release.

```
nvfortran-Fatal-/opt/nvidia/hpc_sdk/Linux_x86_64/25.11/compilers/bin/tools/fort2 TERMINATED by signal 11
```

fort2 dies in its own optimizer, before code generation, so there is no IR, PTX or SASS for the file
and nothing to inspect downstream. Needs `-O1` or higher **and** `-mp=gpu`; `-O0`, host `-mp` and
plain `-O3` all compile.

Found in MFC (<https://github.com/MFlowCode/MFC>), AMR ghost fill, `src/simulation/m_amr_exchange.fpp`
before commit `245b3868`. The workaround there was to split the two target regions into two routines.

## Bug

`is_alloc()`, in the HL scrubber's store-to-load forwarding pass, asks "is this statement the store of
a call to the automatic-array allocator". Disassembled:

```c
if (!(ILT_flags(ilt) & 1)) return false;          /* statement contains a call            */
ili = ILT_ILIP(ilt);
if (ILI_OPC(ili) != IL_STA)  return false;        /* 0x185 = STA, checked                 */
t = ILI_OPND(ili, 1);                             /* opcode of t is never checked  <-- bug */
u = ILI_OPND(t, 1);                               /* assumes t's operand 1 is an ILI index */
if (ILI_OPC(u) != IL_JSR)   return false;         /* 0x189 = JSR                          */
sym = ILI_OPND(u, 1);
return strcmp(SYMNAME(sym), "pgf90_auto_alloc04_i8") == 0;
```

`t` is the value operand of the store. Two opcodes reach that dereference, six times each:

| `t` | operand 1 is | result |
|---|---|---|
| `IL_DFRAR` | an ILI index — a call's result register | correct, `u` is the `JSR` |
| `IL_ACON` | a **symbol table index** | fort2 indexes a 56-byte ILI table with a symbol number |

`ILI_OPND(t, 1)` for the `ACON` is 17489. The symbol table holds 17504 live entries, and symbol 17489
is a valid `ST_CONST`; the symbol side is healthy. The ILI table has 2265 live entries at base
`0x1145dd0`, so `0x1145dd0 + 17489*56 = 0x1234f88`, ~980 KB past the base and past the end of the
heap. `si_addr` is that address.

**Fix: check `ILI_OPC(t) == IL_DFRAR` before dereferencing `t`'s operand as an ILI.**

Backtrace, identical on 25.11 and 26.5 (fort2 ships unstripped):

```
#0  ILI_OPC(int)
#1  is_alloc(int)
#2  iscall_in_path()
#3  is_call_in_path(int, int, int, int)
#4  def_ok(int, int, int, bool)
#5  forward_to_load(bool*, int, int, int, int, int, fastset*)
#6  forwarding_visitor(ILI_coordinates const*)
#7..#11 visit_ili_operands / visit_ilis
#12 forward()
#13 hlscrub_fortran_pass(int)
#14 hlscrub(int)
```

`dump_ili()` has the same defect: its operand loop calls `ILI_OPC` on every operand before consulting
the operand-type table, and faults on the same node with `rdi = 17489`.

## Where the ACON comes from

fort2's own dumper prints symbol operands with `~` and link operands with `^`:

```
ILT 438 -> ILI 2060  STA   2032^ 1759^ 19
           ILI 2032  ACON  5489~<.uplevelArgPack_4,0>
```

The statement stores the address of `.uplevelArgPack_4`, the uplevel argument pack OpenMP outlining
builds to pass host variables into the outlined region. That is why `-mp=gpu` is required: the
outliner is what emits a `STA` of an `ACON`, and `is_alloc` walks into it as though it were a call.

## The read happens whether or not it crashes

The misread value is a symbol index, so it tracks the symbol count: `4*N + 551` for `N` filler arrays
in `repro.f90`, `4*N + 1489` in the original two-file reduction. Four symbols per
`integer, allocatable :: vN(:)`.

A breakpoint on the read in a build that **compiles cleanly** fires six times with an index outside
the ILI table. The filler size only decides whether the resulting address is mapped:

| filler entries | `ACON` sptr | value read where `IL_JSR` (393) was expected |
|---|---|---|
| 200, 600, 2800 | | 0 |
| 1000 | 5489 | 1016544 |
| 1600 | 7889 | 1145390455 |

None matched 393 ⇒ `is_alloc` returned false ⇒ the call stayed a barrier, conservative by accident.
In `iscall_in_path` the result is inverted (`xor $1`): a call-carrying statement is a barrier *unless*
`is_alloc` calls it a `pgf90_auto_alloc04_i8` call, which is excused. So a wrongly-true `is_alloc`
would drop a barrier and let `forward_to_load` forward a store across a real call — a miscompile.
A match would then need a second out-of-range read to survive a `strcmp` on a symbol name, which
would fault first. The realistic failure mode is the segfault, not bad code, but the read is
undefined behaviour either way.

This is the whole of the "perturbation sensitivity" seen while reducing on 25.5 at 1000 entries,
where the index sat on the edge of the heap: dropping either target region, the `collapse(2)` or the
`bind(teams,parallel)` clauses compiled, as did adding or removing almost any declaration, as did
renaming the file — 10 characters compiled, 11 or more crashed. All of them shift symbol numbering or
heap layout. None of them matter once the filler is well past the boundary.

Mapped-or-not is not monotonic in `N` and not deterministic run to run. Declaring the filler directly
in the program instead of in a module moves fort2's ILI table from the brk heap into an mmap'd block,
its neighbourhood then moves with ASLR, and the reproducer becomes a coin flip — 8/10, 9/10, 19/20
over repeated runs of a byte-identical file. With the module, in the same file, it is 20/20.
**Do not fold `m_big` into the program.**

## What is required

Reduced against a 12000-entry filler, far enough from the boundary that the answers are not layout
luck. Irrelevant: the second target region, `collapse(2)`, `bind(teams,parallel)`, the derived types,
the `pure` procedures, the dummy arguments, the loop body.

- **`target teams loop` specifically.** `target teams distribute parallel do` does not crash. A plain
  `target` region does not crash.
- **The `use`.** It is what pulls the filler symbols into the compilation.
- An empty loop body is enough; the outliner still builds the arg pack and stores its address.

## OpenACC is unaffected

Not layout luck — the dereference is never performed. `is_alloc` instrumented on the original
reproducer, once with its OpenMP directives and once translated to OpenACC (`parallel loop`,
`declare create`, `update device`):

| | `is_alloc` entered | passed call-flag check | passed `IL_STA` check ⇒ bad deref |
|---|---|---|---|
| `-mp=gpu` | 63 | 63 | **4** ⇒ segfault |
| `-acc=gpu` | 110 | 110 | **0** |

The pass runs harder under OpenACC — 110 call-carrying statements examined against 63, and 1718
`forward_to_load` calls — but none of those statements is a `STA`, so every call returns at the
`IL_STA` test. `!$acc parallel loop`, `!$acc kernels` and `!$acc parallel` on the minimal shape all
compile and do not reach `is_alloc` at all.

This scopes the defect to the OpenMP offload path as it stands. It does not prove OpenACC cannot build
a `STA` over an `ACON`; the buggy pass is generic ILI code, and any front end producing that shape
would hit it.

## Versions

| NVHPC | result |
|---|---|
| 24.5 | clean at every filler size tried, up to 8000. Its fort2 has no `is_alloc`, `forward_to_load`, `forwarding_visitor` or `hlscrub_fortran_pass` — the pass does not exist yet |
| 24.9 – 26.3 | reproduced in MFC CI |
| 25.5 | original reduction; 1000 filler entries sufficed |
| 25.11 | 20/20 |
| 26.5 | 20/20; `is_alloc` carries the identical unguarded sequence |

## Tracking

| Where | Link / ID |
|-------|-----------|
| Vendor | [NVIDIA developer forums](https://forums.developer.nvidia.com/t/nvfortran-mp-gpu-fort2-segfaults-on-a-target-teams-loop-is-alloc-indexes-the-ili-table-with-a-symbol-number-24-9-through-26-5/383574), posted 2026-09-18; TPR#38992 |
| MFC | workaround in `m_amr_exchange.fpp`, commit `245b3868` |

## Files

| file | what it is |
| --- | --- |
| `repro.f90` | The reproducer. One file: 336 lines of unreferenced filler and an 8-line program. |
| `repro.sh` | Compiles it, then the three controls that must all succeed. |

## Reproduce

```
./repro.sh
```

20/20 on 25.11 and 26.5. The client is the whole of it:

```fortran
program p
    use m_big, only: flag
    implicit none
    integer :: i
!$omp target teams loop
    do i = 1, 10
    end do
end program p
```

## Re-deriving this

fort2 runs standalone under gdb, which is where the backtraces and operand dumps came from. The driver
deletes its temporaries, so capture the pipeline first:

```
nvfortran -v -O3 -mp=gpu -c repro.f90 -o repro.o > v.txt 2>&1
```

then rewrite the `/tmp/nvfortran*.{ilm,stb,cci,cmod,inl,ll}` paths in the `fort1` and `fort2` command
lines to fixed paths, run the `fort1` line to regenerate the `.ilm`, and run the `fort2` line under
gdb. Useful symbols: `ilib` (ILI table descriptor; 56-byte entries, `opc` at +0, operand *n* at
+20+4(*n*-1)), `stb+0x9fb0` (symbol table base, 152-byte entries), `ilis` (opcode info, 32-byte
stride, name pointer first), `getprint(int)`, `dump_ili(FILE*, int)`.
