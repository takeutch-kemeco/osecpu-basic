gosub *X
print 4

goto *END

*X
print 1
gosub *Y
print 3
return

*Y
print 2
return

*END
