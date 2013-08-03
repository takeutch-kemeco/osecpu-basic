let a
a := 3.1415

let b
b := 1.4142

gosub *F

gosub *SWAP
gosub *F

goto *END

*F
        print a
        print b
        print a * b
        print (-a) * b;
        print a * (-b);
        print (-a) * (-b);
        return

*SWAP
        let t
        t := a
        a := b
        b := t
        return

*END
