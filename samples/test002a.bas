openwin 256 256

dim c
for c := 0 to 1234 step 0.05
        dim b

rem     b := (sin c) * 255
        b := (cos c) * 255

        if b < 0 then b := -b

        dim h
        for h := 0 to 255 step 1
                dim w
                for w := 0 to 255 step 1
                        dim r
                        dim g
                        r := w
                        g := h

                        drawpoint 0 w h r g b
                next
        next
        sleep 0 1
next
