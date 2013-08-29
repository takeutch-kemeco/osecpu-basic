dim a[3];
a[0]=0; a[1]= 0; a[2]=3;

dim b[3];
b[0]=3; b[1]= 0; b[2]=3;

dim c[3];
c[0]=3; c[1]= 3; c[2]=3;

dim la[3]; dim lb[3]; dim lc[3];

mat la = b - a;
mat lb = c - b;
mat lc = la * lb;
px(&la);
px(&lb);
px(&lc);

mat la = b - c;
mat lb = a - b;
mat lc = la * lb;
px(&la);
px(&lb);
px(&lc);

function px(x)
{
        dim v[3];
        print x@v[0]; print x@v[1]; print x@v[2];
}
