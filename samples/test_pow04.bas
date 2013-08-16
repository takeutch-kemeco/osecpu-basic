rem ２個単位で、各ペア同士がほぼ同じ数にならなければ異常

dim b(10)
b(0) := 1.0
b(1) := -1.23
b(2) := 1.5129
b(3) := -1.860867
b(4) := 2.28886641
b(5) := -2.8153056843
b(6) := 3.462825991688999
b(7) := -4.25927596977747
b(8) := 5.238909442826287
b(9) := -6.443858614676334

dim a
a := -1.23

dim p(10)
p(0):=0
p(1):=1
p(2):=2
p(3):=3
p(4):=4
p(5):=5
p(6):=6
p(7):=7
p(8):=8
p(9):=9

print a^p(0); print b(0)
print a^p(1); print b(1)
print a^p(2); print b(2)
print a^p(3); print b(3)
print a^p(4); print b(4)
print a^p(5); print b(5)
print a^p(6); print b(6)
print a^p(7); print b(7)
print a^p(8); print b(8)
print a^p(9); print b(9)
