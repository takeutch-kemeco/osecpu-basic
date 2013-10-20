/* onbc.windstack.c
 * Copyright (C) 2013 Takeutch Kemeco
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include "onbc.print.h"
#include "onbc.mem.h"
#include "onbc.windstack.h"

/* 関数呼び出し時にスタックに積まれる各引数のアドレスをスタックするための機構を提供する。
 * すなわち、各引数の実際の値の位置をプッシュ・ポップするためだけの、専用のスタック。
 * 実際には mem の WINDSTACK_BEGIN_ADDRESS 以降のメモリー領域を用いる。
 */

/* 任意のレジスターの値をワインドスタックにプッシュする。
 * 実際にはレジスターの値には引数のアドレスが入っている想定。
 */
void push_windstack(const char* register_name)
{
        write_mem(register_name, "windstack_head");
        pA("windstack_head++;");

#ifdef DEBUG_WINDSTACK
        pA_mes("push_windstack(): ");
        pA_reg("windstack_head");
        pA_mes(", ");
        pA_reg(register_name);
        pA_mes("\\n");
#endif /* DEBUG_WINDSTACK */
}

/* 任意のレジスターへワインドスタックからポップする。
 * 実際にはレジスターへは引数のアドレスが入る想定。（プッシュしたのが正しく引数アドレスであれば）
 */
void pop_windstack(const char* register_name)
{
        pA("windstack_head--;");
        read_mem(register_name, "windstack_head");

#ifdef DEBUG_WINDSTAC
        pA_mes("pop_windstack(): ");
        pA_reg("windstack_head");
        pA_mes(", ");
        pA_reg(register_name);
        pA_mes("\\n");
#endif /* DEBUG_WINDSTACK */
}

/* ワインドスタックの初期化
 */
void init_windstack(void)
{
        pA("SInt32 windstack_head:R16;");

        pA("windstack_head = %d;", WINDSTACK_BEGIN_ADDRESS);
}
