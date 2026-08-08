#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int tl = atoi(argv[1]);
  int s_none = 0, s_atomic = 0, s_crit = 0;
  #pragma omp target parallel for num_threads(tl) map(tofrom: s_none)
  for (int i = 0; i < tl; ++i) s_none += 1;
  #pragma omp target parallel for num_threads(tl) map(tofrom: s_atomic)
  for (int i = 0; i < tl; ++i) { 
    #pragma omp atomic update
    s_atomic += 1; }
  #pragma omp target parallel for num_threads(tl) map(tofrom: s_crit)
  for (int i = 0; i < tl; ++i) {
    #pragma omp critical
    { s_crit += 1; } }
  printf("threads=%4d  none=%6d  atomic=%6d  critical=%6d\n", tl, s_none, s_atomic, s_crit);
  return 0;
}
