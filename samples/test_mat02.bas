dim a[4,3];
dim b[3,4];

a[0,0]=0;  a[0,1]=1;  a[0,2]=2;
a[1,0]=10; a[1,1]=11; a[1,2]=12;
a[2,0]=20; a[2,1]=21; a[2,2]=22;
a[3,0]=30; a[3,1]=31; a[3,2]=32;
pa();

mat b = trn(a);
pb();

function pa()
{
        print a[0,0]; print a[0,1]; print a[0,2];
        print a[1,0]; print a[1,1]; print a[1,2];
        print a[2,0]; print a[2,1]; print a[2,2];
        print a[3,0]; print a[3,1]; print a[3,2];
}

function pb()
{
        print b[0,0]; print b[0,1]; print b[0,2]; print b[0,3];
        print b[1,0]; print b[1,1]; print b[1,2]; print b[1,3];
        print b[2,0]; print b[2,1]; print b[2,2]; print b[2,3];
}
