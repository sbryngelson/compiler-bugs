#include <stdio.h>
int main(void) {
  enum { n = 64 };
  static int seq[n]; int pos = 0;
  for (int i = 0; i < n; ++i) seq[i] = -1;
  #pragma omp target parallel for ordered map(tofrom: seq, pos)
  for (int i = 0; i < n; ++i) {
    #pragma omp ordered
    { seq[pos] = i+1; pos = pos + 1; }
  }
  int bad = 0;
  for (int i = 0; i < n; ++i) if (seq[i] != i+1) ++bad;
  if (!bad) printf("PASS ordered preserved\n");
  else { printf("  FAIL: %d out of order\n  first 16:", bad);
         for (int i = 0; i < 16; ++i) printf("%4d", seq[i]); printf("\n"); }
  return 0;
}
