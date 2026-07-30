! MFC's actual shape: a scalar explicitly map(tofrom:)'d, accumulated by every
! thread through !$omp atomic update, under a directive carrying
! defaultmap(firstprivate:scalar) -- which is what omp_macros.fpp emits.
program p
    implicit none
    integer, parameter :: n = 4096
    integer :: s, i
    s = 0
#ifdef EXPLICIT
    !$omp target teams distribute parallel do map(tofrom:s)
#else
    !$omp target teams distribute parallel do map(tofrom:s) defaultmap(firstprivate:scalar)
#endif
    do i = 1, n
        !$omp atomic update
        s = s + 1
    end do
    write (*, '(a,i0,a,i0)') 'atomic_update: sum = ', s, ' expected ', n
    if (s == n) then
        print *, 'PASS'
    else
        print *, 'FAIL'
    end if
end program p
