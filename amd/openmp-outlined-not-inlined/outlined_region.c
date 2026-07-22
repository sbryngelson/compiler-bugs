/* Control for outlined_region.f90: identical arithmetic and loop structure in C.
 *
 *   amdclang -fopenmp --offload-arch=gfx90a -O3 \
 *            -Rpass-analysis=kernel-resource-usage outlined_region.c -o /dev/null
 *
 * clang inlines the target body into the kernel: VGPRs 80, ScratchSize 0, occupancy 6.
 */
#define M 16

void kern(double *a, double *b, int n) {
  #pragma omp target teams distribute parallel for
  for (int i = 0; i < n; ++i) {
    double t[M], u[M];
    for (int k = 1; k <= M; ++k) {
      double rk = (double)k;
      t[k-1] = (2.0*a[i] - 7.0*rk)/6.0 + 0.25*(a[i] - rk)*(a[i] - rk);
      u[k-1] = (2.0*rk - 7.0*a[i])/6.0 + 0.25*(rk - a[i])*(rk - a[i]);
    }
    for (int k = 1; k < M; ++k) t[0] += t[k]*u[k];
    b[i] = t[0] + u[0] + t[1]*u[2] + t[3]/u[4];
  }
}

int main(void) {
  static double a[1024], b[1024];
  kern(a, b, 1024);
  return (int)b[0];
}
