print fact(5)

goto *END

function fact(x)
        if x > 1 then fact := x * fact(x - 1); else fact := 1;
end function

*END

