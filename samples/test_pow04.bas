#include "stdoscp.bas"
#include "math.bas"

/* ２個単位で、各ペア同士がほぼ同じ数にならなければ異常
 */

dim b[10];
b[0] = 1.0;
b[1] = -1.23;
b[2] = 1.5129;
b[3] = -1.860867;
b[4] = 2.28886641;
b[5] = -2.8153056843;
b[6] = 3.462825991688999;
b[7] = -4.25927596977747;
b[8] = 5.238909442826287;
b[9] = -6.443858614676334;

dim a = -1.23;

dim p[10];
p[0]=0;
p[1]=1;
p[2]=2;
p[3]=3;
p[4]=4;
p[5]=5;
p[6]=6;
p[7]=7;
p[8]=8;
p[9]=9;

__print(__pow(a, p[0])); __print(b[0]);
__print(__pow(a, p[1])); __print(b[1]);
__print(__pow(a, p[2])); __print(b[2]);
__print(__pow(a, p[3])); __print(b[3]);
__print(__pow(a, p[4])); __print(b[4]);
__print(__pow(a, p[5])); __print(b[5]);
__print(__pow(a, p[6])); __print(b[6]);
__print(__pow(a, p[7])); __print(b[7]);
__print(__pow(a, p[8])); __print(b[8]);
__print(__pow(a, p[9])); __print(b[9]);
