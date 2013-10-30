/* onbc.double.c
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

/* double型用アキュムレーター
 *
 * 実際は1:15:16の固定小数
 */

/* double同士での加算命令を出力する
 * lreg + rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_add_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("%s = %s + %s;", areg, lreg, rreg);
}

/* double同士での減算命令を出力する
 * lreg - rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_sub_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("%s = %s - %s;", areg, lreg, rreg);
}

/* double同士での乗算命令を出力する(内部処理のモジュール化用)
 * fixL * fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mul_double_module(void)
{
        /* 符号を保存しておき、+へ変換する*/
        pA("fixS = 0;");
        pA("if (fixL < 0) {fixL = -fixL; fixS |= 1;}");
        pA("if (fixR < 0) {fixR = -fixR; fixS |= 2;}");

        pA("fixRx = (fixR & 0xffff0000) >> 16;");
        pA("fixLx = (fixL & 0xffff0000);");

        pA("fixR = fixR & 0x0000ffff;");
        pA("fixL = fixL & 0x0000ffff;");

        pA("fixA = "
           "(((fixL >> 1) * fixR) >> 15) + "
           "((fixLx >> 16) * fixR) + "
           "(fixLx * fixRx) + "
           "(fixL * fixRx);");

        /* 符号を元に戻す
         * fixS の値は、 & 0x00000003 した状態と同様の値のみである前提
         */
        pA("if ((fixS == 0x00000001) | (fixS == 0x00000002)) {fixA = -fixA;}");
}

/* double同士での乗算命令を出力する
 * lreg * rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 *
 * この演算をインライン展開すると容量を消費しすぎるので、モジュール化して呼び出すようにしてある。
 * その為、レジスターの自由度に制約がある。
 * lreg = fixL, rreg = fixR, areg = fixA の整合性を意識してレジスターを選択すべき。
 * 通常はこのレジスターセットで受け渡しするのが無難。
 */
void __func_mul_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("fixL = %s;", lreg);
        pA("fixR = %s;", rreg);

        beginF();

        __func_mul_double_module();

        endF();

        pA("%s = fixA;", areg);
}

/* double同士での除算命令を出力する
 * lreg / rreg -> areg
 * 予め lreg, rreg に値をセットしておくこと。 演算結果は areg へ出力される。
 *
 * 内部的に __func_mul_double_module() を用いてる関係で、レジスターの自由度に制約がある。
 * lreg = fixL, rreg = fixR, areg = fixA の整合性を意識してレジスターを選択すべき。
 * 通常はこのレジスターセットで受け渡しするのが無難。
 */
void __func_div_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("fixL = %s;", lreg);
        pA("fixR = %s;", rreg);

        beginF();

        /* R の逆数を得る
         *
         * （通常は 0x00010000 を 1 と考えるが、）
         * 0x40000000 を 1 と考えると、通常との差は << 14 なので、
         * 0x40000000 / R の結果も << 14 に対する演算結果として得られ、
         * （除算の場合は単位分 >> するので（すなわち >> 16））、
         * したがって結果を << 2 すれば（16 - 14 = 2だから） 0x00010000 を 1 とした場合での値となるはず。
         */

        /* 絶対に0除算が起きないように、0ならば最小数に置き換えてから除算 */
        pA("if (fixR == 0) {fixR = 1;}");
        pA("fixRx = 0x40000000 / fixR;");

        pA("fixR = fixRx << 2;");

        /* 逆数を乗算することで除算とする */
        __func_mul_double_module();

        endF();

        pA("%s = fixA;", areg);
}

/* double同士での符号付き剰余命令を出力する
 * lreg MOD fixR -> fixA
 * 予め lreg, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 内部的に __func_mul_double_module() を用いてる関係で、レジスターの自由度に制約がある。
 * lreg = fixL, rreg = fixR, areg = fixA の整合性を意識してレジスターを選択すべき。
 * 通常はこのレジスターセットで受け渡しするのが無難。
 */
void __func_mod_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("fixL = %s;", lreg);
        pA("fixR = %s;", rreg);

        beginF();

        /* 符号付き剰余
         */

        /* fixL, fixR それぞれの絶対値
         */
        pA("if (fixL >= 0) {fixLx = fixL;} else {fixLx = -fixL;}");
        pA("if (fixR >= 0) {fixRx = fixR;} else {fixRx = -fixR;}");

        pA("fixS = 0;");

        /* fixL, fixR の符号が異なる場合の検出
         */
        pA("if (fixL > 0) {if (fixR < 0) {fixS = 1;}}");
        pA("if (fixL < 0) {if (fixR > 0) {fixS = 2;}}");

        /* 符号が異なり、かつ、絶対値比較で fixL の方が小さい場合
         */
        pA("if (fixLx < fixRx) {");
                pA("if (fixS == 1) {fixS = 3; fixA = fixL + fixR;}");
                pA("if (fixS == 2) {fixS = 3; fixA = fixL + fixR;}");
        pA("}");

        /* それ以外の場合
         */
        pA("if (fixS != 3) {");
                /* 絶対に0除算が起きないように、0ならば最小数に置き換えてから除算
                 */
                pA("if (fixR == 0) {fixR = 1;}");
                pA("fixT = fixL / fixR;");

                /* floor
                 */
                pA("if (fixT < 0) {fixT -= 1;}");
                pA("fixRx = fixT * fixR;");
                pA("fixA = fixL - fixRx;");
        pA("}");

        endF();

        pA("%s = fixA;", areg);
}

/* doubleの符号反転命令を出力する
 * -lreg -> areg
 * 予め lreg に値をセットしておくこと。 演算結果は areg へ出力される。
 */
void __func_minus_double(struct Var* avar, const char* areg,
                         const char* lreg, const char* rreg)
{
        pA("%s = -%s;", areg, lreg);
}

/* doubleのand演算はエラー
 */
void __func_and_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        yyerror("syntax err: 浮動小数点数型へAND演算を行ってます");
}

/* doubleのor演算はエラー
 */
void __func_or_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        yyerror("syntax err: 浮動小数点数型へOR演算を行ってます");
}

/* doubleのxor演算はエラー
 */
void __func_xor_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        yyerror("syntax err: 浮動小数点数型へXOR演算を行ってます");
}

/* doubleのビット反転はエラー
 */
void __func_invert_double(struct Var* avar, const char* areg,
                          const char* lreg, const char* rreg)
{
        yyerror("syntax err: 浮動小数点数型へビット反転を行ってます");
}

/* doubleの左シフトはエラー
 */
void __func_lshift_double(struct Var* avar, const char* areg,
                          const char* lreg, const char* rreg)
{
        yyerror("syntax err: 浮動小数点数型へ左シフトを行ってます");
}

/* doubleの右シフトはエラー
 */
void __func_rshift_double(struct Var* avar, const char* areg,
                          const char* lreg, const char* rreg)
{
        yyerror("syntax err: 浮動小数点数型へ右シフトを行ってます");
}

void __func_not_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg)
{
        pA("if (%s != 0) {%s = 0;} else {%s = 1;}", lreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}

void __func_eq_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        pA("if (%s == %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}

void __func_ne_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        pA("if (%s != %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}

void __func_lt_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        pA("if (%s < %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}

void __func_gt_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        pA("if (%s > %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}

void __func_le_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        pA("if (%s <= %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}

void __func_ge_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg)
{
        pA("if (%s >= %s) {%s = 1;} else {%s = 0;}", lreg, rreg, areg, areg);
        var_clear_type(avar);
        avar->type |= TYPE_SIGNED | TYPE_INT;
}
