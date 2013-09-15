#include "stdoscp.bas"

dim a = 4;

__print(a >> 10);
__print(a >>> 10);

__print((a >> 10) << 10);
__print((a >>> 10) << 10);

dim a = -4;

__print(a >> 10);
__print(a >>> 10);

__print((a >> 10) << 10);
__print((a >>> 10) << 10);

