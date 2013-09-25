#include "stdoscp.bas"

#define A 123
float a = A;
__print(a);
#define A 234
a = A;
__print(a);
