dim a
a := 1

on a = 1 goto *L1

print -1

*L1
print 1

on a <> 1 goto *L2

print 2

goto *END

*L2
print -1

*END
