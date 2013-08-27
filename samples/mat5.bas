dim b(3)
b(0):=10; b(1):= 20; b(2):=30;

dim c

gosub *pb
mat c := b * b
print c

goto *END

*pb
        print b(0); print b(1); print b(2);
        return

*END
