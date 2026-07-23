module m
contains
  subroutine k(a,b,n)
    real(8),intent(in)::a(*); real(8),intent(inout)::b(*); integer,intent(in)::n
    integer::i,j
    j=0
    !$omp target teams distribute parallel do simd linear(j)
    do i=1,n
      b(i)=a(i)*real(j,8)
    end do
  end subroutine
end module
