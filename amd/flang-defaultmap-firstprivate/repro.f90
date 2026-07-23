subroutine k(a,b,n)
  real(8),intent(in)::a(*); real(8),intent(inout)::b(*); integer,intent(in)::n
  integer::i; real(8)::sc
  sc=2.0d0
  !$omp target teams distribute parallel do defaultmap(firstprivate:scalar)
  do i=1,n; b(i)=a(i)*sc; end do
end subroutine
