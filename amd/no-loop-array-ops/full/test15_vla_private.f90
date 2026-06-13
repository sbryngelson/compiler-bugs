! test15_vla_private.f90
! Tests whether AMD OpenMP target correctly handles a fixed-size private array
! inside a target teams distribute parallel do.
! This is the BASELINE (always works); test15b tests the failing VLA case.
program test15_vla_private
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: NCELLS = 2500
    integer, parameter :: NF = 3

    real(wp) :: inp(NCELLS), out(NCELLS)
    integer  :: i, j, nerr

    do i = 1, NCELLS
        inp(i) = real(i, wp) * 0.001_wp
    end do
    out = 0._wp

    call run_test(NF, NCELLS, inp, out)

    nerr = 0
    do i = 1, NCELLS
        if (abs(out(i) - inp(i)) > 1.e-12_wp) nerr = nerr + 1
    end do

    if (nerr == 0) then
        print *, "PASS test15: fixed-size dim(NF) private array works"
    else
        print *, "FAIL test15:", nerr, "cells wrong"
        print *, "  cell 1: expected", inp(1), "got", out(1)
    end if

contains

    subroutine run_test(nf, N, inp, out)
        integer, intent(in)  :: nf, N
        real(wp), intent(in) :: inp(N)
        real(wp), intent(out):: out(N)
        real(wp) :: local(NF)   ! parameter size -- always safe
        integer  :: i, j

        !$omp target teams distribute parallel do &
        !$omp   map(to:inp,nf) map(from:out) private(local,j)
        do i = 1, N
            do j = 1, nf
                local(j) = inp(i)
            end do
            out(i) = 0._wp
            do j = 1, nf
                out(i) = out(i) + local(j)
            end do
        end do
        !$omp end target teams distribute parallel do
    end subroutine

end program test15_vla_private
