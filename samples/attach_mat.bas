dim a(3,3)
dim b(3,3)

dim ap
dim bp
ap := (100 >> 16)
bp := (200 >> 16)

ap<-a(0,0):=0;  ap<-a(0,1):=1;  ap<-a(0,2):=2;
ap<-a(1,0):=10; ap<-a(1,1):=11; ap<-a(1,2):=12;
ap<-a(2,0):=20; ap<-a(2,1):=21; ap<-a(2,2):=22;

mat bp<-b := ap<-a
gosub *pb

mat bp<-b := zer
gosub *pb

mat bp<-b := con
gosub *pb

mat bp<-b := ap<-a + bp<-b
gosub *pb

mat bp<-b := con
gosub *pb

mat bp<-b := ap<-a - bp<-b
gosub *pb

mat bp<-b := 10 * con
gosub *pb

mat bp<-b := idn
gosub *pb

gosub *p0b

goto *END

*pb
        print bp<-b(0,0); print bp<-b(0,1); print bp<-b(0,2);
        print bp<-b(1,0); print bp<-b(1,1); print bp<-b(1,2);
        print bp<-b(2,0); print bp<-b(2,1); print bp<-b(2,2);
        return

*p0b
        print b(0,0); print b(0,1); print b(0,2);
        print b(1,0); print b(1,1); print b(1,2);
        print b(2,0); print b(2,1); print b(2,2);
        return

*END
