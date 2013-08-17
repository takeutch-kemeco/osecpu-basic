dim w
dim h

dim r
for r := 0 to (3.14 * 2) step 0.05
        w := fx(r)
        h := fy(r)
        print w
        print h
        dim col; col:=torgb 255 255 255
        drawline 0 100 + w 300 + h 100 + w 300 + h col
next

goto *END
def fx(r) := r * 50
def fy(r) := (sin r) * 50

def rx(x, y) := ((cos r) * x) - ((sin r) * y)
def ry(x, y) := ((sin r) * x) + ((cos r) * y)

*END
