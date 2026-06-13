rm -f test_* test *.mod
ftn -h acc test.f90 -o test
srun -n 1 ./test
