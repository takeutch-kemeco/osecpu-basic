dim scw=480, sch=240;
dim ot[8192,10];
dim pool[1000], m[3,3], v[3], rd=3.14159265358979/180;
dim vt[8]; vt[0]=100>>16; vt[1]=104>>16; vt[2]=108>>16; vt[3]=112>>16;
           vt[4]=116>>16; vt[5]=120>>16; vt[6]=124>>16; vt[7]=128>>16;
dim vtx[8]; vtx[0]=160>>16; vtx[1]=164>>16; vtx[2]=168>>16; vtx[3]=172>>16;
            vtx[4]=176>>16; vtx[5]=180>>16; vtx[6]=184>>16; vtx[7]=188>>16;
dim vts[8]; vts[0]=360>>16; vts[1]=364>>16; vts[2]=368>>16; vts[3]=372>>16;
            vts[4]=376>>16; vts[5]=380>>16; vts[6]=384>>16; vts[7]=388>>16;
dim rm[5]; rm[0]=200>>16; rm[1]=220>>16; rm[2]=240>>16; rm[3]=260>>16; rm[4]=280>>16;
dim rv[3]; rv[0]=0; rv[1]=0; rv[2]=0;
dim rvd[3]; rvd[0]=rd*0.5; rvd[1]=rd*1.0; rvd[2]=rd*1.5;
vt[0]@v[0]=-22; vt[0]@v[1]=-22; vt[0]@v[2]=-22; vt[1]@v[0]=+22; vt[1]@v[1]=-22; vt[1]@v[2]=-22;
vt[2]@v[0]=+22; vt[2]@v[1]=+22; vt[2]@v[2]=-22; vt[3]@v[0]=-22; vt[3]@v[1]=+22; vt[3]@v[2]=-22;
vt[4]@v[0]=-22; vt[4]@v[1]=-22; vt[4]@v[2]=+22; vt[5]@v[0]=+22; vt[5]@v[1]=-22; vt[5]@v[2]=+22;
vt[6]@v[0]=+22; vt[6]@v[1]=+22; vt[6]@v[2]=+22; vt[7]@v[0]=-22; vt[7]@v[1]=+22; vt[7]@v[2]=+22;

openwin scw sch;

*LLL;
        mat rv = rv + rvd;

        dim rs, rc;
        mat rm[0]@m=idn; rs=sin rv[0]; rc=cos rv[0]; rm[0]@m[1,1]=rc; rm[0]@m[1,2]=-rs; rm[0]@m[2,1]= rs; rm[0]@m[2,2]=rc;
        mat rm[1]@m=idn; rs=sin rv[1]; rc=cos rv[1]; rm[1]@m[0,0]=rc; rm[1]@m[0,2]= rs; rm[1]@m[2,0]=-rs; rm[1]@m[2,2]=rc;
        mat rm[2]@m=idn; rs=sin rv[2]; rc=cos rv[2]; rm[2]@m[0,0]=rc; rm[2]@m[0,1]=-rs; rm[2]@m[1,0]= rs; rm[2]@m[1,1]=rc;

        mat rm[3]@m=rm[0]@m * rm[1]@m; mat rm[4]@m=rm[3]@m * rm[2]@m;

        mat vtx[0]@v=rm[4]@m * vt[0]@v; mat vtx[1]@v=rm[4]@m * vt[1]@v;
        mat vtx[2]@v=rm[4]@m * vt[2]@v; mat vtx[3]@v=rm[4]@m * vt[3]@v;
        mat vtx[4]@v=rm[4]@m * vt[4]@v; mat vtx[5]@v=rm[4]@m * vt[5]@v;
        mat vtx[6]@v=rm[4]@m * vt[6]@v; mat vtx[7]@v=rm[4]@m * vt[7]@v;

        dim prj=200, tz=100, iz;
        iz=prj * (1/(vtx[0]@v[2] + tz)); mat vts[0]@v = iz * vtx[0]@v;
        iz=prj * (1/(vtx[1]@v[2] + tz)); mat vts[1]@v = iz * vtx[1]@v;
        iz=prj * (1/(vtx[2]@v[2] + tz)); mat vts[2]@v = iz * vtx[2]@v;
        iz=prj * (1/(vtx[3]@v[2] + tz)); mat vts[3]@v = iz * vtx[3]@v;
        iz=prj * (1/(vtx[4]@v[2] + tz)); mat vts[4]@v = iz * vtx[4]@v;
        iz=prj * (1/(vtx[5]@v[2] + tz)); mat vts[5]@v = iz * vtx[5]@v;
        iz=prj * (1/(vtx[6]@v[2] + tz)); mat vts[6]@v = iz * vtx[6]@v;
        iz=prj * (1/(vtx[7]@v[2] + tz)); mat vts[7]@v = iz * vtx[7]@v;

        dim ov[3]; ov[0]=scw/2; ov[1]=sch/2; ov[2]=0;
        mat vts[0]@v=vts[0]@v+ov; mat vts[1]@v=vts[1]@v+ov; mat vts[2]@v=vts[2]@v+ov; mat vts[3]@v=vts[3]@v+ov;
        mat vts[4]@v=vts[4]@v+ov; mat vts[5]@v=vts[5]@v+ov; mat vts[6]@v=vts[6]@v+ov; mat vts[7]@v=vts[7]@v+ov;

        dim col, va[3], vb[3];
        /* init_ot(); */

/* 0 1 2 3 */
        col=torgb 255 0 0;
        mat va=vtx[1]@v - vtx[0]@v; mat vb=vtx[2]@v - vtx[1]@v; mat va=va * vb;
        if (va[2]>=0) filltri 0 vts[0]@v[0] vts[0]@v[1] vts[1]@v[0] vts[1]@v[1] vts[2]@v[0] vts[2]@v[1] col;
        if (va[2]>=0) filltri 0 vts[2]@v[0] vts[2]@v[1] vts[3]@v[0] vts[3]@v[1] vts[0]@v[0] vts[0]@v[1] col;

/* 4 5 6 7 */
        col=torgb 0 255 0;
        mat va=vtx[4]@v - vtx[5]@v; mat vb=vtx[6]@v - vtx[5]@v; mat va=va * vb;
        if (va[2]>=0) filltri 0 vts[4]@v[0] vts[4]@v[1] vts[5]@v[0] vts[5]@v[1] vts[6]@v[0] vts[6]@v[1] col;
        if (va[2]>=0) filltri 0 vts[6]@v[0] vts[6]@v[1] vts[7]@v[0] vts[7]@v[1] vts[4]@v[0] vts[4]@v[1] col;

/* 4 5 1 0 */
        col=torgb 0 0 255;
        mat va=vtx[5]@v - vtx[4]@v; mat vb=vtx[1]@v - vtx[5]@v; mat va=va * vb;
        if (va[2]>=0) filltri 0 vts[4]@v[0] vts[4]@v[1] vts[5]@v[0] vts[5]@v[1] vts[1]@v[0] vts[1]@v[1] col;
        if (va[2]>=0) filltri 0 vts[1]@v[0] vts[1]@v[1] vts[0]@v[0] vts[0]@v[1] vts[4]@v[0] vts[4]@v[1] col;

/* 5 6 2 1 */
        col=torgb 255 255 0;
        mat va=vtx[6]@v - vtx[5]@v; mat vb=vtx[2]@v - vtx[6]@v; mat va=va * vb;
        if (va[2]>=0) filltri 0 vts[5]@v[0] vts[5]@v[1] vts[6]@v[0] vts[6]@v[1] vts[2]@v[0] vts[2]@v[1] col;
        if (va[2]>=0) filltri 0 vts[2]@v[0] vts[2]@v[1] vts[1]@v[0] vts[1]@v[1] vts[5]@v[0] vts[5]@v[1] col;

/* 6 7 3 2 */
        col=torgb 0 255 255;
        mat va=vtx[7]@v - vtx[6]@v; mat vb=vtx[3]@v - vtx[7]@v; mat va=va * vb;
        if (va[2]>=0) filltri 0 vts[6]@v[0] vts[6]@v[1] vts[7]@v[0] vts[7]@v[1] vts[3]@v[0] vts[3]@v[1] col;
        if (va[2]>=0) filltri 0 vts[3]@v[0] vts[3]@v[1] vts[2]@v[0] vts[2]@v[1] vts[6]@v[0] vts[6]@v[1] col;

/* 7 4 0 3 */
        col=torgb 255 0 255;
        mat va=vtx[4]@v - vtx[7]@v; mat vb=vtx[0]@v - vtx[4]@v; mat va=va * vb;
        if (va[2]>=0) filltri 0 vts[7]@v[0] vts[7]@v[1] vts[4]@v[0] vts[4]@v[1] vts[0]@v[0] vts[0]@v[1] col;
        if (va[2]>=0) filltri 0 vts[0]@v[0] vts[0]@v[1] vts[3]@v[0] vts[3]@v[1] vts[7]@v[0] vts[7]@v[1] col;

        sleep 0 16;

        col=torgb 100 140 180;
        fillrect 0  scw sch 0 0 col;
goto *LLL;

function init_ot()
{
        dim i;
        for (i = 0; i < 8192; i = i + 1) {
                ot[i,0] = -1;
                print ot[i,0];
        }
}
