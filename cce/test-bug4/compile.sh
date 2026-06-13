# ftn test-noacc.f90 -o test
rm -f test test_* *.mod
ftn -h acc test.f90 -o test
srun -n 1 ./test
