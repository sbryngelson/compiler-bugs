module m_lin
contains
  subroutine k(a,b,n)
    real(8),intent(in)::a(*); real(8),intent(inout)::b(*); integer,intent(in)::n
    integer::i,j
    j=0
    !$omp target teams distribute parallel do simd linear(j)
    do i=1,n; j=j+1; b(i)=a(i)*real(j,8); end do
  end subroutine
end module

program drv
  use m_lin
  implicit none
  integer,parameter::n=256
  real(8)::a(n),b(n)
  a=1; b=0
  call k(a,b,n)
  print *,b(1)
end program
