#include "stdoscp.bas"
#include "math.bas"

/* 計算できてしまった場合は異常。（エラーになれば正常）
 */

dim b[10];
b[0]=0.7752052636746;
b[1]=1.367783760452783;
b[2]=0.68029698307444;
b[3]=1.606130353346137;
b[4]=0.55832828356212;
b[5]=2.04798021480726;
b[6]=0.41406576005335;
b[7]=2.958044732686664;
b[8]=0.26342935780978;
b[9]=5.159208352468288;

dim a = 1.23;

__print(__pow(a, (-1.23))); __print(b[0]);
__print(__pow(a, b[0])); __print(b[1]);
__print(__pow(a, b[1])); __print(b[2]);
__print(__pow(a, b[2])); __print(b[3]);
__print(__pow(a, b[3])); __print(b[4]);
__print(__pow(a, b[4])); __print(b[5]);
__print(__pow(a, b[5])); __print(b[6]);
__print(__pow(a, b[6])); __print(b[7]);
__print(__pow(a, b[7])); __print(b[8]);
__print(__pow(a, b[8])); __print(b[9]);
