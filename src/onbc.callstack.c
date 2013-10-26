/* onbc.callstack.c
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
#include "onbc.callstack.h"

/* 関数呼び出し時のスタック位置をプッシュ・ポップするためだけの、専用のスタック。
 * 実際には mem の CALLSTACK_BEGIN_ADDRESS 以降のメモリー領域を用いる。
 */

/* 任意のレジスターの値をコールスタックへプッシュする
 */
void push_callstack(const char* register_name)
{
        write_mem(register_name, "callstack_head");
        pA("callstack_head++;");

#ifdef DEBUG_CALLSTACK
        pA_mes("push_callstack(): ");
        pA_reg(register_name);
        pA_mes(", ");
        pA_reg("callstack_head");
        pA_mes("\\n");
#endif /* DEBUG_CALLSTACK */
}

/* 任意のレジスターの値へコールスタックからポップする
 */
void pop_callstack(const char* register_name)
{
        pA("callstack_head--;");
        read_mem(register_name, "callstack_head");

#ifdef DEBUG_CALLSTACK
        pA_mes("pop_callstack(): ");
        pA_reg(register_name);
        pA_mes(", ");
        pA_reg("callstack_head");
        pA_mes("\\n");
#endif /* DEBUG_CALLSTACK */
}

/* コールスタックの初期化
 */
void init_callstack(void)
{
        pA("SInt32 callstack_head:R20;");

        pA("callstack_head = %d;", CALLSTACK_BEGIN_ADDRESS);
}
