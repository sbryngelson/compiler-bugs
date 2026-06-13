rm -f test *.mod test_*
# ftn test.f90 -o test
ftn -h acc test.f90 -o test
srun -n 1 ./test
