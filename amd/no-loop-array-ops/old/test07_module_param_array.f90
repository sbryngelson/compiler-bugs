! test07_module_param_array.f90
!
! Demonstrates AMD flang 7.2.0 (amdflang) device-code failure when a Fortran
! `parameter` array declared in a `use`d module is accessed as a WHOLE ARRAY
! inside an OpenMP target offload region.
!
! Root cause in MFC: `molecular_weights(:)` from m_thermochem (a `parameter`
! array, not GPU_DECLARE'd) is used as a whole-array operand inside GPU loops
! after a merge commit.  This silently drops ALL GPU kernels during
! device LTO, producing HSA_STATUS_ERROR_INVALID_SYMBOL_NAME at runtime.
!
! This miniapp has two tests:
!   PART A - whole-array access  `param_arr(:) * A(:)` in target region  ->  FAILS
!   PART B - indexed access      `param_arr(i)  * A(i)` in do-loop        ->  WORKS
!
module m_constants
    implicit none
    integer, parameter :: wp = 8
    integer, parameter :: NSPEC = 4
    real(wp), parameter :: molecular_weights(NSPEC) = &
        [28.014_wp, 32.000_wp, 18.015_wp, 44.010_wp]
end module m_constants

program test07_module_param_array
    use m_constants
    implicit none
    integer, parameter :: N = 10000

    real(wp) :: A(N, NSPEC), res_whole(N), res_indexed(N), ref(N)
    integer :: i, k, nerr_whole, nerr_indexed

    do i = 1, N
        do k = 1, NSPEC
            A(i,k) = real(i*k, wp) * 0.001_wp
        end do
        ref(i) = sum(A(i,:) / molecular_weights(:))
    end do

    res_whole = 0._wp
    !$omp target teams distribute parallel do &
    !$omp   map(to:A) map(from:res_whole)
    do i = 1, N
        res_whole(i) = sum(A(i,:) / molecular_weights(:))
    end do
    !$omp end target teams distribute parallel do

    res_indexed = 0._wp
    !$omp target teams distribute parallel do &
    !$omp   map(to:A) map(from:res_indexed)
    do i = 1, N
        res_indexed(i) = 0._wp
        do k = 1, NSPEC
            res_indexed(i) = res_indexed(i) + A(i,k) / molecular_weights(k)
        end do
    end do
    !$omp end target teams distribute parallel do

    nerr_whole = 0
    do i = 1, N
        if (abs(res_whole(i) - ref(i)) > 1.e-10_wp * ref(i)) nerr_whole = nerr_whole + 1
    end do
    if (nerr_whole == 0) then
        print *, "PASS test07a: whole-array module parameter access in target region"
    else
        print *, "FAIL test07a:", nerr_whole, "errors -- whole-array module param access broken"
        print *, "  cell 1: got", res_whole(1), "ref", ref(1)
    end if

    nerr_indexed = 0
    do i = 1, N
        if (abs(res_indexed(i) - ref(i)) > 1.e-10_wp * ref(i)) nerr_indexed = nerr_indexed + 1
    end do
    if (nerr_indexed == 0) then
        print *, "PASS test07b: indexed module parameter access in target region"
    else
        print *, "FAIL test07b:", nerr_indexed, "errors -- indexed module param access broken"
    end if
end program test07_module_param_array
