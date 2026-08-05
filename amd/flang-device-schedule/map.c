#include <stdio.h>
#include <omp.h>
int main(void) {
  enum { n = 32 };
  static int tid[n];
  for (int i = 0; i < n; ++i) tid[i] = -1;
  #pragma omp target teams distribute parallel for num_teams(1) thread_limit(8) SCHEDCLAUSE map(tofrom: tid)
  for (int i = 0; i < n; ++i) tid[i] = omp_get_thread_num();
  for (int i = 0; i < n; ++i) printf("%3d", tid[i]);
  printf("\n");
  return 0;
}
