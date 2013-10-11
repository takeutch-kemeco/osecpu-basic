/* onbc.eoe.c
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
#include "onbc.stack.h"
#include "onbc.func.h"

/* <expression> <OPE_?> <expression> の状態から、左右の <expression> の値をそれぞれ fixL, fixR へ読み込む
 */
void read_eoe_arg(void)
{
        pop_stack("fixR");
        pop_stack("fixL");
}

/* eoe用レジスタをスタックへプッシュする
 */
void push_eoe(void)
{
        beginF();

        push_stack("fixL");
        push_stack("fixR");
        push_stack("fixLx");
        push_stack("fixRx");
        push_stack("fixS");
        push_stack("fixT");
        push_stack("fixT1");
        push_stack("fixT2");
        push_stack("fixT3");
        push_stack("fixT4");

        endF();
}

/* eoe用レジスタをスタックからポップする
 */
void pop_eoe(void)
{
        beginF();

        pop_stack("fixT4");
        pop_stack("fixT3");
        pop_stack("fixT2");
        pop_stack("fixT1");
        pop_stack("fixT");
        pop_stack("fixS");
        pop_stack("fixRx");
        pop_stack("fixLx");
        pop_stack("fixR");
        pop_stack("fixL");

        endF();
};

void debug_eoe(void)
{
        pA("junkApi_putConstString('\\nfixL:');");
        pA("junkApi_putStringDec('\\1', fixL, 11, 1);");
        pA("junkApi_putConstString(' fixR:');");
        pA("junkApi_putStringDec('\\1', fixR, 11, 1);");
        pA("junkApi_putConstString(' fixLx:');");
        pA("junkApi_putStringDec('\\1', fixLx, 11, 1);");
        pA("junkApi_putConstString(' fixRx:');");
        pA("junkApi_putStringDec('\\1', fixRx, 11, 1);");
        pA("junkApi_putConstString(' fixT:');");
        pA("junkApi_putStringDec('\\1', fixT, 11, 1);");
        pA("junkApi_putConstString(' fixT1:');");
        pA("junkApi_putStringDec('\\1', fixT1, 11, 1);");
        pA("junkApi_putConstString(' fixT2:');");
        pA("junkApi_putStringDec('\\1', fixT2, 11, 1);");
        pA("junkApi_putConstString(' fixT3:');");
        pA("junkApi_putStringDec('\\1', fixT3, 11, 1);");
        pA("junkApi_putConstString(' fixT4:');");
        pA("junkApi_putStringDec('\\1', fixT4, 11, 1);");
        pA("junkApi_putConstString(' fixS:');");
        pA("junkApi_putStringDec('\\1', fixS, 11, 1);");
        pA("junkApi_putConstString(' fixA:');");
        pA("junkApi_putStringDec('\\1', fixA, 11, 1);");
        pA("junkApi_putConstString(' fixA1:');");
        pA("junkApi_putStringDec('\\1', fixA1, 11, 1);");
        pA("junkApi_putConstString(' fixA2:');");
        pA("junkApi_putStringDec('\\1', fixA2, 11, 1);");
        pA("junkApi_putConstString(' fixA3:');");
        pA("junkApi_putStringDec('\\1', fixA3, 11, 1);");
        pA("junkApi_putConstString('\\n');");
}

/* read_eoe_arg 用変数の初期化
 *
 * push_eoe(), pop_eoe() ともに、例外として fixA スタックへ退避しない。
 * この fixA は eoe 間で値を受け渡しする為に用いるので、push_eoe(), pop_eoe() に影響されないようにしてある。
 * （push後に行った演算の結果をfixAに入れておくことで、その後にpopした後でも演算結果を引き継げるように）
 *
 * fixA1 ～ fixA3 も、 fixA 同様に戻り値の受け渡しに使える。
 */
void init_eoe_arg(void)
{
        pA("SInt32 fixA:R07;");
        pA("SInt32 fixL:R08;");
        pA("SInt32 fixR:R09;");
        pA("SInt32 fixLx:R0A;");
        pA("SInt32 fixRx:R0B;");
        pA("SInt32 fixS:R0C;");
        pA("SInt32 fixT:R0D;");
        pA("SInt32 fixT1:R0E;");
        pA("SInt32 fixT2:R0F;");
        pA("SInt32 fixT3:R10;");
        pA("SInt32 fixT4:R11;");
        pA("SInt32 fixA1:R12;");
        pA("SInt32 fixA2:R13;");
        pA("SInt32 fixA3:R14;");
}
