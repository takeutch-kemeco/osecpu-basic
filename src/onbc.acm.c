/* onbc.acm.c
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
#include <stdlib.h>
#include "onbc.print.h"
#include "onbc.mem.h"
#include "onbc.cast.h"
#include "onbc.var.h"
#include "onbc.int.h"
#include "onbc.float.h"
#include "onbc.acm.h"

/* 共通アキュムレーター
 */

/* x項演算の共通ルーチン
 *
 * 各 __func_*() には、その型の場合における演算を行う関数を渡す。
 */
static void
__var_common_operation_new(struct Var* var0,
                           void_func __func_int,
                           void_func __func_char,
                           void_func __func_short,
                           void_func __func_long,
                           void_func __func_float,
                           void_func __func_double,
                           void_func __func_ptr)
{
        /* var0が非ポインター型の場合
         */
        if (var0->indirect_len == 0) {
                if (var0->type & TYPE_INT)
                        __func_int();
                else if (var0->type & TYPE_CHAR)
                        __func_char();
                else if (var0->type & TYPE_SHORT)
                        __func_short();
                else if (var0->type & TYPE_LONG)
                        __func_long();
                else if (var0->type & TYPE_FLOAT)
                        __func_float();
                else if (var0->type & TYPE_DOUBLE)
                        __func_double();
                else if (var0->type & TYPE_VOID)
                        yyerror("syntax err: void型に対して演算を行ってます");
                else
                        yyerror("system err: __var_binary_operation_new()");

        /* var0がポインター型の場合
         */
        } else {
                if (__func_ptr != NULL)
                        __func_ptr();
                else
                        yyerror("syntax err: ポインター型に対して不正な演算を行ってます");
        }

        var0->is_lvalue = 0; /* 右辺値とする */

        push_stack("fixA");
}

/* 二項演算の共通ルーチン
 *
 * 各 __func_*() には、その型の場合における演算を行う関数を渡す。
 * __func_*() は fixL operator fixR -> fixA な動作を行う前提
 */
struct Var*
__var_binary_operation_new(struct Var* var1,
                           struct Var* var2,
                           void_func __func_int,
                           void_func __func_char,
                           void_func __func_short,
                           void_func __func_long,
                           void_func __func_float,
                           void_func __func_double,
                           void_func __func_ptr)
{
        struct Var* var0 = var_cast_new(var1, var2);

        var_pop_stack(var2, "fixR");
        cast_regval("fixR", var0, var2);

        var_pop_stack(var1, "fixL");
        cast_regval("fixL", var0, var1);

        __var_common_operation_new(var0,
                                   __func_int,
                                   __func_char,
                                   __func_short,
                                   __func_long,
                                   __func_float,
                                   __func_double,
                                   __func_ptr);

        return var0;
}

/* 単項演算の共通ルーチン
 *
 * 各 __func_*() には、その型の場合における演算を行う関数を渡す。
 * __func_*() は fixL -> fixA な動作を行う前提
 */

struct Var*
__var_unary_operation_new(struct Var* var1,
                          void_func __func_int,
                          void_func __func_char,
                          void_func __func_short,
                          void_func __func_long,
                          void_func __func_float,
                          void_func __func_double,
                          void_func __func_ptr)
{
        struct Var* var0 = new_var();
        *var0 = *var1;

        var_pop_stack(var1, "fixL");

        __var_common_operation_new(var0,
                                   __func_int,
                                   __func_char,
                                   __func_short,
                                   __func_long,
                                   __func_float,
                                   __func_double,
                                   __func_ptr);

        return var0;
}

struct Var*
__var_func_add_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_add_int,
                                           __func_add_int,
                                           __func_add_int,
                                           __func_add_int,
                                           __func_add_float,
                                           __func_add_float,
                                           __func_add_int);

        return var0;
}

struct Var*
__var_func_sub_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_sub_int,
                                           __func_sub_int,
                                           __func_sub_int,
                                           __func_sub_int,
                                           __func_sub_float,
                                           __func_sub_float,
                                           __func_sub_int);

        return var0;
}

struct Var*
__var_func_mul_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_mul_int,
                                           __func_mul_int,
                                           __func_mul_int,
                                           __func_mul_int,
                                           __func_mul_float,
                                           __func_mul_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_div_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_div_int,
                                           __func_div_int,
                                           __func_div_int,
                                           __func_div_int,
                                           __func_div_float,
                                           __func_div_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_mod_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_mod_int,
                                           __func_mod_int,
                                           __func_mod_int,
                                           __func_mod_int,
                                           __func_mod_float,
                                           __func_mod_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_minus_new(struct Var* var1)
{
        struct Var* var0 =
                __var_unary_operation_new(var1,
                                          __func_minus_int,
                                          __func_minus_int,
                                          __func_minus_int,
                                          __func_minus_int,
                                          __func_minus_float,
                                          __func_minus_float,
                                          NULL);

        return var0;
}

struct Var*
__var_func_and_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_and_int,
                                           __func_and_int,
                                           __func_and_int,
                                           __func_and_int,
                                           __func_and_float,
                                           __func_and_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_or_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_or_int,
                                           __func_or_int,
                                           __func_or_int,
                                           __func_or_int,
                                           __func_or_float,
                                           __func_or_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_xor_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_xor_int,
                                           __func_xor_int,
                                           __func_xor_int,
                                           __func_xor_int,
                                           __func_xor_float,
                                           __func_xor_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_invert_new(struct Var* var1)
{
        struct Var* var0 =
                __var_unary_operation_new(var1,
                                          __func_invert_int,
                                          __func_invert_int,
                                          __func_invert_int,
                                          __func_invert_int,
                                          __func_invert_float,
                                          __func_invert_float,
                                          NULL);

        return var0;
}

struct Var*
__var_func_lshift_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_lshift_int,
                                           __func_lshift_int,
                                           __func_lshift_int,
                                           __func_lshift_int,
                                           __func_lshift_float,
                                           __func_lshift_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_rshift_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 =
                __var_binary_operation_new(var1,
                                           var2,
                                           __func_arithmetic_rshift_int,
                                           __func_arithmetic_rshift_int,
                                           __func_arithmetic_rshift_int,
                                           __func_arithmetic_rshift_int,
                                           __func_arithmetic_rshift_float,
                                           __func_arithmetic_rshift_float,
                                           NULL);

        return var0;
}

struct Var*
__var_func_not_new(struct Var* var1)
{
        struct Var* var0 = new_var();

        var_pop_stack(var1, "fixL");

        pA("if (fixL != 0) {fixA = 0;} else {fixA = 1;}");
        push_stack("fixA");

        return var0;
}

static void __var_func_eq_common(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = var_cast_new(var1, var2);

        var_pop_stack(var2, "fixR");
        cast_regval("fixR", var0, var2);

        var_pop_stack(var1, "fixL");
        cast_regval("fixL", var0, var1);

        free(var0);
}

struct Var*
__var_func_eq_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL == fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

struct Var*
__var_func_ne_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL != fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

struct Var*
__var_func_lt_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL < fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

struct Var*
__var_func_gt_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL > fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

struct Var*
__var_func_le_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL <= fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

struct Var*
__var_func_ge_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL >= fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

struct Var*
__var_func_assignment_new(struct Var* var1, struct Var* var2)
{
        /* var0 = var1
         */
        struct Var* var0 = new_var();
        *var0 = *var1;

        var_pop_stack(var2, "fixR");

        if (var1->is_lvalue && (var1->dim_len == 0)) {
                pop_stack("fixL");
        } else {
                yyerror("syntax err: 有効な左辺値ではないので代入できません");
        }

        cast_regval("fixR", var0, var2);
        write_mem("fixR", "fixL");

        push_stack("fixR");

        return var0;
}
