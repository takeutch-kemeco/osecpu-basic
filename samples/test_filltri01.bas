#include "stdoscp.bas"
#include "math.bas"
#include "stdgr.bas"

dim col = __torgb(250, 250, 250);
dim ofs;

ofs=100;
__filltri(0, ofs+0, ofs+0, ofs+20, ofs+20, ofs+0, ofs+40, col);

ofs=120;
__filltri(0, ofs+10, ofs+10, ofs+20, ofs+20, ofs+0, ofs+30, col);

ofs=140;
__filltri(0, ofs+10, ofs+10, ofs+20, ofs+20, ofs+15, ofs+30, col);

ofs=260;
__filltri(0, ofs+0, ofs+0, ofs+20, ofs+20, ofs+-10, ofs+40, col);

ofs=300;
__filltri(0, ofs+10, ofs+10, ofs+20, ofs+20, ofs+0, ofs+30, col);

ofs=350;
__filltri(0, ofs+10, ofs+10, ofs+20, ofs+20, ofs+15, ofs+30, col);
