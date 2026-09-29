module m
  implicit none
  logical :: use_b = .false.
  !$omp declare target(use_b)
contains
  subroutine work(a, n, b)
    integer, intent(in) :: n
    real(8), intent(inout) :: a(n)
    real(8), dimension(:), optional, intent(inout) :: b
    integer :: i
    !$omp target teams distribute parallel do private(i)
    do i = 1, n
      if (use_b) then
        a(i) = a(i) + b(1)
      else
        a(i) = a(i) + 1d0
      end if
    end do
  end subroutine
end module
program p
  use m
  implicit none
  real(8) :: a(100)
  a = 0d0
  !$omp target enter data map(to:a)
  call work(a, 100)
  !$omp target exit data map(from:a)
  print *, 'sum =', sum(a), ' (expect 100)'
end program
