! Does a device kernel read an array with a NEGATIVE lower bound correctly?
! MFC's ib_markers%sf is allocated (-buff_size:m+buff_size, ...) and a device
! loop over the interior finds nothing, while the identical host loop finds the
! markers. This isolates that: same array, same loop, host vs device, with a
! 1-based control that differs only in the declared bounds.
module m_nb
    implicit none
    integer, parameter :: lo = -4, hi = 11          ! interior 0..7, buffer 4 deep
    integer, allocatable :: neg(:, :, :)            ! bounds lo:hi
    integer, allocatable :: one(:, :, :)            ! bounds 1:(hi-lo+1)
    !$omp declare target(neg, one)
end module m_nb

program negbound
    use m_nb
    implicit none
    integer :: i, j, k, hneg, dneg, hone, done
    allocate (neg(lo:hi, lo:hi, lo:hi)); neg = 0
    allocate (one(1:hi - lo + 1, 1:hi - lo + 1, 1:hi - lo + 1)); one = 0
    ! mark the same physical cells in both, via each array's own indexing
    do k = 0, 7; do j = 0, 7; do i = 0, 7
        if (mod(i + j + k, 3) == 0) then
            neg(i, j, k) = 1
            one(i - lo + 1, j - lo + 1, k - lo + 1) = 1
        end if
    end do; end do; end do
    hneg = count(neg /= 0); hone = count(one /= 0)
    !$omp target enter data map(to: neg, one)
    dneg = 0
    !$omp target teams distribute parallel do collapse(3) map(tofrom: dneg)
    do k = 0, 7
        do j = 0, 7
            do i = 0, 7
                if (neg(i, j, k) /= 0) then
                    !$omp atomic update
                    dneg = dneg + 1
                end if
            end do
        end do
    end do
    done = 0
    !$omp target teams distribute parallel do collapse(3) map(tofrom: done)
    do k = 0, 7
        do j = 0, 7
            do i = 0, 7
                if (one(i - lo + 1, j - lo + 1, k - lo + 1) /= 0) then
                    !$omp atomic update
                    done = done + 1
                end if
            end do
        end do
    end do
    write (*, '(a,i0,a,i0,a)') 'negative-lb  host=', hneg, ' device=', dneg, &
        merge('   PASS', '   FAIL', hneg == dneg)
    write (*, '(a,i0,a,i0,a)') 'one-based    host=', hone, ' device=', done, &
        merge('   PASS', '   FAIL', hone == done)
end program negbound
