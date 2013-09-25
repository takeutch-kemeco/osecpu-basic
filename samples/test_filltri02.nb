#include "stdoscp.bas"
#include "math.bas"
#include "stdgr.bas"

float rm[3][3];
float rv[3];

float v0[3]; v0[0] = 10; v0[1] = 12; v0[2] = 0;
float v1[3]; v1[0] = 10; v1[1] = -2;  v1[2] = 0;
float v2[3]; v2[0] = 0;  v2[1] = -2;  v2[2] = 0;
float ofs[3]; ofs[0] = 100; ofs[1] = 100; ofs[2] = 0;
float v0t[3], v1t[3], v2t[3];

while (1) {
        rv[2] = rv[2] + 0.05;
        rot_matrix3(&rm, &rv);
        mul_m3v3(&v0t, &rm, &v0);
        mul_m3v3(&v1t, &rm, &v1);
        mul_m3v3(&v2t, &rm, &v2);
        add_vector3(&v0t, &v0t, &ofs);
        add_vector3(&v1t, &v1t, &ofs);
        add_vector3(&v2t, &v2t, &ofs);
        __filltri(0, v0t[0], v0t[1], v1t[0], v1t[1], v2t[0], v2t[1], __torgb(250, 250, 250));
        __sleep(0, 16);
        __fillrect(0, 640, 480, 0, 0, 0);
}
