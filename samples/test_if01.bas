#include "stdoscp.bas"

if (0 < 1)
        __print(123);

if (1)
        __print(234);

if (0) __print(-1); else __print(345);

if (0)
        __print(-1);
else
        __print(456);

if (1) {
        __print(567);
} else {
        __print(-1);
}
