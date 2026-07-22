! firstprivate of a ONE-element real(8) array (8 bytes of data) makes the
! kernel request ~35 KB/lane of scratch with a dynamic stack. The same array
! under private(), shared(), or no clause costs nothing, and a firstprivate
! scalar costs nothing. amdflang (AFAR 23.2.1), gfx90a.
subroutine k(a, b, n, c)
  real(8), intent(in)    :: a(*)
  real(8), intent(inout) :: b(*)
  integer, intent(in)    :: n
  real(8), intent(in)    :: c(1)
  integer :: i
  !$omp target teams distribute parallel do firstprivate(c)
  do i = 1, n
     b(i) = a(i) * c(1)
  end do
end subroutine

program drv
  implicit none
  integer, parameter :: n = 1024
  real(8) :: a(n), b(n), c1(1)
  integer :: i
  do i = 1, n; a(i) = real(i, 8); b(i) = 0; end do
  c1 = 2.0d0
  call k(a, b, n, c1)
  print *, b(1)
end program
