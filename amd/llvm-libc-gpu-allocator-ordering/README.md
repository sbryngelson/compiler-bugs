# LLVM libc GPU allocator: `free` has no release ordering, so `malloc` can return memory another thread overwrites (MI300A)

Target: gfx942 (MI300A, six XCCs, one L2 each). Toolchain: AFAR 24.3.0
(`therock-afar-24.3.0-multiarch-10.1.0-592954c`, ROCm/llvm-project `3ba19712e9fb`) and llvm-project
`main` at `fc16f151a697` (2026-11-02), libc built for `amdgcn-amd-amdhsa` and linked into the program with
`-Xoffload-linker <build>/libc/lib/libc.a`.

**Status: open.** Upstream [llvm#238205](https://github.com/llvm/llvm-project/issues/238205), fix
proposed in [llvm#238208](https://github.com/llvm/llvm-project/pull/238208); downstream
[ROCm#5228](https://github.com/ROCm/llvm-project/issues/5228) asks for the fix in `amd-staging` and the next
AFAR drop.

## Bug

`Slab::deallocate` in `libc/src/__support/GPU/allocator.cpp` clears the chunk's bit with a relaxed
`fetch_and`, and `Slab::allocate` claims it with a relaxed `fetch_or`. The release fence in
`GuardPtr::unlock` runs after the clear, so the freeing thread's stores to the chunk are not ordered before
the chunk can be claimed again. On MI300A a thread on another XCC can take the chunk, and the previous
owner's dirty L2 lines are then written back over the new data. Commit `e9350dc` had removed the
equivalent fences. In AFAR's OpenMP device code `malloc`/`free` (and `omp_alloc`) are this allocator.

It was found through a Fortran kernel containing `loc = [i, j, k]`: flang lowers the array constructor to a
heap temporary (`fir.allocmem`, a device `malloc`/`free`), and `loc` received other threads' values.
`repro.f90` is that program ([MFC](https://github.com/MFlowCode/MFC) has the same statement shape in
`m_ibm`); `repro.c` is the same defect in C.

## Results

MI300A, `HSA_XNACK=1`, new process per launch, 10 launches each.

| libc | `repro.c`, launches with `bad > 0` | `repro.f90`, launches with damaged records |
|---|---|---|
| AFAR 24.3.0 as shipped | 10 of 10 (665–1858 records) | 9 of 10 |
| AFAR's libc source rebuilt, unmodified | 10 of 10 | 9 of 10 |
| `main`, unpatched | 10 of 10 (815–1965 records) | 5 of 5 (separate run) |
| `main` + release fence before the `fetch_and` | 0 of 10 | 0 of 5 |
| `main` + `allocator-release-acquire.patch` | 0 of 10 | 0 of 5 |
| AFAR source + the same patch | 0 of 10 | 0 of 10 |

Other observations:

- It needs allocating threads on more than one XCC. Confined to one XCC (a mask on
  `s_getreg_b32 hwreg(HW_REG_XCC_ID)`), 280M allocations over 14 launches gave 0 damaged records; two XCCs
  damaged some launches; three or more damaged nearly every launch.
- Of single instructions put before `free`, only `buffer_wbl2 sc1` (L2 write-back) cures it;
  `s_waitcnt vmcnt(0)` alone, a compiler barrier and a workgroup-scope fence do not. A device-scope release
  fence does.
- HIP's device `malloc` (the ROCm allocator) does not show it. The Fortran program was clean on MI250X
  (one XCC per GCD; XNACK not enabled in hardware there), which fits but is not a controlled comparison.
- Damage appeared for 64, 128, 256 and 4096 byte allocations.
- A kernel-time micro-benchmark showed no slowdown from the patch.

Until a libc with the fence ships, the Fortran program avoids it with element-wise stores
(`loc(1) = i; loc(2) = j; loc(3) = k`), which allocate nothing in the kernel. `-fstack-arrays` also avoided
it in a small test but moves every array temporary of the program to the stack.

## Not established

Only gfx942 was tested. There is no hardware trace, so the cause is inferred from the tests above. The libc
test suite was not run, and the libc was built with AFAR's compiler, not a from-scratch upstream toolchain.
`RELEASE` on the clear alone also passed every test here; the pair in the patch is what the memory model
requires.

## Files

| file | what |
|---|---|
| `repro.c` | C reproducer; `./repro_c 20000000` prints `bad N of 20000000` |
| `repro.f90` | the Fortran program; prints `bad records`, `duplicated cells`, `missing cells` per trial |
| `allocator-release-acquire.patch` | `RELEASE` on the clear, `ACQUIRE` on the claim, against `main` `fc16f151a697` |
| `Makefile` | `make run` (set `AFAR_ROOT`) |

To test a patched libc, build the amdgcn libc from the matching llvm-project commit with the drop's own
clang (`-DLLVM_ENABLE_RUNTIMES=libc -DLLVM_LIBC_FULL_BUILD=ON -DLIBC_TARGET_TRIPLE=amdgcn-amd-amdhsa
-DCMAKE_C_COMPILER_TARGET=amdgcn-amd-amdhsa -DCMAKE_CXX_COMPILER_TARGET=amdgcn-amd-amdhsa
-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`, about two minutes), then add
`-Xoffload-linker <build>/libc/lib/libc.a` to the compile line. A plain `-L` does not override the shipped
`libc.a`.
