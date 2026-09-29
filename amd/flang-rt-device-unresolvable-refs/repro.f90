module m
  implicit none
  type :: t
    real(8) :: x = 1d0
    real(8), allocatable :: y(:)
  end type
contains
  subroutine work(s)
    !$omp declare target
    real(8), intent(inout) :: s
    type(t), allocatable :: v(:)
    allocate(v(4))
    s = s + sum(v%x)
    deallocate(v)
  end subroutine
end module
program r2
  use m
  implicit none
  real(8) :: s
  s = 0d0
  !$omp target map(tofrom:s)
  call work(s)
  !$omp end target
  print *, s
end program
