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

#include "onbc.print.h"
#include "onbc.var.h"

/* 型変換関連
 */

/* 2項演算の場合のキャスト結果のVarを生成して返す
 */
struct Var* var_cast_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        /* より汎用性の高い方の型を var0 に得る。
         * その際に、var0は非配列型とするので、var->total_lenには型の基本サイズが入る。
         * 現状は実質的に SInt32 型のみなので、どの型も 1 となる。(void型も1)
         */
        if ((var1->type & TYPE_DOUBLE) || (var2->type & TYPE_DOUBLE)) {
                var0->type = TYPE_DOUBLE;
                var0->total_len = 1;
        } else if ((var1->type & TYPE_FLOAT) || (var2->type & TYPE_FLOAT)) {
                var0->type = TYPE_FLOAT;
                var0->total_len = 1;
        } else if ((var1->type & TYPE_INT) || (var2->type & TYPE_INT)) {
                var0->type = TYPE_INT;
                var0->total_len = 1;
        } else if ((var1->type & TYPE_LONG) || (var2->type & TYPE_LONG)) {
                var0->type = TYPE_LONG;
                var0->total_len = 1;
        } else if ((var1->type & TYPE_SHORT) || (var2->type & TYPE_SHORT)) {
                var0->type = TYPE_SHORT;
                var0->total_len = 1;
        } else if ((var1->type & TYPE_CHAR) || (var2->type & TYPE_CHAR)) {
                var0->type = TYPE_CHAR;
                var0->total_len = 1;
        } else if ((var1->type & TYPE_VOID) || (var2->type & TYPE_VOID)) {
                var0->type = TYPE_VOID;
                var0->total_len = 1;
        } else {
                yyerror("system err: var_cast_new(), variable type not found");
        }

        var0->is_lvalue = 0; /* 右辺値とする */

#ifdef DEBUG_VAR_CAST
        printf("var0, ");
        var_print(var0);

        printf("var1, ");
        var_print(var1);

        printf("var2, ");
        var_print(var2);
#endif /* DEBUG_VAR_CAST */

        return var0;
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
                if (src_var->type & (TYPE_FLOAT | TYPE_DOUBLE))
                        pA("%s >>= 16;", register_name); /* 固定小数点数から整数へ変換 */

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
                        yyerror("system err: cast_regval(), variable type not found");
                }
        }
}
