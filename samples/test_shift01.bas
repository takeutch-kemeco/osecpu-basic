#include "stdoscp.bas"

dim a = 4;
__print(a >> 1);
__print(a >> 2);
__print(a >> 3);

__print(a << 1);
__print(a << 2);
__print(a << 3);

__print(a >> 16);
__print(a >> 20);

__print((a >> 16) << 16);
__print((a >> 16) << 28);
__print((a >> 16) << 29);
__print((a >> 16) << 30);
