dim a[3,3];
dim b[3,3];
dim c[3,3];

a[0,0]=0;  a[0,1]=1;  a[0,2]=2;
a[1,0]=10; a[1,1]=11; a[1,2]=12;
a[2,0]=20; a[2,1]=21; a[2,2]=22;

mat b = idn;
b[0,0] = 0;
b[2,2] = 0;

dim i;
for (i = 0; i < 1000000; i = i + 1)
        mat c = a * b;

mat c = a * b;
pc();

function pc()
{
        print c[0,0]; print c[0,1]; print c[0,2];
        print c[1,0]; print c[1,1]; print c[1,2];
        print c[2,0]; print c[2,1]; print c[2,2];
}
