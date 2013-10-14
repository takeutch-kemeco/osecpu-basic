/* onbc.stack.c
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

/* スタック構造関連
 * これはプッシュ・ポップだけの単純なスタック構造を提供する。
 * 実際には mem の STACK_BEGIN_ADDRESS 以降のメモリー領域を用いる。
 */

#define STACK_BEGIN_ADDRESS (MEM_SIZE - 0x200000)

/* 任意のレジスターの値をスタックにプッシュする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
void push_stack(const char* regname_data)
{
        write_mem(regname_data, "stack_head");
        pA("stack_head++;");

#ifdef DEBUG_STACK
        pA("junkApi_putConstString('push_stack(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_STACK */
}

/* スタックから任意のレジスターへ値をポップする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
void pop_stack(const char* regname_data)
{
        pA("stack_head--;");
        read_mem(regname_data, "stack_head");

#ifdef DEBUG_STACK
        pA("junkApi_putConstString('pop_stack(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_STACK */
}

/* スタックへのダミープッシュ
 * 実際には値をメモリーへプッシュすることはしないが、ヘッド位置だけを動かす。
 * 実際にダミーデータを用いて push_stack() するよりも軽い。
 */
void push_stack_dummy(void)
{
        pA("stack_head++;");
}

/* スタックからのダミーポップ
 * 実際には値をメモリーからポップすることはしないが、ヘッド位置だけを動かす。
 * 実際にダミーデータを用いて pop_stack() するよりも軽い。
 */
void pop_stack_dummy(void)
{
        pA("stack_head--;");
}

/* スタックの初期化
 */
void init_stack(void)
{
        pA("SInt32 stack_head:R01;");
        pA("SInt32 stack_frame:R02;");
        pA("SInt32 stack_socket:R03;");

        pA("stack_head = %d;", STACK_BEGIN_ADDRESS);
        pA("stack_frame = %d;", STACK_BEGIN_ADDRESS);
}

/* スタック関連の各種レジスターの値を、実行時に画面に印字する
 * 主にデバッグ用
 */
void debug_stack(void)
{
        pA_reg("stack_socket");
        pA_reg("stack_head");
        pA_reg("stack_frame");
}

/* スタックフレームから10個分の内容を、実行時に画面に印字する
 * 主にデバッグ用
 * fixA1, fixA2の値を破壊するので注意
 */
void debug_stack_frame(void)
{
        pA("junkApi_putConstString('debug_stack_frame:');");

        int32_t i;
        for (i = 0; i < 10; i++) {
                pA("fixA1 = stack_frame + %d;", i);
                read_mem("fixA2", "fixA1");

                pA("junkApi_putConstString('[');");
                pA("junkApi_putStringDec('\\1', fixA2, 11, 1);");
                pA("junkApi_putConstString(']');");
        }

        pA("junkApi_putConstString('\\n');");
}
