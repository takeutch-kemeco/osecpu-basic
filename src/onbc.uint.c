/* onbc.uint.c
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
#include "onbc.var.h"
#include "onbc.func.h"

/* uint型用アキュムレーター
 */

/* uint同士での加算命令を出力する
 * lreg + rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_add_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s + %s;", areg, lreg, rreg);
}

/* uint同士での減算命令を出力する
 * lreg - rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_sub_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s - %s;", areg, lreg, rreg);
}

/* uint同士での乗算命令を出力する
 * lreg * rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_mul_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s * %s;", areg, lreg, rreg);
}

/* uint同士での除算命令を出力する
 * lreg / rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_div_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s / %s;", areg, lreg, rreg);
}

/* uint同士での余り算命令を出力する
 * lreg MOD rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_mod_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s %% %s;", areg, lreg, rreg);
}

/* uintの符号反転命令を出力する
 * -lreg -> areg
 * 予め lreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_minus_uint(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("%s = (%s ^ (-1)) + 1;", areg, lreg);
}

/* uint同士でのAND命令を出力する
 * lreg AND rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_and_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s & %s;", areg, lreg, rreg);
}

/* uint同士でのOR命令を出力する
 * lreg OR rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_or_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("%s = %s | %s;", areg, lreg, rreg);
}

/* uint同士でのXOR命令を出力する
 * lreg XOR rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_xor_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s ^ %s;", areg, lreg, rreg);
}

/* uintのビット反転命令を出力する
 * ~lreg -> areg
 * 予め lreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_invert_uint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg)
{
        pA("%s = %s ^ (-1);", areg, lreg);
}

/* uintの左シフト命令を出力する
 * lreg << rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_lshift_uint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg)
{
        pA("%s = %s << %s;", areg, lreg, rreg);
}

/* uintの右シフト命令を出力する（論理シフト）
 * lreg >> rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 *
 * 論理シフトとして動作する。
 */
void __func_rshift_uint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg)
{
        pA("if (%s >= 32) {", rreg);
                pA("%s = 0;", areg);
        pA("} else {");
                pA("if ((%s < 0) & (%s >= 1)) {", lreg, rreg);
                        pA("%s &= 0x7fffffff;", lreg);
                        pA("%s >>= %s;", lreg, rreg);
                        pA("%s--;", rreg);
                        pA("%s = 0x40000000 >> %s;", areg, rreg);
                        pA("%s |= %s;", areg, lreg);
                pA("} else {");
                        pA("%s = %s >> %s;", areg, lreg, rreg);
                pA("}");
        pA("}");
}

void __func_not_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("if (%s != 0) {%s = 0;} else {%s = 1;}", lreg, areg, areg);
}

void __func_eq_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s == %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_ne_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s != %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_lt_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s < %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_gt_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s > %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_le_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s <= %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_ge_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s >= %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}
