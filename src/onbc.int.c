/* onbc.int.c
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

/* int 型用アキュムレーター
 * 加算、減算、乗算、除算、余り算、符号反転、
 * AND, OR, XOR, ビット反転, NOT,
 * 左シフト、算術右シフト
 */

/* int同士での加算命令を出力する
 * fixL + fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_add_int(void)
{
        pA("fixA = fixL + fixR;");
}

/* int同士での減算命令を出力する
 * fixL - fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_sub_int(void)
{
        pA("fixA = fixL - fixR;");
}

/* int同士での乗算命令を出力する
 * fixL * fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_mul_int(void)
{
        pA("fixA = fixL * fixR;");
}

/* int同士での除算命令を出力する
 * fixL / fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_div_int(void)
{
        pA("fixA = fixL / fixR;");
}

/* int同士での余り算命令を出力する
 * fixL MOD fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_mod_int(void)
{
        pA("fixA = fixL % fixR;");
}

/* intの符号反転命令を出力する
 * -fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_minus_int(void)
{
        pA("fixA = -fixL;");
}

/* int同士でのAND命令を出力する
 * fixL AND fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_and_int(void)
{
        pA("fixA = fixL & fixR;");
}

/* int同士でのOR命令を出力する
 * fixL OR fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_or_int(void)
{
        pA("fixA = fixL | fixR;");
}

/* int同士でのXOR命令を出力する
 * fixL XOR fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_xor_int(void)
{
        pA("fixA = fixL ^ fixR;");
}

/* intのビット反転命令を出力する
 * ~fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_invert_int(void)
{
        pA("fixA = fixL ^ (-1);");
}

/* intの左シフト命令を出力する
 * fixL << fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
void __func_lshift_int(void)
{
        pA("fixA = fixL << fixR;");
}

/* intの右シフト命令を出力する（算術シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 算術シフトとして動作する。
 */
void __func_arithmetic_rshift_int(void)
{
        pA("if (fixR >= 32) {");
                pA("fixA = 0;");
        pA("} else {");
                pA("if (fixL < 0) {");
                        pA("fixL = ~fixL;");
                        pA("fixL++;");
                        pA("fixL >>= fixR;");
                        pA("fixL = ~fixL;");
                        pA("fixL++;");
                        pA("fixA = fixL;");
                pA("} else {");
                        pA("fixA = fixL >> fixR;");
                pA("}");
        pA("}");
}

/* intの右シフト命令を出力する（論理シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 論理シフトとして動作する。
 */
void __func_logical_rshift_int(void)
{
        pA("if (fixR >= 32) {");
                pA("fixA = 0;");
        pA("} else {");
                pA("if ((fixL < 0) & (fixR >= 1)) {");
                        pA("fixL &= 0x7fffffff;");
                        pA("fixL >>= fixR;");
                        pA("fixR--;");
                        pA("fixA = 0x40000000 >> fixR;");
                        pA("fixA |= fixL;");
                pA("} else {");
                        pA("fixA = fixL >> fixR;");
                pA("}");
        pA("}");
}
