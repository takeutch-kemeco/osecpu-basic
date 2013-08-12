dim a
a := 0

dim i
i := 1
*LLL
        a := a + i
        i := i + 1
        if i <= 10 then goto *LLL

print a
