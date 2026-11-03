// amdclang -fopenmp --offload-arch=gfx942 -O2 t.c && HSA_XNACK=1 ./a.out 20000000
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct { int loc[3]; int ib; } rec_t;
int main(int argc, char **argv) {
  long n = atol(argv[1]);
  rec_t *r = calloc(n, sizeof(rec_t));
#pragma omp target enter data map(alloc : r[0 : n])
#pragma omp target teams distribute parallel for
  for (long i = 0; i < n; i++) {
    int *t = malloc(3 * sizeof(int));
    t[0] = i; t[1] = i >> 8; t[2] = i ^ 1234;
    memcpy(r[i].loc, t, sizeof t[0] * 3);
    free(t);
    r[i].ib = 1;
  }
#pragma omp target update from(r[0 : n])
  long bad = 0;
  for (long i = 0; i < n; i++)
    bad += r[i].loc[0] != (int)i || r[i].loc[1] != (int)(i >> 8) || r[i].loc[2] != (int)(i ^ 1234) || r[i].ib != 1;
  printf("bad %ld of %ld\n", bad, n);
}
