/* onbc.mem.c
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

/* 低レベルなメモリー領域関連
 * これは単純なリード・ライトしか備えていない、システム中での最も低レベルなメモリー領域と、そのIOを提供する。
 * それらリード・ライトがどのような意味を持つかは、呼出側（高レベル側）が各自でルールを決めて運用する。
 *
 * 最終的には、システムで用いるメモリーは、全て、このメモリー領域を利用するように置き換えたい。
 */

#include "onbc.print.h"
#include "onbc.mem.h"

void init_mem(void)
{
        pB("VPtr mem_ptr:P01;");
        pB("junkApi_malloc(mem_ptr, T_SINT32, %d);", MEM_SIZE);
}

void write_mem(const char* regname_data,
               const char* regname_address)
{
        pA("PASMEM0(%s, T_SINT32, mem_ptr, %s);", regname_data, regname_address);
}

void read_mem(const char* regname_data,
              const char* regname_address)
{
        pA("PALMEM0(%s, T_SINT32, mem_ptr, %s);", regname_data, regname_address);
}

/* ヒープメモリーの初期化
 */
void init_heap(void)
{
        pB("SInt32 heap_base:R04;");
        pB("SInt32 heap_socket:R05;");
        pB("SInt32 heap_offset:R06;");
        pB("heap_base = 0;");
};

/* ヒープメモリー関連の各種レジスターの値を、実行時に画面に印字する
 * 主にデバッグ用
 */
void debug_heap(void)
{
        pA("junkApi_putConstString('heap_socket[');");
        pA("junkApi_putStringDec('\\1', heap_socket, 11, 1);");
        pA("junkApi_putConstString('], heap_base[');");
        pA("junkApi_putStringDec('\\1', heap_base, 11, 1);");
        pA("junkApi_putConstString('], heap_offset[');");
        pA("junkApi_putStringDec('\\1', heap_offset, 11, 1);");
        pA("junkApi_putConstString(']\\n');");
}
