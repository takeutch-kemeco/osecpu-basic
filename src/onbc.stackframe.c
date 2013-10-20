/* onbc.stackframe.c
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

/* スタックフレームポインターの単純なプッシュ・ポップのみを提供する。
 * すなわち、スタックフレームの位置をプッシュ・ポップするためだけの、専用のスタック。
 * 実際には mem の STACKFRAME_BEGIN_ADDRESS 以降のメモリー領域を用いる。
 */

#define STACKFRAME_BEGIN_ADDRESS (MEM_SIZE - 0x10000)

/* 古いスタックフレームをプッシュし、任意のレジスターの値によって現在のスタックフレームを更新する
 */
void push_stackframe(const char* register_name)
{
        write_mem("stack_frame", "stack_frame_stack_head");
        pA("stack_frame_stack_head++;");
        pA("stack_frame = %d;", register_name);

#ifdef DEBUG_STACKFRAME
        pA_mes("push_stackframe(): ");
        pA_reg("stack_frame_stack_head");
        pA_mes(", ");
        pA_reg("stack_frame");
        pA_mes("\\n");
#endif /* DEBUG_STACKFRAME */
}

/* スタックフレームをポップする
 */
void pop_stackframe(void)
{
        pA("stack_frame_stack_head--;");
        read_mem("stack_frame", "stack_frame_stack_head");

#ifdef DEBUG_STACKFRAME
        pA_mes("push_stackframe(): ");
        pA_reg("stack_frame_stack_head");
        pA_mes(", ");
        pA_reg("stack_frame");
        pA_mes("\\n");
#endif /* DEBUG_STACKFRAME */
}

/* スタックフレームの初期化
 */
void init_stackframe(void)
{
        pA("SInt32 stack_frame_head:R15;");
        pA("SInt32 stack_frame:R02;");

        pA("stack_frame_stack_head = %d;", STACKFRAME_BEGIN_ADDRESS);
        pA("stack_frame = stack_head;");
}
