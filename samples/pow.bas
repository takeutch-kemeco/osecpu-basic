let a
let b

b := 2
gosub *F

b := -2
gosub *F

b := 0.5
gosub *F

b := -0.5
gosub *F

goto *END

*F
        a := 2
        gosub *FF

        a := -2
        gosub *FF

        return

*FF
        print a ^ b
        return

*END
