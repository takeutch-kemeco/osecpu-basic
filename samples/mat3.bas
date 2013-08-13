dim a(3,3)
dim b(3,3)
dim c(3,3)

a(0,0):=0;  a(0,1):=1;  a(0,2):=2;
a(1,0):=10; a(1,1):=11; a(1,2):=12;
a(2,0):=20; a(2,1):=21; a(2,2):=22;

mat a := idn
mat b := idn

gosub *pa
gosub *pb

mat c := a * b
gosub *pc

goto *END

*pa
        print a(0,0); print a(0,1); print a(0,2);
        print a(1,0); print a(1,1); print a(1,2);
        print a(2,0); print a(2,1); print a(2,2);
        return

*pb
        print b(0,0); print b(0,1); print b(0,2);
        print b(1,0); print b(1,1); print b(1,2);
        print b(2,0); print b(2,1); print b(2,2);
        return

*pc
        print c(0,0); print c(0,1); print c(0,2);
        print c(1,0); print c(1,1); print c(1,2);
        print c(2,0); print c(2,1); print c(2,2);
        return

*END
