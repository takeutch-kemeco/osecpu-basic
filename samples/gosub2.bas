gosub *L0

print 3

goto *END

*L0
print 0
gosub *L1
return

*L1
print 1
gosub *L2
return

*L2
print 2
return

*END
