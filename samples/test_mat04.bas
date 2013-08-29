dim a[3,3];
a[0,0]=0;  a[0,1]=1;  a[0,2]=2;
a[1,0]=10; a[1,1]=11; a[1,2]=12;
a[2,0]=20; a[2,1]=21; a[2,2]=22;

dim b[3];
b[0]=10; b[1]= 20; b[2]=30;

dim c = 10;
dim ic = 1 / c;

pa();
mat a = c * a;
pa();
mat a = ic * a;
pa();

pb();
mat b = c * b;
pb();
mat b = ic * b;
pb();

function pa()
{
        print a[0,0]; print a[0,1]; print a[0,2];
        print a[1,0]; print a[1,1]; print a[1,2];
        print a[2,0]; print a[2,1]; print a[2,2];
}

function pb()
{
        print b[0]; print b[1]; print b[2];
}
