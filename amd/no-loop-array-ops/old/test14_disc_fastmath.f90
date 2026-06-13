! test14_disc_fastmath.f90
! Tests whether -fopenmp-target-fast causes disc < 0 in the fast magnetosonic
! speed formula. Hypothesis: relaxed FP may flip sign of discriminant.
! Result: PASS (disc always >= 0); -fopenmp-target-fast is not the root cause.
program test14_disc_fastmath
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: N = 100000

    real(wp) :: disc_min, disc_i
    real(wp) :: rho, c_sq, Bn, Bt1, Bt2, B2loc, term
    integer  :: i, n_neg

    disc_min = huge(1._wp)
    n_neg = 0

    !$omp target teams distribute parallel do &
    !$omp   reduction(min:disc_min) reduction(+:n_neg) &
    !$omp   private(rho,c_sq,Bn,Bt1,Bt2,B2loc,term,disc_i)
    do i = 1, N
        rho   = 1.e-3_wp * (1._wp + real(mod(i, 997), wp))
        c_sq  = 1.e-2_wp * (1._wp + real(mod(i, 503), wp))
        Bn    = 0.5641895835_wp * (1._wp + 0.001_wp*real(mod(i, 100), wp))
        Bt1   = 1.0149412604_wp * (1._wp + 0.001_wp*real(mod(i, 200), wp))
        Bt2   = 0.5641895835_wp
        B2loc = Bn**2 + Bt1**2 + Bt2**2
        term   = c_sq + B2loc / rho
        disc_i = term**2 - 4._wp * c_sq * (Bn**2 / rho)
        disc_min = min(disc_min, disc_i)
        if (disc_i < 0._wp) n_neg = n_neg + 1
    end do
    !$omp end target teams distribute parallel do

    print *, "min(disc) =", disc_min
    print *, "n_neg     =", n_neg
    if (n_neg == 0) then
        print *, "PASS test14: disc >= 0 for all cells"
    else
        print *, "FAIL test14:", n_neg, "cells with disc < 0"
    end if
end program test14_disc_fastmath
