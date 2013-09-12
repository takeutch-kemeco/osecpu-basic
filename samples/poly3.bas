#include "stdoscp.bas"
#include "math.bas"

dim scw=480, sch=240;
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

__openwin(scw, sch);

*LLL;
        mat rv = rv + rvd;

        dim rs, rc;
        mat rm[0]@m=idn; rs=__sin(rv[0]); rc=__cos(rv[0]); rm[0]@m[1,1]=rc; rm[0]@m[1,2]=-rs; rm[0]@m[2,1]= rs; rm[0]@m[2,2]=rc;
        mat rm[1]@m=idn; rs=__sin(rv[1]); rc=__cos(rv[1]); rm[1]@m[0,0]=rc; rm[1]@m[0,2]= rs; rm[1]@m[2,0]=-rs; rm[1]@m[2,2]=rc;
        mat rm[2]@m=idn; rs=__sin(rv[2]); rc=__cos(rv[2]); rm[2]@m[0,0]=rc; rm[2]@m[0,1]=-rs; rm[2]@m[1,0]= rs; rm[2]@m[1,1]=rc;

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

        draw_F4(vts[0], vts[1], vts[2], vts[3], (torgb 255 0 0));   /* 0 1 2 3 */
        draw_F4(vts[4], vts[5], vts[6], vts[7], (torgb 0 255 0));   /* 4 5 6 7 */
        draw_F4(vts[4], vts[5], vts[1], vts[0], (torgb 0 0 255));   /* 4 5 1 0 */
        draw_F4(vts[5], vts[6], vts[2], vts[1], (torgb 255 255 0)); /* 4 5 2 1 */
        draw_F4(vts[6], vts[7], vts[3], vts[2], (torgb 0 255 255)); /* 6 7 3 2 */
        draw_F4(vts[7], vts[4], vts[0], vts[3], (torgb 255 0 255)); /* 7 4 0 3 */

        __sleep(0, 16);

        col=torgb 100 140 180;
        __fillrect(0, scw, sch, 0, 0, col);
goto *LLL;

function draw_F3(v0, v1, v2, col)
{
#ifdef ZERO
        mat va = v1@v - v0@v;
        mat vb = v2@v - v1@v;
        mat va = va * vb;
        if (va[2] >= 0)
#endif
                filltri 0 v0@v[0] v0@v[1] v1@v[0] v1@v[1] v2@v[0] v2@v[1] col;
}

function draw_F4(v0, v1, v2, v3, col)
{
        draw_F3(v0, v1, v2, col);
        draw_F3(v2, v3, v0, col);
}
