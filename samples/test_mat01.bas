dim a[3,3];
dim b[3,3];

a[0,0]=0;  a[0,1]=1;  a[0,2]=2;
a[1,0]=10; a[1,1]=11; a[1,2]=12;
a[2,0]=20; a[2,1]=21; a[2,2]=22;

mat b = a;

mat b = zer;
pb();

mat b = con;
pb();

mat b = a + b;
pb();

mat b = con;
pb();

mat b = a - b;
pb();

mat b = 10 * con;
pb();

mat b = idn;
pb();

function pb()
{
        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = 0; i < 3; i = i + 1) {
                        print b[j,i];
                }
        }
}
