/* Can C generate the same chained negative-byte-offset GEP into a promotable
   alloca? If so the defect is not Fortran-specific. Mirrors a 1-based index:
   a pointer advanced by n elements, then backed up one element in BYTES. */
#include <stdio.h>
#include <omp.h>
int main(void) {
    int n = 1, out[64];
    for (int i = 0; i < 64; i++) out[i] = -1;
#pragma omp target teams distribute parallel for map(tofrom: out[0:64]) firstprivate(n)
    for (int j = 0; j < 64; j++) {
        int idx[3] = {0, 0, 0};
        int *p = idx + n;                       /* + n elements   */
        int *q = (int *)((char *)p - 4);        /* - 4 BYTES      */
        *q = 5 * (j + 1);                       /* dynamic write  */
        out[j] = idx[0];                        /* expect 5*(j+1) */
    }
    int bad = 0;
    for (int j = 0; j < 64; j++) if (out[j] != 5 * (j + 1)) bad++;
    printf("pa_c nbad=%d of 64  %s (e.g. out[0]=%d expected 5)\n",
           bad, bad ? "FAIL" : "PASS", out[0]);
    return 0;
}
