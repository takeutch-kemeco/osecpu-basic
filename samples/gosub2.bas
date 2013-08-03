gosub *L0

print 3

goto *END

*L0
print 1
gosub *L1
return

*L1
print 2
return

*END

