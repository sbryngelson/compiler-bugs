! `count` is explicitly map(tofrom:) -- it is SHARED. Each atomic capture must
! hand out a distinct value. Under defaultmap CCE privatises `count`, so every
! thread increments its own copy and they all capture the same number.
program p
    implicit none
    integer, parameter :: n = 4096
    integer :: slot(n), count, i, j, dup
    count = 0; slot = 0
#ifdef EXPLICIT
    !$omp target teams distribute parallel do map(tofrom:count,slot)
#else
    !$omp target teams distribute parallel do map(tofrom:count,slot) defaultmap(firstprivate:scalar)
#endif
    do i = 1, n
        !$omp atomic capture
        count = count + 1
        slot(i) = count
        !$omp end atomic
    end do
    dup = 0                            ! count slots that repeat an earlier value
    do i = 1, n
        do j = 1, i - 1
            if (slot(i) == slot(j)) then
                dup = dup + 1; exit
            end if
        end do
    end do
    write (*, '(a,i0,a,i0)') 'priv_atomic: duplicates = ', dup, ' of ', n
    if (dup == 0) then
        print *, 'PASS'
    else
        print *, 'FAIL'
    end if
end program p
