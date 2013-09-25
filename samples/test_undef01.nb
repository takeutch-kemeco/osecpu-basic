#include "stdoscp.bas"

#define ABC 123
__print(ABC);

#undef ABC
float ABC = 234;
__print(ABC);

