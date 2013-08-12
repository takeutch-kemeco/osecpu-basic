dim a
a := 1

on a = 1 gosub *L1

on a <> 1 gosub *L1

print 2
goto *END

*L1
print 1
return

*END
