#include "stdoscp.bas"

dim aaa = 234;
function a01(x,y,z)
{
        __print(aaa);
        __print(x);
        __print(y);
        __print(z);
        dim q = 789;
        __print(x);
        __print(q);
        __print(y);
        __print(z);
        return 123;
}
a01(1,2,3);
dim x = a01(4,5,6);
__print(x);

x = a01(7,8);
__print(x);

x = a01(9,10,11,12);
__print(x);
