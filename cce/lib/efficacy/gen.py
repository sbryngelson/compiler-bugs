import sys
# Emit a Fortran file exercising one directive, in a shape where its effect is
# observable in generated code. mode: host | device
def src(directive, mode):
    d = f"!DIR$ {directive}\n" if directive else ""
    dleaf = f"!DIR$ {directive} s_leaf\n" if directive in ("INLINENEVER","INLINEALWAYS","NOINLINE") else ""
    acc_r = "!$acc routine seq\n" if mode=="device" else ""
    loopdir = d if directive in ("NOUNROLL","NOFUSION","VECTOR","PROBABILITY_ALMOST_ALWAYS") else ""
    acc_l = "!$acc parallel loop gang vector present(x,y) private(t)\n" if mode=="device" else ""
    return f"""module m
  implicit none
contains
  subroutine s_leaf(a,b,c)
{acc_r}{dleaf}    real(8), intent(in) :: a,b
    real(8), intent(out) :: c
    c = a*b + a/b
  end subroutine
  subroutine s_driver(x,y,n)
    real(8), intent(inout) :: x(:),y(:)
    integer, intent(in) :: n
    real(8) :: t
    integer :: i
{acc_l}{loopdir}    do i=1,n
      call s_leaf(x(i),y(i),t); x(i)=t
    end do
  end subroutine
end module
program p
  use m
  real(8) :: x(1024),y(1024)
  x=2.0d0; y=3.0d0
{"!$acc data copy(x,y)" if mode=="device" else ""}
  call s_driver(x,y,1024)
{"!$acc end data" if mode=="device" else ""}
  print *, x(1)
end program
"""
open(sys.argv[3],"w").write(src(sys.argv[1] if sys.argv[1]!="NONE" else "", sys.argv[2]))
