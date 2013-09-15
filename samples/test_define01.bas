#include "stdoscp.bas"

#define A 123
dim a = A;
__print(a);
#define A 234
a = A;
__print(a);
