/* onbc.ec.c
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
#include <stdint.h>
#include "onbc.print.h"
#include "onbc.mem.h"
#include "onbc.stack.h"
#include "onbc.var.h"
#include "onbc.label.h"
#include "onbc.acm.h"
#include "onbc.ec.h"

/* 白紙のECインスタンスをメモリー領域を確保して生成
 */
struct EC* new_ec(void)
{
        struct EC* ec = malloc(sizeof(*ec));
        if (ec == NULL)
                yyerror("system err: new_ec(), malloc()");

        ec->var = new_var();
        ec->type_operator = 0;
        ec->type_expression = 0;
        ec->child_len = 0;

        return ec;
}

/* メモリー領域を開放してECインスタンスを消去
 * (枝(child_ptr[])も含めての開放ではない)
 */
void delete_ec(struct EC* ec)
{
        free((void*)ec);
}

/* EC木のアセンブラへの翻訳関連
 */

void translate_ec(struct EC* ec)
{
        if ((ec->type_operator != EC_OPE_FUNCTION) &&
            (ec->type_expression != EC_COMPOUND_STATEMENT) &&
            (ec->type_expression != EC_SELECTION_STATEMENT) &&
            (ec->type_expression != EC_ITERATION_STATEMENT) &&
            (ec->type_expression != EC_DECLARATION) &&
            (ec->type_expression != EC_DIRECT_DECLARATOR) &&
            (ec->type_expression != EC_FUNCTION_DEFINITION) &&
            (ec->type_expression != EC_DECLARATOR) &&
            (ec->type_expression != EC_PARAMETER_TYPE_LIST)) {
                int32_t i;
                for (i = 0; i < ec->child_len; i++) {
                        translate_ec(ec->child_ptr[i]);
                }

                if (ec->child_len >= 1)
                        *(ec->var) = *(ec->child_ptr[0]->var);
        }

        if (ec->type_expression == EC_FUNCTION_DEFINITION) {
                const int32_t skip_label = cur_label_index_head++;
                pA("PLIMM(P3F, %d);", skip_label);

                translate_ec(ec->child_ptr[0]); /* 関数識別子、および引数 */
                translate_ec(ec->child_ptr[1]); /* 関数のステートメント部 */

                /* 現在の関数からのリターン
                 * プログラムフローがこの位置へ至る状態は、関数内でreturnが実行されなかった場合。
                 * しかし、関数は expression なので、終了後に"必ず"スタックが +1 された状態でなければならないので、
                 * fixAにデフォルト値として 0 をセットし、 return 0 と同様の処理となる。
                 */
                pA("fixA = 0;");
                __define_user_function_return();

                /* スコープ復帰位置をポップし、ローカルスコープから一段復帰する（コンパイル時）
                 */
                dec_cur_scope_depth();
                varlist_scope_pop();

                pA("LB(0, %d);", skip_label);
        } else if (ec->type_expression == EC_DECLARATION) {
                cur_initializer_type = ec->var->type;
                translate_ec(ec->child_ptr[0]);
                *(ec->var) = *(ec->child_ptr[0]->var);
        } else if (ec->type_expression == EC_DECLARATION_LIST) {
                /* 何もしない */
        } else if (ec->type_expression == EC_INIT_DECLARATOR_LIST) {
                /* 何もしない */
        } else if (ec->type_expression == EC_INIT_DECLARATOR) {
                pA("fixL = %d;", ec->child_ptr[0]->var->base_ptr);
                pop_stack("fixR");

                push_stack("fixL");
                push_stack("fixR");

                ec->child_ptr[0]->var->is_lvalue = 1;
                *(ec->var) = *(__var_func_assignment_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var));
                pop_stack_dummy();
        } else if (ec->type_expression == EC_DECLARATOR) {
                if (ec->var->type & TYPE_FUNCTION) {
                        cur_initializer_type |= TYPE_FUNCTION;
                        cur_initializer_type &= ~(TYPE_AUTO);
                }

                __new_var_initializer(ec->var);

                if (ec->var->type & TYPE_FUNCTION) {
                        const int32_t func_label = cur_label_index_head++;

                        struct Var* var = varlist_search(ec->var->iden);
                        var->base_ptr = func_label;

                        pA("LB(0, %d);", func_label);

                        translate_ec(ec->child_ptr[0]);
                }
        } else if (ec->type_expression == EC_DIRECT_DECLARATOR) {
                /* 何もしない */
        } else if (ec->type_expression == EC_PARAMETER_TYPE_LIST) {
                /* スコープ復帰位置をプッシュし、一段深いローカルスコープの開始（コンパイル時）
                 */
                inc_cur_scope_depth();
                varlist_scope_push();

                /* ローカル変数として @stack_prev_frame を作成し、
                 * その後、それのオフセットに 0 をセットする（コンパイル時）
                 */
                const char stack_prev_frame_iden[] = "@stack_prev_frame";
                varlist_add_local(stack_prev_frame_iden, NULL, 0, 0, TYPE_INT | TYPE_AUTO);
                varlist_set_scope_head();

                if (ec->child_len == 1)
                        translate_ec(ec->child_ptr[0]);
        } else if (ec->type_expression == EC_PARAMETER_LIST) {
                /* 何もしない */
        } else if (ec->type_expression == EC_PARAMETER_DECLARATION) {
                /* 何もしない */
        } else if (ec->type_expression == EC_STATEMENT) {
                /* 何もしない */
        } else if (ec->type_expression == EC_COMPOUND_STATEMENT) {
                inc_cur_scope_depth();  /* コンパイル時 */
                varlist_scope_push();   /* コンパイル時 */

                translate_ec(ec->child_ptr[0]);
                translate_ec(ec->child_ptr[1]);

                dec_cur_scope_depth();  /* コンパイル時 */
                varlist_scope_pop();    /* コンパイル時 */
        } else if (ec->type_expression == EC_LABELED_STATEMENT) {
                pA("LB(1, %d);", labellist_search(ec->var->iden));
        } else if (ec->type_expression == EC_EXPRESSION_STATEMENT) {
                if (ec->child_len != 0) {
                        /* expression に属するステートメントは、
                         * 終了時点で”必ず”スタックへのプッシュが1個だけ余計に残ってる為、それを掃除する。
                         */
                        pop_stack_dummy();
                }
        } else if (ec->type_expression == EC_STATEMENT_LIST) {
                /* 何もしない */
        } else if (ec->type_expression == EC_SELECTION_STATEMENT) {
                if (ec->type_operator == EC_OPE_IF) {
                        translate_ec(ec->child_ptr[0]);

                        const int32_t else_label = cur_label_index_head++;
                        const int32_t end_label = cur_label_index_head++;

                        pop_stack("stack_socket");
                        pA("if (stack_socket == 0) {PLIMM(P3F, %d);}", else_label);

                        translate_ec(ec->child_ptr[1]);

                        pA("PLIMM(P3F, %d);", end_label);
                        pA("LB(0, %d);", else_label);

                        if (ec->child_len == 3)
                                translate_ec(ec->child_ptr[2]);

                        pA("LB(0, %d);", end_label);
                } else {
                        yyerror("system err: translate_ec(), EC_SELECTION_STATEMENT");
                }
        } else if (ec->type_expression == EC_ITERATION_STATEMENT) {
                if (ec->type_operator == EC_OPE_WHILE) {
                        const int32_t loop_head = cur_label_index_head++;
                        const int32_t loop_end = cur_label_index_head++;

                        pA("LB(0, %d);", loop_head);

                        translate_ec(ec->child_ptr[0]);

                        pop_stack("stack_socket");
                        pA("if (stack_socket == 0) {PLIMM(P3F, %d);}", loop_end);

                        translate_ec(ec->child_ptr[1]);

                        pA("PLIMM(P3F, %d);", loop_head);

                        pA("LB(0, %d);", loop_end);
                } else if (ec->type_operator == EC_OPE_FOR) {
                        const int32_t loop_head = cur_label_index_head++;
                        const int32_t loop_end = cur_label_index_head++;

                        translate_ec(ec->child_ptr[0]);

                        pA("LB(0, %d);", loop_head);

                        translate_ec(ec->child_ptr[1]);

                        pop_stack("stack_socket");
                        pA("if (stack_socket == 0) {PLIMM(P3F, %d);}", loop_end);

                        translate_ec(ec->child_ptr[3]);

                        translate_ec(ec->child_ptr[2]);
                        pop_stack_dummy(); /* スタック+1の状態を0へ戻す */

                        pA("PLIMM(P3F, %d);", loop_head);

                        pA("LB(0, %d);", loop_end);
                } else {
                        yyerror("system err: translate_ec(), EC_ITERATION_STATEMENT");
                }
        } else if (ec->type_expression == EC_JUMP_STATEMENT) {
                if (ec->type_operator == EC_OPE_GOTO) {
                        pA("PLIMM(P3F, %d);", labellist_search(ec->var->iden));
                } else if (ec->type_operator == EC_OPE_RETURN) {
                        /* 空の return の場合は return 0 として動作させる。
                         * これは、ユーザー定義関数は expression なので、
                         * 終了後に必ずスタックが +1 状態である必要があるため。
                         */
                        if (ec->child_len == 0) {
                                pA("fixA = 0;");
                        } else {
                                pop_stack("fixA");
                        }

                        __define_user_function_return();
                } else {
                        yyerror("system err: translate_ec(), EC_JUMP_STATEMENT");
                }
        } else if (ec->type_expression == EC_INLINE_ASSEMBLER_STATEMENT) {
                if (ec->type_operator == EC_OPE_ASM_STATEMENT) {
                        pA("%s", (char*)ec->var->const_variable);
                } else if (ec->type_operator == EC_OPE_ASM_SUBST_VTOR) {
                        var_pop_stack(ec->child_ptr[0]->var, ec->iden);
                } else if (ec->type_operator == EC_OPE_ASM_SUBST_RTOV) {
                        if (ec->child_ptr[0]->var->is_lvalue) {
                                pop_stack("stack_socket");
                                write_mem(ec->iden, "stack_socket");
                        } else {
                                yyerror("syntax err: 有効な左辺値ではありません");
                        }
                } else {
                        yyerror("system err: translate_ec(), EC_INLINE_ASSEMBLER_STATEMENT");
                }
        } else if (ec->type_expression == EC_EXPRESSION) {
                /* 何もしない */
        } else if (ec->type_expression == EC_ASSIGNMENT) {
                if (ec->type_operator == EC_OPE_SUBST) {
                        *(ec->var) = *(__var_func_assignment_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var));
                } else if (ec->type_operator == EC_OPE_LIST) {
                        /* 何もしない */
                } else {
                        yyerror("system err: translate_ec(), EC_ASSIGNMENT");
                }
        } else if (ec->type_expression == EC_CALC) {
                if (ec->type_operator == EC_OPE_ADD) {
                        ec->var = __var_func_add_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_SUB) {
                        ec->var = __var_func_sub_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_MUL) {
                        ec->var = __var_func_mul_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_DIV) {
                        ec->var = __var_func_div_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_MOD) {
                        ec->var = __var_func_mod_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_OR) {
                        ec->var = __var_func_or_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_AND) {
                        ec->var = __var_func_and_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_XOR) {
                        ec->var = __var_func_xor_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_LSHIFT) {
                        ec->var = __var_func_lshift_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_RSHIFT) {
                        ec->var = __var_func_rshift_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_EQ) {
                        ec->var = __var_func_eq_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_NE) {
                        ec->var = __var_func_ne_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_LT) {
                        ec->var = __var_func_lt_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_LE) {
                        ec->var = __var_func_le_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_GT) {
                        ec->var = __var_func_gt_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else if (ec->type_operator == EC_OPE_GE) {
                        ec->var = __var_func_ge_new(ec->child_ptr[0]->var, ec->child_ptr[1]->var);
                } else {
                        yyerror("system err: translate_ec(), EC_CALC");
                }
        } else if (ec->type_expression == EC_CAST) {
                if (ec->type_operator == EC_OPE_CAST) {
                        /* 何もしない */
                } else {
                        yyerror("system err: translate_ec(), EC_CAST");
                }
        } else if (ec->type_expression == EC_PRIMARY) {
                if (ec->type_operator == EC_OPE_VARIABLE) {
                        struct Var* tmp = varlist_search(ec->iden);
                        if (tmp == NULL)
                                yyerror("syntax err: 未定義の変数を参照しようとしました");

                        *(ec->var) = *tmp;

                        if (ec->var->type & TYPE_AUTO)
                                pA("stack_socket = %d + stack_frame;", ec->var->base_ptr);
                        else
                                pA("stack_socket = %d;", ec->var->base_ptr);

                        push_stack("stack_socket");
                } else {
                        yyerror("system err: translate_ec(), EC_PRIMARY");
                }
        } else if (ec->type_expression == EC_UNARY) {
                if (ec->type_operator == EC_OPE_ADDRESS) {
                        *(ec->var) = *(ec->child_ptr[0]->var);

                        if (ec->var->is_lvalue == 0)
                                yyerror("syntax err: 有効な左辺値ではないのでアドレス取得できません");

                        ec->var->indirect_len++;
                        ec->var->is_lvalue = 0;
                } else if (ec->type_operator == EC_OPE_POINTER) {
                        *(ec->var) = *(ec->child_ptr[0]->var);

                        if (ec->var->is_lvalue) {
                                if (ec->var->indirect_len <= 0)
                                        yyerror("syntax err: 間接参照の深さが不正です");

                                ec->var->indirect_len--;
                        }

                        var_pop_stack(ec->var, "fixL");
                        push_stack("fixL");

                        ec->var->is_lvalue = 1;
                } else if (ec->type_operator == EC_OPE_INV) {
                        ec->var = __var_func_invert_new(ec->child_ptr[0]->var);
                } else if (ec->type_operator == EC_OPE_NOT) {
                        ec->var = __var_func_not_new(ec->child_ptr[0]->var);
                } else if (ec->type_operator == EC_OPE_SUB) {
                        ec->var = __var_func_minus_new(ec->child_ptr[0]->var);
                } else if (ec->type_operator == EC_OPE_SIZEOF) {
                        ec->var = ec->child_ptr[0]->var;
                        pA("stack_socket = %d;", ec->var->total_len);
                        push_stack("stack_socket");
                } else {
                        yyerror("system err: translate_ec(), EC_UNARY");
                }
        } else if (ec->type_expression == EC_POSTFIX) {
                if (ec->type_operator == EC_OPE_ARRAY) {
                        if (ec->var->dim_len <= 0)
                                yyerror("syntax err: 配列の添字次元が不正です");

                        /* この時点でスタックには "変数アドレス -> 添字" の順で積まれてる前提。
                         * fixLに変数アドレス、fixRに添字をポップする。
                         */

                        if (ec->child_ptr[0]->var->is_lvalue == 0)
                                yyerror("system err: 有効な左辺値ではありません");

                        var_pop_stack(ec->child_ptr[1]->var, "fixR");
                        var_pop_stack(ec->child_ptr[0]->var, "fixL");

                        *(ec->var) = *(ec->child_ptr[0]->var);

                        ec->var->dim_len--;
                        ec->var->total_len /= ec->var->unit_len[ec->var->dim_len];

                        pA("fixL += fixR * %d;", ec->var->total_len);
                        push_stack("fixL");

                        ec->var->is_lvalue = 1;
                } else if (ec->type_operator == EC_OPE_FUNCTION) {
                        /* 現在の stack_frame をプッシュする。
                         * そして、ここには関数終了後にはリターン値が入った状態となる。
                         */
                        pA("stack_socket = stack_frame;");
                        pA("stack_frame = stack_head;");
                        push_stack("stack_socket");

                        struct Var* var = varlist_search_global(ec->var->iden);
                        if (var == NULL)
                                yyerror("syntax err: 未定義の関数を呼び出そうとしました");

                        translate_ec(ec->child_ptr[0]);

                        const int32_t return_label = cur_label_index_head++;

                        pA("PLIMM(labelstack_socket, %d);", return_label);
                        push_labelstack();

                        pA("PLIMM(P3F, %d);", var->base_ptr);
                        pA("LB(1, %d);", return_label);
                } else {
                        yyerror("system err: translate_ec(), EC_POSTFIX");
                }
        } else if (ec->type_expression == EC_ARGUMENT_EXPRESSION_LIST) {
                /* 何もしない */
        } else if (ec->type_expression == EC_CONSTANT) {
                pA("fixR = %d;", *((int*)(ec->var->const_variable)));

                struct Var* tmp = varlist_search(ec->iden);
                if (tmp == NULL)
                        yyerror("system err: const variable");

                *(ec->var) = *tmp;

                pA("fixL = %d;", ec->var->base_ptr);
                write_mem("fixR", "fixL");
                push_stack("fixL");
        } else {
                yyerror("system err: translate_ec()");
        }
}