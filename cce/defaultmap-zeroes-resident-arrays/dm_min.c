/* Does a defaultmap clause privatize an explicitly-mapped scalar?
   C/C++ equivalent of the Fortran case, to test whether the defect is in the
   Fortran front end or in the shared OpenMP lowering. */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    int n = 1024, d1 = 0, d2 = 0;
    int *a = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) a[i] = 1;
#pragma omp target enter data map(to: a[0:n])
#pragma omp target teams distribute parallel for map(tofrom: d1)
    for (int i = 0; i < n; i++) if (a[i]) {
#pragma omp atomic
        d1++;
    }
#pragma omp target teams distribute parallel for defaultmap(tofrom:aggregate) map(tofrom: d2)
    for (int i = 0; i < n; i++) if (a[i]) {
#pragma omp atomic
        d2++;
    }
    printf("no-defaultmap d1=%d  with-defaultmap d2=%d  (expect 1024 both) %s\n",
           d1, d2, (d1==1024 && d2==1024) ? "PASS" : "FAIL");
    return 0;
}
