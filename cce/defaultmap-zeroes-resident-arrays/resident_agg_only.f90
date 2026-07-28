! Reading a derived-type POINTER COMPONENT on the device.
!
! MFC's ib_markers is type(scalar_field) with an integer pointer component %sf.
! It is made resident, populated on the host, and pushed with an explicit update.
! The runtime trace confirms the data lands in exactly the buffer %sf is attached
! to -- yet a device loop reads all zeros, while the identical host loop reads the
! real values. A plain module allocatable in the same position works.
!
! Arms: pointer component vs allocatable component vs bare module array.
module m_resident
    implicit none
    integer, parameter :: n = 16
    type :: sf_ptr_t
        integer, pointer :: sf(:, :, :) => null()
    end type sf_ptr_t
    type :: sf_alloc_t
        integer, allocatable :: sf(:, :, :)
    end type sf_alloc_t
    type(sf_ptr_t)   :: dptr
    type(sf_alloc_t) :: dalloc
    integer, allocatable :: bare(:, :, :)
    !$omp declare target(dptr, dalloc, bare)
end module m_resident

program resident
    use m_resident
    implicit none
    integer :: i, j, k, h1, d1, h2, d2, h3, d3
    allocate (dptr%sf(-2:n + 2, -2:n + 2, -2:n + 2))
    allocate (dalloc%sf(-2:n + 2, -2:n + 2, -2:n + 2))
    allocate (bare(-2:n + 2, -2:n + 2, -2:n + 2))
    dptr%sf = 0; dalloc%sf = 0; bare = 0
    do k = 0, n; do j = 0, n; do i = 0, n
        if (mod(i + j + k, 5) == 0) then
            dptr%sf(i, j, k) = 1; dalloc%sf(i, j, k) = 1; bare(i, j, k) = 1
        end if
    end do; end do; end do
    h1 = count(dptr%sf /= 0); h2 = count(dalloc%sf /= 0); h3 = count(bare /= 0)

    !$omp target enter data map(to: dptr, dalloc, bare)
    !$omp target enter data map(to: dptr%sf, dalloc%sf)
    !$omp target update to(dptr%sf, dalloc%sf, bare)

    d1 = 0
    !$omp target teams distribute parallel do defaultmap(tofrom:aggregate) collapse(3) map(tofrom: d1)
    do k = 0, n; do j = 0, n; do i = 0, n
        if (dptr%sf(i, j, k) /= 0) then
            !$omp atomic update
            d1 = d1 + 1
        end if
    end do; end do; end do
    d2 = 0
    !$omp target teams distribute parallel do defaultmap(tofrom:aggregate) collapse(3) map(tofrom: d2)
    do k = 0, n; do j = 0, n; do i = 0, n
        if (dalloc%sf(i, j, k) /= 0) then
            !$omp atomic update
            d2 = d2 + 1
        end if
    end do; end do; end do
    d3 = 0
    !$omp target teams distribute parallel do defaultmap(tofrom:aggregate) collapse(3) map(tofrom: d3)
    do k = 0, n; do j = 0, n; do i = 0, n
        if (bare(i, j, k) /= 0) then
            !$omp atomic update
            d3 = d3 + 1
        end if
    end do; end do; end do

    write (*, '(a,i0,a,i0,a)') 'pointer-component    host=', h1, ' device=', d1, merge('   PASS', '   FAIL', h1 == d1)
    write (*, '(a,i0,a,i0,a)') 'allocatable-component host=', h2, ' device=', d2, merge('   PASS', '   FAIL', h2 == d2)
    write (*, '(a,i0,a,i0,a)') 'bare module array    host=', h3, ' device=', d3, merge('   PASS', '   FAIL', h3 == d3)
end program resident
