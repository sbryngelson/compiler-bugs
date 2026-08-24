# Synthetic source reproducer: attempted, does not trigger

`gen.py N` emits a Fortran program with N target regions plus one victim kernel; `sweep.sh 256 512 600` compiles each and prints the victim's LDS/scratch/VGPR and the image-wide LDS histogram. Three filler designs were tried:

1. trivial `target teams distribute parallel do` copy loops;
2. plus a runtime-sized local array mapped `tofrom` (forces globalization);
3. plus a call to a `recursive` `declare target` function (blocks inlining).

None reproduces. At 602 kernels the victim's ISA is unchanged (LDS 0, scratch 0, VGPR 28) and, checked directly with a compiler instrumented at the cap site, the access cap fires **zero** times — versus 3800 times on the real MFC module. The generated module is not missing the construct: it contains 616 references to `__kmpc_parallel_60` / `SharedMemVariableSharingSpace`, more than MFC's 537.

So kernel count alone is not the trigger. What matters is how many accesses actually accumulate on one object, which depends on the call structure the Attributor walks: in MFC the state globals reach ~512 accesses (about one per kernel, through callsite translation), while in these synthetic images the same globals stay far below the cap. Reproducing synthetically would require matching that accumulation, which we have not isolated.

This is why the bitcode pair in this directory is the practical reproducer: it is the real merged device-LTO module, needs only `opt`, and no application build or GPU.
