dim a(10)
(100 >> 16)<-a(5):=123
print (100>>16)<-a(5)

if (100>>16)<-a(5) = 123 then print 1; else print 2;
if a(5) = 123 then print 1; else print 2;
