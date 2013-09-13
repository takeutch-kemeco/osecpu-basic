#include "stdoscp.bas"
#include "math.bas"
#include "matrix.bas"

dim scw=480, sch=240;
dim pool[10000], m[3,3], v[3], rd=3.14159265358979/180;
dim vt[8]; vt[0]=100>>16; vt[1]=104>>16; vt[2]=108>>16; vt[3]=112>>16;
           vt[4]=116>>16; vt[5]=120>>16; vt[6]=124>>16; vt[7]=128>>16;
dim vtx[8]; vtx[0]=160>>16; vtx[1]=164>>16; vtx[2]=168>>16; vtx[3]=172>>16;
            vtx[4]=176>>16; vtx[5]=180>>16; vtx[6]=184>>16; vtx[7]=188>>16;
dim rv[3]; rv[0]=0; rv[1]=0; rv[2]=0;
dim rvd[3]; rvd[0]=rd*0.5; rvd[1]=rd*1.0; rvd[2]=rd*1.5;
vt[0]@v[0]=-22; vt[0]@v[1]=-22; vt[0]@v[2]=-22; vt[1]@v[0]=+22; vt[1]@v[1]=-22; vt[1]@v[2]=-22;
vt[2]@v[0]=+22; vt[2]@v[1]=+22; vt[2]@v[2]=-22; vt[3]@v[0]=-22; vt[3]@v[1]=+22; vt[3]@v[2]=-22;
vt[4]@v[0]=-22; vt[4]@v[1]=-22; vt[4]@v[2]=+22; vt[5]@v[0]=+22; vt[5]@v[1]=-22; vt[5]@v[2]=+22;
vt[6]@v[0]=+22; vt[6]@v[1]=+22; vt[6]@v[2]=+22; vt[7]@v[0]=-22; vt[7]@v[1]=+22; vt[7]@v[2]=+22;

__openwin(scw, sch);

*LLL;
        mat rv = rv + rvd;

        dim mx[3,3], my[3,3], mz[3,3], mt[3,3], rm[3,3];
        rot_x_matrix3(&mx, rv[0]);
        rot_y_matrix3(&my, rv[1]);
        rot_z_matrix3(&mz, rv[2]);
        mul_matrix3(&mt, &mz, &my);
        mul_matrix3(&rm, &mt, &mx);

        dim prj=200, tz=100;
        dim ov[3]; ov[0]=scw/2; ov[1]=sch/2; ov[2]=0;
        dim i;
        for (i = 0; i < 8; i= i + 1) {
                mul_m3v3(vtx[i], &rm, vt[i]);
                scale_vector3(vtx[i], prj * (1 / (vtx[i]@v[2] + tz)));
                add_vector3(vtx[i], vtx[i], &ov);
        }

        draw_W4(vtx[0], vtx[1], vtx[2], vtx[3], (torgb 255 0 0));   /* 0 1 2 3 */
        draw_W4(vtx[4], vtx[5], vtx[6], vtx[7], (torgb 0 255 0));   /* 4 5 6 7 */
        draw_W4(vtx[4], vtx[5], vtx[1], vtx[0], (torgb 0 0 255));   /* 4 5 1 0 */
        draw_W4(vtx[5], vtx[6], vtx[2], vtx[1], (torgb 255 255 0)); /* 4 5 2 1 */
        draw_W4(vtx[6], vtx[7], vtx[3], vtx[2], (torgb 0 255 255)); /* 6 7 3 2 */
        draw_W4(vtx[7], vtx[4], vtx[0], vtx[3], (torgb 255 0 255)); /* 7 4 0 3 */

        __sleep(0, 16);

        __fillrect(0, scw, sch, 0, 0, (torgb 100 140 180));
goto *LLL;

function draw_W4(v0, v1, v2, v3, col)
{
#ifdef ZERO
        mat va = v1@v - v0@v;
        mat vb = v2@v - v1@v;
        mat va = va * vb;
        if (va[2] >= 0)
#endif
        {
                __drawline(0, v0@v[0], v0@v[1], v1@v[0], v1@v[1], col);
                __drawline(0, v1@v[0], v1@v[1], v2@v[0], v2@v[1], col);
                __drawline(0, v2@v[0], v2@v[1], v3@v[0], v3@v[1], col);
                __drawline(0, v3@v[0], v3@v[1], v0@v[0], v0@v[1], col);
        }
}
