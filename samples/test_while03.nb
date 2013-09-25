#include "stdoscp.bas"

float j = 0;
while (j < 10) {
        float i = 0;
        while (i < 10) {
                __print((j * 100) + i);

                i = i + 1;
        }

        j = j + 1;
}
