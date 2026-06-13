rm -f test test_* *.mod
# ftn  mod.f90 mod2.f90 test.f90 -o test
ftn -h acc mod.f90 mod2.f90 test.f90  -o test
srun -n 1 ./test
