#include "stdoscp.bas"

/* ポインターのテスト
 *
 * アドレスはfix32型ではなく、int32型なので、
 * p=&a などとした値は、0.000...1 のような小さな数となる。
 * そのため普通に __print(p としても、桁が小さすぎて0.0000としか表示されない。
 * これを p<<16 することで、printでも表示できるようになる。
 * すなわち、アドレスは内部的にはint32として受け渡しされ、使用されている。
 */

dim padding[10];
dim p;

dim a=123;
p=&a;
__print(p@a);
__print(p);
__print(p<<16);

dim b;
b=234;
p=&b;
__print(p@a);
__print(p);
__print(p<<16);
