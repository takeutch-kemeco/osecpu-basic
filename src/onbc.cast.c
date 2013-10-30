/* onbc.cast.c
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

#include <stdio.h>
#include "onbc.print.h"
#include "onbc.var.h"

/* 型変換関連
 */

/* 2つの変数スペックの型の共通の汎用型を生成して返す。
 * lvar, rvar は type をあらかじめ正規化しておくべき。
 */
struct Var* new_var_binary_type_promotion(struct Var* lvar, struct Var* rvar)
{
        struct Var* avar = new_var();

        if (lvar->indirect_len >= 1) {
                *avar = *lvar;
        } else if (rvar->indirect_len >= 1) {
                *avar = *rvar;
        } else {
                if (var_is_void(lvar) || var_is_void(rvar)) {
                        avar->type = TYPE_VOID;
                        avar->total_len = 1;
                } else if (var_is_floating(lvar) || var_is_floating(rvar)) {
                        avar->type = TYPE_DOUBLE;
                        avar->total_len = 1;
                } else if (var_is_integral(lvar) || var_is_integral(rvar)) {
                        avar->type = TYPE_SIGNED;
                        avar->type = TYPE_INT;
                        avar->total_len = 1;
                } else {
                        yyerror("system err: new_var_binary_type_promotion()");
                }
        }

        return avar;
}

/* 任意レジスターの値を型変換する
 * lvar, rvar は type をあらかじめ正規化しておくべき。
 */
void cast_regval(struct Var* lvar, struct Var* rvar, const char* rreg)
{
#ifdef DEBUG_CAST_REGVAL
        printf("cast_regval(),\n");
        printf("lvar, ");
        var_print(lvar);
        printf("rvar, ");
        var_print(rvar);
#endif /* DEBUG_CAST_REGVAL */

        /* lvar, rvar が非ポインター型の場合
         */
        if (lvar->indirect_len == 0 && rvar->indirect_len == 0) {
                if (var_is_integral(lvar) && var_is_floating(rvar))
                        pA("%s >>= 16;", rreg); /* 固定小数点数値から整数値へ変換 */
                else if (var_is_floating(lvar) && var_is_integral(rvar))
                        pA("%s <<= 16;", rreg); /* 整数値から固定小数点数値へ変換 */
        }

        /* lvar が非ポインター型の場合
         */
        if (lvar->indirect_len == 0) {
                if (lvar->type & TYPE_INT) {
                        /* pA("%s &= 0xffffffff;", rreg); */
                } else if (lvar->type & TYPE_CHAR) {
                        pA("%s &= 0x000000ff;", rreg);
                } else if (lvar->type & TYPE_SHORT) {
                        pA("%s &= 0x0000ffff;", rreg);
                } else if (lvar->type & TYPE_LONG) {
                        /* pA("%s &= 0xffffffff;", rreg); */
                } else if (lvar->type & TYPE_FLOAT) {
                        /* なにもしない */
                } else if (lvar->type & TYPE_DOUBLE) {
                        /* なにもしない */
                } else if (lvar->type & TYPE_VOID) {
                        /* なにもしない */
                } else {
                        printf("lvar->type[%d]\n", lvar->type);
                        yyerror("system err: cast_regval(), variable type not found");
                }
        }
}
