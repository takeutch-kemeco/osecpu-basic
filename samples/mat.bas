dim a(3,3)
dim b(3,3)

a(0,0):=0;  a(0,1):=1;  a(0,2):=2;
a(1,0):=10; a(1,1):=11; a(1,2):=12;
a(2,0):=20; a(2,1):=21; a(2,2):=22;

mat b := a
gosub *pb

mat b := zer
gosub *pb

mat b := con
gosub *pb

mat b := a + b
gosub *pb

mat b := con
gosub *pb

mat b := a - b
gosub *pb

mat b := 10 * con
gosub *pb

mat b := idn
gosub *pb

goto *END

*pb
        print b(0,0); print b(0,1); print b(0,2);
        print b(1,0); print b(1,1); print b(1,2);
        print b(2,0); print b(2,1); print b(2,2);
        return

*END
