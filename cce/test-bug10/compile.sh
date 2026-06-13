rm -f test_* test *.mod 
# ftn test.f90 -o test
ftn -h acc -M878 test.f90 -o test
srun -n 1 ./test
