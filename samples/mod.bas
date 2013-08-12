dim a
dim b
b := 3.1415
a := 1.4142

gosub *F

gosub *SWAP
gosub *F

goto *END

*F
        print a
        print b
        print a mod b
        print (-a) mod b;
        print a mod (-b);
        print (-a) mod (-b);
        return

*SWAP
        dim t
        t := a
        a := b
        b := t
        return

*END
