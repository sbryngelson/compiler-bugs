# Forum post — ready to paste

Post to **nvc, nvc++ and nvfortran**:
<https://forums.developer.nvidia.com/c/accelerated-computing/hpc-compilers/nvc-nvc-and-nvfortran/313>

Self-contained: the reproducer generates itself from the snippet, so no attachment or repo
access is needed. Record the TPR number in `README.md` once they assign one.

---

**Subject:** nvfortran `-mp=gpu`: fort2 segfaults on a `target teams loop` — `is_alloc()` indexes the ILI table with a symbol number (24.9 through 26.5)

## Summary

`nvfortran -O3 -mp=gpu` on a file with one `!$omp target teams loop` region kills fort2:

```
nvfortran-Fatal-/opt/nvidia/hpc_sdk/Linux_x86_64/25.11/compilers/bin/tools/fort2 TERMINATED by signal 11
```

Needs `-O1` or above **and** `-mp=gpu`. `-O0`, host `-mp`, and plain `-O3` all compile. OpenACC is
unaffected. First seen in our CI on 24.9; still there in 26.5. 24.5 is clean.

fort2 ships unstripped, so I was able to take this further than a crash report. The fault is in
`is_alloc()`, which walks the value operand of a store as if it were an ILI reference when it is a
symbol table index. Details below — I think it is a one-line fix.

## Environment

```
Compiler    nvfortran 25.11-0 and 26.5-0, both reproduce
            nvfortran 24.5-1 does not reproduce
Target      -tp icelake-server, cudacap 80, CUDA 13.0
OS          Linux 6.8.0 (Ubuntu), x86-64
Build       nvfortran -O3 -mp=gpu -c bug.f90
```

## Reproducer

Generate it, then compile:

```bash
python3 - > bug.f90 <<'EOF'
n = 8000
names = ["v%d(:)" % i for i in range(n)]
decl = "\n".join("    integer, allocatable :: " + ", ".join(names[i:i+25]) for i in range(0, n, 25))
print("module m_big\n    implicit none\n    logical :: flag = .false.\n" + decl + "\nend module m_big\n")
print("program p\n    use m_big, only: flag\n    implicit none\n    integer :: i\n!$omp target teams loop\n    do i = 1, 10\n    end do\nend program p")
EOF

nvfortran -O3 -mp=gpu -c bug.f90
```

The client is all of it:

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

`m_big` is 8000 unreferenced `integer, allocatable :: vN(:)` declarations. They are not incidental;
see "Why the filler is there" below before trying to cut them.

20 crashes out of 20 runs on 25.11 and on 26.5.

## Root cause

Backtrace, identical on both versions:

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

`is_alloc()` disassembles to:

```c
if (!(ILT_flags(ilt) & 1)) return false;
ili = ILT_ILIP(ilt);
if (ILI_OPC(ili) != IL_STA)  return false;   /* checked                               */
t = ILI_OPND(ili, 1);                        /* opcode of t is never checked           */
u = ILI_OPND(t, 1);                          /* assumes t's operand 1 is an ILI index  */
if (ILI_OPC(u) != IL_JSR)   return false;
sym = ILI_OPND(u, 1);
return strcmp(SYMNAME(sym), "pgf90_auto_alloc04_i8") == 0;
```

Two opcodes reach that dereference in this compile, six times each:

| `t` | its operand 1 | |
|---|---|---|
| `IL_DFRAR` | an ILI index, a call's result register | intended, `u` is the `JSR` |
| `IL_ACON` | a **symbol table index** | fort2 indexes the ILI table with a symbol number |

Your own `dump_ili()` prints symbol operands with `~` and link operands with `^`, which shows what
the `ACON` is:

```
ILT 438 -> ILI 2060  STA   2032^ 1759^ 19
           ILI 2032  ACON  5489~<.uplevelArgPack_4,0>
```

The statement stores the address of `.uplevelArgPack_4`, the uplevel argument pack the OpenMP
outliner builds for the target region. That is why `-mp=gpu` is required to see this.

At the fault, `ILI_OPND(t, 1)` is 17489. The symbol table holds 17504 live entries and symbol 17489
is a valid `ST_CONST`, so the symbol side is fine. The ILI table has 2265 live entries at base
`0x1145dd0` with 56-byte entries, so the access is `0x1145dd0 + 17489*56 = 0x1234f88`, roughly
980 KB past the base and past the end of the heap. `si_addr` is that address.

**Suggested fix:** check `ILI_OPC(t) == IL_DFRAR` before dereferencing `t`'s operand as an ILI.

`dump_ili()` has the same defect — its operand loop calls `ILI_OPC` on every operand before
consulting the operand-type table, and faults on the same node with `rdi = 17489`.

## Why the filler is there

This is the part that will waste your time if I do not spell it out. **The out-of-bounds read happens
on every affected compile, including the ones that succeed.** A breakpoint on the read in a build
that compiles cleanly fires six times with an index outside the ILI table. Whether you get a segfault
depends only on whether that address happens to be mapped.

The misread value is a symbol index, so it tracks the symbol count: `4*N + 551` for `N` filler
arrays, four symbols per allocatable. 8000 arrays put it far enough out to fault reliably. With a
smaller module the same bad read lands inside the heap and the compile "succeeds" on garbage:

| filler entries | sptr read as an ILI index | value returned where `IL_JSR` (393) was expected |
|---|---|---|
| 200, 600, 2800 | | 0 |
| 1000 | 5489 | 1016544 |
| 1600 | 7889 | 1145390455 |

Two consequences for reproducing it on your side:

1. Do not reduce the filler. Whether it crashes is not monotonic in the module size, and near the
   boundary it is not even deterministic run to run — heap layout moves with ASLR. Editing the file
   at all, comments included, can shift it.
2. Keep `m_big` a module. Declaring the same arrays directly in the program moves fort2's ILI table
   from the brk heap into an mmap'd block, and the reproducer degrades to roughly 8/10.

None of the OpenMP shape matters, which is why our original reduction looked so arbitrary. Reduced
against a 12000-entry filler: the `collapse(2)`, the `bind(teams,parallel)`, a second target region,
derived types, dummy arguments and the loop body are all irrelevant. What matters is `target teams
loop` specifically — `target teams distribute parallel do` does not crash, and neither does a plain
`target` region.

## OpenACC is not affected

Not luck about the address — the dereference never runs. Instrumenting `is_alloc` on our original
reproducer, once with OpenMP directives and once translated to OpenACC (`parallel loop`,
`declare create`, `update device`):

| | `is_alloc` entered | passed the call-flag check | passed the `IL_STA` check, i.e. did the deref |
|---|---|---|---|
| `-mp=gpu` | 63 | 63 | 4, then segfault |
| `-acc=gpu` | 110 | 110 | 0 |

The pass runs harder under OpenACC — more call-carrying statements examined, not fewer — but none is
a `STA`, so every call returns at the `IL_STA` test.

## Versions

| NVHPC | |
|---|---|
| 24.5 | clean at every filler size tried, up to 8000. Its fort2 has no `is_alloc`, `forward_to_load`, `forwarding_visitor` or `hlscrub_fortran_pass`, so the pass postdates it |
| 24.9 – 26.3 | reproduced in our CI |
| 25.11, 26.5 | 20/20 here |

## Where this came from

MFC (<https://github.com/MFlowCode/MFC>), a CFD solver, in the AMR ghost-fill routine. We worked
around it by splitting the two target regions into two routines, but the workaround is only moving
the symbol numbering, so I would not trust it to hold.
