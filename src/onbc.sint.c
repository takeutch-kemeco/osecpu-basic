/* onbc.sint.c
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

/* sint型用アキュムレーター
 */

/* sint同士での加算命令を出力する
 * lreg + rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_add_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s + %s;", areg, lreg, rreg);
}

/* sint同士での減算命令を出力する
 * lreg - rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_sub_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s - %s;", areg, lreg, rreg);
}

/* sint同士での乗算命令を出力する
 * lreg * rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_mul_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s * %s;", areg, lreg, rreg);
}

/* sint同士での除算命令を出力する
 * lreg / rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_div_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s / %s;", areg, lreg, rreg);
}

/* sint同士での余り算命令を出力する
 * lreg MOD rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_mod_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s %% %s;", areg, lreg, rreg);
}

/* sintの符号反転命令を出力する
 * -lreg -> areg
 * 予め lreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_minus_sint(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("%s = -%s;", areg, lreg);
}

/* sint同士でのAND命令を出力する
 * lreg AND rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_and_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s & %s;", areg, lreg, rreg);
}

/* sint同士でのOR命令を出力する
 * lreg OR rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_or_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("%s = %s | %s;", areg, lreg, rreg);
}

/* sint同士でのXOR命令を出力する
 * lreg XOR rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_xor_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("%s = %s ^ %s;", areg, lreg, rreg);
}

/* sintのビット反転命令を出力する
 * ~lreg -> areg
 * 予め lreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_invert_sint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg)
{
        pA("%s = %s ^ (-1);", areg, lreg);
}

/* sintの左シフト命令を出力する
 * lreg << rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_lshift_sint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg)
{
        pA("%s = %s << %s;", areg, lreg, rreg);
}

/* sintの右シフト命令を出力する（算術シフト）
 * lreg >> rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 *
 * 算術シフトとして動作する。
 */
void __func_rshift_sint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg)
{
        pA("if (%s >= 32) {", rreg);
                pA("%s = 0;", areg);
        pA("} else {");
                pA("if (%s < 0) {", lreg);
                        pA("%s = ~%s;", lreg, lreg);
                        pA("%s++;", lreg);
                        pA("%s >>= %s;", lreg, rreg);
                        pA("%s = ~%s;", lreg, lreg);
                        pA("%s++;", lreg);
                        pA("%s = %s;", areg, lreg);
                pA("} else {");
                        pA("%s = %s >> %s;", areg, lreg, rreg);
                pA("}");
        pA("}");
}

void __func_not_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg)
{
        pA("if (%s != 0) {%s = 0;} else {%s = 1;}", lreg, areg, areg);
}

void __func_eq_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s == %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_ne_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s != %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_lt_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s < %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_gt_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s > %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_le_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s <= %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}

void __func_ge_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg)
{
        pA("if (%s >= %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
}
