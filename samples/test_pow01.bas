#include "stdoscp.bas"
#include "math.bas"

/* ２個単位で、各ペア同士がほぼ同じ数にならなければ異常
 */

dim b[10];
b[0]=1.306098342927648;
b[1]=1.388833969910399;
b[2]=1.497820969846338;
b[3]=1.643673998391485;
b[4]=1.842694300541299;
b[5]=2.120838261848281;
b[6]=2.521182513852888;
b[7]=3.118697643980291;
b[8]=4.051232096606508;
b[9]=5.588974955097326;

dim a = 1.23;

__print(__pow(1.23, a)); __print(b[0]);
__print(__pow(b[0], a)); __print(b[1]);
__print(__pow(b[1], a)); __print(b[2]);
__print(__pow(b[2], a)); __print(b[3]);
__print(__pow(b[3], a)); __print(b[4]);
__print(__pow(b[4], a)); __print(b[5]);
__print(__pow(b[5], a)); __print(b[6]);
__print(__pow(b[6], a)); __print(b[7]);
__print(__pow(b[7], a)); __print(b[8]);
__print(__pow(b[8], a)); __print(b[9]);
