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
#include "onbc.sint.h"
#include "onbc.uint.h"
#include "onbc.double.h"
#include "onbc.ptr.h"
#include "onbc.acm.h"

/* 共通アキュムレーター
 */

/* x項演算の共通ルーチン
 *
 * 各 __func_*() には、その型の場合における演算を行う acm_func 関数を渡す。
 */
static void
var_common_operation_new(struct Var* avar,
                         const char* areg,
                         const char* lreg,
                         const char* rreg,
                         acm_func __func_sint,
                         acm_func __func_uint,
                         acm_func __func_double,
                         acm_func __func_ptr)
{
        /* avarの型に応じて分岐
         */
        if (avar->indirect_len >= 1) {
                __func_ptr(avar, areg, lreg, rreg);
        } else if (var_is_integral(avar)) {
                if (avar->type & TYPE_SIGNED) {
                        __func_sint(avar, areg, lreg, rreg);
                } else if (avar->type & TYPE_UNSIGNED) {
                        __func_uint(avar, areg, lreg, rreg);
                } else {
                        yyerror("__var_common_operation_new(), integral type err");
                }
        } else if (var_is_floating(avar)) {
                __func_double(avar, areg, lreg, rreg);
        } else if (var_is_void(avar)) {
                yyerror("syntax err: void 型への演算を行いました");
        } else {
                yyerror("__var_common_operation_new(), type err");
        }

        avar->is_lvalue = 0; /* 右辺値とする */

        push_stack(areg);
}

/* 二項の暗黙の型変換を行う
 */
static void
var_binary_implicit_type_promotion(struct Var* avar,
                                   struct Var* lvar, const char* lreg,
                                   struct Var* rvar, const char* rreg)
{
        if ((lvar->indirect_len == 0) && (rvar->indirect_len == 0)) {
                cast_regval(avar, lvar, lreg);
                cast_regval(avar, rvar, rreg);
        }
}

/* 二項演算の共通ルーチン
 *
 * 各 __func_*() には、その型の場合における演算を行う関数を渡す。
 * __func_*() は a = l ope r な動作を行う前提
 */
static struct Var*
var_binary_operation_new(const char* areg,
                         struct Var* lvar, const char* lreg,
                         struct Var* rvar, const char* rreg,
                         acm_func __func_sint,
                         acm_func __func_uint,
                         acm_func __func_double,
                         acm_func __func_ptr)
{
        rvar = var_normalization_type(rvar);
        var_pop_stack(rvar, rreg);

        lvar = var_normalization_type(lvar);
        var_pop_stack(lvar, lreg);

        struct Var* avar = new_var_binary_type_promotion(lvar, rvar);
        var_binary_implicit_type_promotion(avar, lvar, lreg, rvar, rreg);

        /* r のみがポインター型の場合は、
         * l と r を入れ替えて a = r ope l を計算するため。
         */
        if (lvar->indirect_len >= 0 && rvar->indirect_len >= 1) {
                struct Var* tmp = lvar;
                lvar = rvar;
                rvar = lvar;
        }

        var_common_operation_new(avar, areg, lreg, rreg,
                                 __func_sint, __func_uint,
                                 __func_double, __func_ptr);

        return avar;
}

/* 単項演算の共通ルーチン
 *
 * 各 __func_*() には、その型の場合における演算を行う関数を渡す。
 * __func_*() は fixL -> fixA な動作を行う前提
 */

static struct Var*
var_unary_operation_new(const char* areg,
                        struct Var* lvar, const char* lreg,
                        acm_func __func_sint,
                        acm_func __func_uint,
                        acm_func __func_double,
                        acm_func __func_ptr)
{
        lvar = var_normalization_type(lvar);
        var_pop_stack(lvar, lreg);

        struct Var* avar = new_var();
        *avar = *lvar;

        var_common_operation_new(avar, areg, lreg, NULL,
                                 __func_sint, __func_uint,
                                 __func_double, __func_ptr);

        return avar;
}

struct Var*
__var_func_add_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_add_sint,
                                         __func_add_uint,
                                         __func_add_double,
                                         __func_add_ptr);

        return avar;
}

struct Var*
__var_func_sub_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_sub_sint,
                                         __func_sub_uint,
                                         __func_sub_double,
                                         __func_sub_ptr);

        return avar;
}

struct Var*
__var_func_mul_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_mul_sint,
                                         __func_mul_uint,
                                         __func_mul_double,
                                         __func_mul_ptr);

        return avar;
}

struct Var*
__var_func_div_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_div_sint,
                                         __func_div_uint,
                                         __func_div_double,
                                         __func_div_ptr);

        return avar;
}

struct Var*
__var_func_mod_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_mod_sint,
                                         __func_mod_uint,
                                         __func_mod_double,
                                         __func_mod_ptr);

        return avar;
}

struct Var*
__var_func_minus_new(const char* areg,
                     struct Var* lvar, const char* lreg)
{
        struct Var* avar =
                var_unary_operation_new(areg,
                                        lvar, lreg,
                                        __func_minus_sint,
                                        __func_minus_uint,
                                        __func_minus_double,
                                        __func_minus_ptr);

        return avar;
}

struct Var*
__var_func_and_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_and_sint,
                                         __func_and_uint,
                                         __func_and_double,
                                         __func_and_ptr);

        return avar;
}

struct Var*
__var_func_or_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_or_sint,
                                         __func_or_uint,
                                         __func_or_double,
                                         __func_or_ptr);

        return avar;
}

struct Var*
__var_func_xor_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_xor_sint,
                                         __func_xor_uint,
                                         __func_xor_double,
                                         __func_xor_ptr);

        return avar;
}

struct Var*
__var_func_invert_new(const char* areg,
                      struct Var* lvar, const char* lreg)
{
        struct Var* avar =
                var_unary_operation_new(areg,
                                        lvar, lreg,
                                        __func_invert_sint,
                                        __func_invert_uint,
                                        __func_invert_double,
                                        __func_invert_ptr);


        return avar;
}

struct Var*
__var_func_lshift_new(const char* areg,
                      struct Var* lvar, const char* lreg,
                      struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_lshift_sint,
                                         __func_lshift_uint,
                                         __func_lshift_double,
                                         __func_lshift_ptr);

        return avar;
}

struct Var*
__var_func_rshift_new(const char* areg,
                      struct Var* lvar, const char* lreg,
                      struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_rshift_sint,
                                         __func_rshift_uint,
                                         __func_rshift_double,
                                         __func_rshift_ptr);

        return avar;
}

struct Var*
__var_func_not_new(const char* areg,
                   struct Var* lvar, const char* lreg)
{
        struct Var* avar =
                var_unary_operation_new(areg,
                                        lvar, lreg,
                                        __func_not_sint,
                                        __func_not_uint,
                                        __func_not_double,
                                        __func_not_ptr);

        return avar;
}

struct Var*
__var_func_eq_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_eq_sint,
                                         __func_eq_uint,
                                         __func_eq_double,
                                         __func_eq_ptr);

        return avar;
}

struct Var*
__var_func_ne_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_ne_sint,
                                         __func_ne_uint,
                                         __func_ne_double,
                                         __func_ne_ptr);

        return avar;
}

struct Var*
__var_func_lt_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_lt_sint,
                                         __func_lt_uint,
                                         __func_lt_double,
                                         __func_lt_ptr);

        return avar;
}

struct Var*
__var_func_gt_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_gt_sint,
                                         __func_gt_uint,
                                         __func_gt_double,
                                         __func_gt_ptr);

        return avar;
}

struct Var*
__var_func_le_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_le_sint,
                                         __func_le_uint,
                                         __func_le_double,
                                         __func_le_ptr);

        return avar;
}

struct Var*
__var_func_ge_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg)
{
        struct Var* avar =
                var_binary_operation_new(areg,
                                         lvar, lreg,
                                         rvar, rreg,
                                         __func_ge_sint,
                                         __func_ge_uint,
                                         __func_ge_double,
                                         __func_ge_ptr);

        return avar;
}

struct Var*
__var_func_assignment_new(const char* areg,
                          struct Var* lvar, const char* lreg,
                          struct Var* rvar, const char* rreg)
{
        /* avar = lvar
         */
        struct Var* avar = new_var();
        *avar = *lvar;

        var_pop_stack(rvar, rreg);

        if (lvar->is_lvalue && (lvar->dim_len == 0))
                pop_stack(lreg);
        else
                yyerror("syntax err: 有効な左辺値ではないので代入できません");

#ifdef DEBUG_VAR_FUNC_ASSIGNMENT_NEW
        pA_mes("__var_func_assignment_new: ");
        pA_reg(lreg);
        pA_mes(", ");
        pA_reg(rreg);
        pA_mes("\\n");
#endif /* DEBUG_VAR_FUNC_ASSIGNMENT_NEW */

        cast_regval(avar, rvar, rreg);
        write_mem(rreg, lreg);

        push_stack(rreg);

        return avar;
}
