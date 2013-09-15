#include "stdoscp.bas"
#include "math.bas"

/* 0以外の数が出たら異常
 * あと最後がエラーじゃない場合も異常
 */

__print(__pow(0, 1));
__print(__pow(0, 20));

__print(__pow(0, 1.23));
__print(__pow(0, 23.456));

__print(__pow(0, 0));
