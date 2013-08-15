dim a(4,3)
dim b(3,4)

dim ap
dim bp
ap := (100 >> 16)
bp := (200 >> 16)

ap<-a(0,0):=0;  ap<-a(0,1):=1;  ap<-a(0,2):=2;
ap<-a(1,0):=10; ap<-a(1,1):=11; ap<-a(1,2):=12;
ap<-a(2,0):=20; ap<-a(2,1):=21; ap<-a(2,2):=22;
ap<-a(3,0):=30; ap<-a(3,1):=31; ap<-a(3,2):=32;

gosub *pa

mat bp<-b := trn(ap<-a)
gosub *pb

goto *END

*pa
        print ap<-a(0,0); print ap<-a(0,1); print ap<-a(0,2);
        print ap<-a(1,0); print ap<-a(1,1); print ap<-a(1,2);
        print ap<-a(2,0); print ap<-a(2,1); print ap<-a(2,2);
        print ap<-a(3,0); print ap<-a(3,1); print ap<-a(3,2);
        return

*pb
        print bp<-b(0,0); print bp<-b(0,1); print bp<-b(0,2); print bp<-b(0,3);
        print bp<-b(1,0); print bp<-b(1,1); print bp<-b(1,2); print bp<-b(1,3);
        print bp<-b(2,0); print bp<-b(2,1); print bp<-b(2,2); print bp<-b(2,3);
        return

*END
