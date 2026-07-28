! MFC's exact directive form: defaultmap(firstprivate:scalar) together with an
! explicit map(to:) for the scalar that the loop atomically increments to hand
! out unique array slots.
program atomcap
    implicit none
    integer, parameter :: n = 4096
    integer :: i, count, local_idx, nbad, nzero, ndup
    integer :: slot(n), seen(n)
    count = 0
    slot = -1
    !$omp target teams distribute parallel do &
    !$omp& map(from:slot) private(local_idx)
    do i = 1, n
        !$omp atomic capture
        count = count + 1
        local_idx = count
        !$omp end atomic
        slot(i) = local_idx
    end do
    call check('omp no-map no-defmap  ', slot, n)
contains
    subroutine check(tag, s, m)
        character(*), intent(in) :: tag
        integer, intent(in) :: m, s(m)
        integer :: q, t(m), bad, zero, dup
        t = 0; bad = 0; zero = 0; dup = 0
        do q = 1, m
            if (s(q) < 1 .or. s(q) > m) then
                bad = bad + 1
                if (s(q) <= 0) zero = zero + 1
            else
                t(s(q)) = t(s(q)) + 1
            end if
        end do
        do q = 1, m
            if (t(q) > 1) dup = dup + t(q) - 1
        end do
        write (*, '(a,a,a,i0,a,i0,a,i0,a,i0,a)') tag, ': ', 'out_of_range=', bad, &
            ' (<=0: ', zero, ')  duplicates=', dup, '  of ', m, &
            merge('   PASS', '   FAIL', bad == 0 .and. dup == 0)
    end subroutine check
end program atomcap
