rem ポインターのテスト

rem アドレスはfix32型ではなく、int32型なので、
rem p=&a などとした値は、0.000...1 のような小さな数となる。
rem そのため普通に print p としても、桁が小さすぎて0.0000としか表示されない。
rem これを p<<16 することで、printでも表示できるようになる。
rem すなわち、アドレスは内部的にはint32として受け渡しされ、使用されている。

dim padding(10);
dim p;

dim a;
a=123;
p=&a;
print p@a
print p
print p<<16

dim b;
b=234;
p=&b
print p@a
print p
print p<<16
