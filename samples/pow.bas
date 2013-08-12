dim a
dim b

ff(2)
ff(-2)
ff(0.5)
ff(-0.5)

goto *END

def f(x,y) := x ^ y

function ff(y)
        print f(2, y)
        print f(-2, y)
end function

*END
