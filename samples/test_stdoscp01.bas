#include "stdoscp.bas"

dim a[1000];
a[10] = 123;
__print(a[10]);

dim b;
b = __peek(10 >> 16);
__print(b);

__poke(&a[10] + (10 >> 16), 234);
__print(a[20]);

__openwin(480, 240);

__fillrect(0, 10, 20, 100, 200, 0x00ffffff);

__drawrect(0, 20, 30, 200, 100, 0x00ffaa88);

__drawpoint(0, 150, 150, 0x00ffffff);

__filloval(0, 100, 150, 10, 20, 0x00ff00ff);

__drawoval(0, 100, 150, 30, 50, 0x00ffff00);

__drawline(0, 60, 70, 180, 200, 0x00aaffaa);

__flushwin(10, 10, 100, 100);

__inkey(0);

dim x = __rand(100);
__print(x);
