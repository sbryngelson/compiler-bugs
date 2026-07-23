module mc
contains
  subroutine k(a,b,n)
    real(8),intent(in)::a(*); real(8),intent(inout)::b(*); integer,intent(in)::n
    integer::i
    !$omp target teams distribute parallel do
    do i=1,n; b(i)=a(i)*2.0d0; end do
  end subroutine
end module
