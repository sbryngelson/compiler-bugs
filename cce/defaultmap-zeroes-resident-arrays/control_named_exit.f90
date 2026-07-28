! MFC's ghost-point search: a named EXIT out of a triple-nested loop, from the
! innermost level, inside a device kernel. Everything else about the counting
! kernel has been eliminated (data present, scalar returns, bounds correct), so
! this construct is what remains.
module m_ne
    implicit none
    integer, parameter :: nx = 16
    integer, allocatable :: mk(:, :, :)
    !$omp declare target(mk)
end module m_ne

program namedexit
    use m_ne
    implicit none
    integer :: i, j, k, ii, jj, kk, hcount, dcount
    logical :: is_gp
    allocate (mk(-2:nx + 2, -2:nx + 2, -2:nx + 2)); mk = 0
    do k = 0, nx; do j = 0, nx; do i = 0, nx
        if (mod(i + j + k, 4) /= 0) mk(i, j, k) = 1     ! solid, with holes
    end do; end do; end do

    hcount = 0                                          ! host reference
    do i = 0, nx; do j = 0, nx; do k = 0, nx
        if (mk(i, j, k) /= 0) then
            is_gp = .false.
            hsearch: do ii = i - 1, i + 1
                do jj = j - 1, j + 1
                    do kk = k - 1, k + 1
                        if (mk(ii, jj, kk) == 0) then
                            is_gp = .true.
                            exit hsearch
                        end if
                    end do
                end do
            end do hsearch
            if (is_gp) hcount = hcount + 1
        end if
    end do; end do; end do

    !$omp target enter data map(to: mk)
    dcount = 0
    !$omp target teams distribute parallel do collapse(3) map(tofrom: dcount) &
    !$omp& private(ii, jj, kk, is_gp)
    do i = 0, nx
        do j = 0, nx
            do k = 0, nx
                if (mk(i, j, k) /= 0) then
                    is_gp = .false.
                    dsearch: do ii = i - 1, i + 1
                        do jj = j - 1, j + 1
                            do kk = k - 1, k + 1
                                if (mk(ii, jj, kk) == 0) then
                                    is_gp = .true.
                                    exit dsearch
                                end if
                            end do
                        end do
                    end do dsearch
                    if (is_gp) then
                        !$omp atomic update
                        dcount = dcount + 1
                    end if
                end if
            end do
        end do
    end do
    write (*, '(a,i0,a,i0,a)') 'named-exit  host=', hcount, ' device=', dcount, &
        merge('   PASS', '   FAIL', hcount == dcount)
end program namedexit
