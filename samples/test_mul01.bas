#include "stdoscp.bas"

/* 最初と最後が2に成らなければ異常
 */

dim a = 2;
__print(a);

a = a * 2; a = a * 2; a = a * 2; a = a * 2; a = a * 2; a = a * 2; a = a * 2; a = a * 2;
__print(a);

a = a * 2; a = a * 2; a = a * 2; a = a * 2; a = a * 2;
__print(a);

a = a / 2; a = a / 2; a = a / 2; a = a / 2; a = a / 2; a = a / 2; a = a / 2; a = a / 2;
__print(a);

a = a / 2; a = a / 2; a = a / 2; a = a / 2; a = a / 2;
__print(a);
