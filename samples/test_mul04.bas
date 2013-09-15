#include "stdoscp.bas"

/* 最初と最後がほぼ-1に成らなければ異常
 */

dim a = -1;
__print(a);

a = a * -0.5; __print(a);
a = a * -0.5; __print(a);
a = a * -0.5; __print(a);
a = a * -0.5; __print(a);
a = a * -0.5; __print(a);
a = a * -0.5; __print(a);
a = a * -0.5; __print(a);

a = a / -0.5; __print(a);
a = a / -0.5; __print(a);
a = a / -0.5; __print(a);
a = a / -0.5; __print(a);
a = a / -0.5; __print(a);
a = a / -0.5; __print(a);
a = a / -0.5; __print(a);
