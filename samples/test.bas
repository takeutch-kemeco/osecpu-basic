let v0(3)
v0(0) := 1
v0(1) := 2
v0(2) := 3

let v1(3)
v1(0) := 1
v1(1) := 2
v1(2) := 3

let ipv
gosub *innerproduct
print ipv

goto *END


*innerproduct
        let v2(3)
        let i
        for i := 0 to 2 step 1
                v2(i) := v0(i) + v1(i)
        next

        ipv := v2(0) + v2(1) + v2(2)
        return

*END
