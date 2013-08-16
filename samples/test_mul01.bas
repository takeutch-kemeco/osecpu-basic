rem 最初と最後が2に成らなければ異常

dim a
a := 2
print a

a := a * 2; a := a * 2; a := a * 2; a := a * 2; a := a * 2; a := a * 2; a := a * 2; a := a * 2;
print a;

a := a * 2; a := a * 2; a := a * 2; a := a * 2; a := a * 2;
print a;

a := a / 2; a := a / 2; a := a / 2; a := a / 2; a := a / 2; a := a / 2; a := a / 2; a := a / 2;
print a

a := a / 2; a := a / 2; a := a / 2; a := a / 2; a := a / 2;
print a
