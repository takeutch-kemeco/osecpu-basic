dim c
dim w
dim h
dim r
dim g
dim b
for c := 0 to 10000 step 0.01
        b := (sin c) * 255
        for h := 0 to 255 step 1
                for w := 0 to 255 step 1
                        r := w
                        g := h
                        drawpoint 0 w h r g b
                next
        next
        sleep 0 1
next
