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
 * var_a, var_b は type をあらかじめ正規化しておくべき。
 */
struct Var* new_var_binary_type_promotion(struct Var* lvar, struct Var* rvar)
{
        struct Var* var = new_var();

        if (var_is_void(lvar) || var_is_void(rvar)) {
                var->type = TYPE_VOID;
                var->total_len = 1;
        } else if (var_is_floating(lvar) || var_is_floating(rvar)) {
                var->type = TYPE_DOUBLE;
                var->total_len = 1;
        } else if (var_is_integral(lvar) || var_is_integral(rvar)) {
                var->type = TYPE_SIGNED;
                var->type = TYPE_INT;
                var->total_len = 1;
        } else {
                yyerror("system err: new_var_binary_type_promotion()");
        }

        return var;
}

/* 任意レジスターの値を型変換する
 */
void cast_regval(const char* register_name,
                 struct Var* dst_var,
                 struct Var* src_var)
{
#ifdef DEBUG_CAST_REGVAL
        printf("cast_regval(),\n");
        printf("dst_var, ");
        var_print(dst_var);
        printf("src_var, ");
        var_print(src_var);
#endif /* DEBUG_CAST_REGVAL */

        /* 参照時のsrc,dstがポインター型の場合
         */
        if (src_var->indirect_len >= 1 && dst_var->indirect_len >= 1) {
                /* なにもしない */

        /* 参照時のsrcがポインター型、dstが非ポインター型の場合 */
        } else if (src_var->indirect_len >= 1 && dst_var->indirect_len == 0) {
                if (dst_var->type & (TYPE_FLOAT | TYPE_DOUBLE))
                        pA("%s <<= 16;", register_name); /* 整数から固定小数点数へ変換 */

        /* 参照時のsrcが非ポインター型、dstがポインター型の場合 */
        } else if (src_var->indirect_len == 0 && dst_var->indirect_len >= 1) {
                /* 何もしない */

        /* 参照時のsrc,dstが非ポインター型の場合
         */
        } else {
                /* srcが固定小数点数、dstが整数の場合 */
                if ((src_var->type & (TYPE_FLOAT | TYPE_DOUBLE)) &&
                    (!(dst_var->type & (TYPE_FLOAT | TYPE_DOUBLE)))) {
                                pA("%s >>= 16;", register_name); /* 固定小数点数から整数へ変換 */

                /* srcが整数、dstが固定小数点数の場合
                 */
                } else if ((!(src_var->type & (TYPE_FLOAT | TYPE_DOUBLE))) &&
                           (dst_var->type & (TYPE_FLOAT | TYPE_DOUBLE))) {
                                pA("%s <<= 16;", register_name); /* 整数値から固定小数値へ変換 */
                }
        }

        /* 参照時のdstが非ポインター型の場合 */
        if (dst_var->indirect_len == 0) {
                if (dst_var->type & TYPE_INT) {
                        /* pA("%s &= 0xffffffff;", register_name); */
                } else if (dst_var->type & TYPE_CHAR) {
                        pA("%s &= 0x000000ff;", register_name);
                } else if (dst_var->type & TYPE_SHORT) {
                        pA("%s &= 0x0000ffff;", register_name);
                } else if (dst_var->type & TYPE_LONG) {
                        /* pA("%s &= 0xffffffff;", register_name); */
                } else if (dst_var->type & TYPE_FLOAT) {
                        /* なにもしない */
                } else if (dst_var->type & TYPE_DOUBLE) {
                        /* なにもしない */
                } else if (dst_var->type & TYPE_VOID) {
                        /* なにもしない */
                } else {
                        printf("dst->var->type[%d]\n", dst_var->type);
                        yyerror("system err: cast_regval(), variable type not found");
                }
        }
}
