module m
contains
  subroutine k(a,b,n)
    real(8),intent(in)::a(*); real(8),intent(inout)::b(*); integer,intent(in)::n
    integer::i; real(8)::t(4)
    !$omp target teams distribute parallel do private(t)
    do i=1,n
      t=a(i); b(i)=sum(t)
    end do
  end subroutine
end module
