dim a(3)
a(0) := 1
a(1) := 2
a(2) := 3

dim b(3)
b(0) := 1
b(1) := 2
b(2) := 3

print innerproduct(a(0),a(1),a(2),b(0),b(1),b(2))

goto *END

function innerproduct(a0,a1,a2,b0,b1,b2)
        innerproduct := (a0 * b0 + a1 * b1 + a2 * b2) ^ 0.5
end function

*END
