#include "stdoscp.bas"

float a = 4;

__print(a >> 10);
__print(a >>> 10);

__print((a >> 10) << 10);
__print((a >>> 10) << 10);

float a = -4;

__print(a >> 10);
__print(a >>> 10);

__print((a >> 10) << 10);
__print((a >>> 10) << 10);

