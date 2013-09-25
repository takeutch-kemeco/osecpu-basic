#include "stdoscp.bas"

if (1) {
        __print(123);
        if (1) {
                __print(234);
                if (0) {
                        __print(-1);
                } else {
                        __print(345);
                }
        } else {
                __print(-1);
        }
} else {
        __print(-1);
}
