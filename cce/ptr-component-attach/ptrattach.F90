! Does mapping a POINTER COMPONENT of an already-present derived type attach the
! device parent's pointer to the device pointee?
!
! This is exactly what MFC's ACC_SETUP_SFs does (macros.fpp:111):
!     enter data copyin(x)        ! the derived type
!     enter data copyin(x%sf)     ! the pointee, as a separate directive
! Under OpenACC that second map implicitly ATTACHES. Under OpenMP it is unclear.
!
! Variant A: two separate directives      (what MFC emits today)
! Variant B: one directive, both objects  (candidate workaround)
module m
    implicit none
    type :: sf_t
        integer, pointer :: sf(:, :, :) => null()
    end type sf_t
    type(sf_t) :: mk
    integer :: nfound
#ifdef USE_OMP
    !$omp declare target(mk, nfound)
#else
    !$acc declare create(mk, nfound)
#endif
end module m

program ptrattach
    use m
    implicit none
    character(len=8) :: variant
    integer :: i, j, hostcount
    call get_command_argument(1, variant)
    allocate (mk%sf(-2:5, -2:5, 0:0))
    mk%sf = 0
    mk%sf(1, 1, 0) = 7; mk%sf(2, 2, 0) = 7; mk%sf(3, 3, 0) = 7; mk%sf(0, 0, 0) = 7

    hostcount = 0
    do i = -2, 5
        do j = -2, 5
            if (mk%sf(i, j, 0) /= 0) hostcount = hostcount + 1
        end do
    end do

#ifdef USE_OMP
    if (trim(variant) == 'B') then
        !$omp target enter data map(to: mk, mk%sf)
    else
        !$omp target enter data map(to: mk)
        !$omp target enter data map(to: mk%sf)
    end if
    nfound = 0
    !$omp target update to(nfound)
    !$omp target teams distribute parallel do collapse(2) reduction(+:nfound)
    do i = -2, 5
        do j = -2, 5
            if (mk%sf(i, j, 0) /= 0) nfound = nfound + 1
        end do
    end do
    !$omp target update from(nfound)
#else
    if (trim(variant) == 'B') then
        !$acc enter data copyin(mk, mk%sf)
    else
        !$acc enter data copyin(mk)
        !$acc enter data copyin(mk%sf)
    end if
    nfound = 0
    !$acc update device(nfound)
    !$acc parallel loop collapse(2) reduction(+:nfound) default(present)
    do i = -2, 5
        do j = -2, 5
            if (mk%sf(i, j, 0) /= 0) nfound = nfound + 1
        end do
    end do
    !$acc update host(nfound)
#endif
    write (*, '(a,a,a,i0,a,i0,a)') 'variant=', trim(variant), &
        '  host=', hostcount, '  device=', nfound, &
        merge('   PASS', '   FAIL', hostcount == nfound)
end program ptrattach
