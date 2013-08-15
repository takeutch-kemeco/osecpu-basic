dim a(3,3)
dim b(3,3)
dim c(3,3)

dim ap
dim bp
dim cp
ap := (100 >> 16)
bp := (200 >> 16)
cp := (300 >> 16)

ap<-a(0,0):=0;  ap<-a(0,1):=1;  ap<-a(0,2):=2;
ap<-a(1,0):=10; ap<-a(1,1):=11; ap<-a(1,2):=12;
ap<-a(2,0):=20; ap<-a(2,1):=21; ap<-a(2,2):=22;

mat bp<-b := idn

bp<-b(0,0) := 0;
bp<-b(2,2) := 0;

mat cp<-c := ap<-a * bp<-b
gosub *pc

mat cp<-c := bp<-b * ap<-a
gosub *pc

goto *END

*pa
        print ap<-a(0,0); print ap<-a(0,1); print ap<-a(0,2);
        print ap<-a(1,0); print ap<-a(1,1); print ap<-a(1,2);
        print ap<-a(2,0); print ap<-a(2,1); print ap<-a(2,2);
        return

*pb
        print bp<-b(0,0); print bp<-b(0,1); print bp<-b(0,2);
        print bp<-b(1,0); print bp<-b(1,1); print bp<-b(1,2);
        print bp<-b(2,0); print bp<-b(2,1); print bp<-b(2,2);
        return

*pc
        print cp<-c(0,0); print cp<-c(0,1); print cp<-c(0,2);
        print cp<-c(1,0); print cp<-c(1,1); print cp<-c(1,2);
        print cp<-c(2,0); print cp<-c(2,1); print cp<-c(2,2);
        return

*END
