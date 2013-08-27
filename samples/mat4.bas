dim a(3,3)
a(0,0):=0;  a(0,1):=1;  a(0,2):=2;
a(1,0):=10; a(1,1):=11; a(1,2):=12;
a(2,0):=20; a(2,1):=21; a(2,2):=22;

dim b(3)
b(0):=10; b(1):= 20; b(2):=30;

dim c
c:=10

dim ic
ic:=1/c

gosub *pa
mat a := c * a
gosub *pa
mat a := ic * a
gosub *pa

gosub *pb
mat b := c * b
gosub *pb
mat b := ic * b
gosub *pb

goto *END

*pa
        print a(0,0); print a(0,1); print a(0,2);
        print a(1,0); print a(1,1); print a(1,2);
        print a(2,0); print a(2,1); print a(2,2);
        return

*pb
        print b(0); print b(1); print b(2);
        return

*END
