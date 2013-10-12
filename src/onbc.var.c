/* onbc.var.c
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
#include <string.h>
#include <stdint.h>
#include "onbc.print.h"
#include "onbc.iden.h"
#include "onbc.stack.h"
#include "onbc.var.h"

/* ローカル、グローバル、それぞれの変数スペックのリスト。
 * 全ての変数は、必ずこの何れかに含まれる。
 */
#define VARLIST_LEN 0x1000
static struct Var global_varlist[VARLIST_LEN];
static struct Var local_varlist[VARLIST_LEN];

/* {local,global}_varlist の現在の先頭から数えて最初の空位置
 */
static int32_t global_varlist_head = 0;
static int32_t local_varlist_head = 0;

/* local_varlist のスコープ位置を記録しておくスタック */
#define VARLIST_SCOPE_LEN VARLIST_LEN
static int32_t local_varlist_scope[VARLIST_SCOPE_LEN] = {[0] = 0};
static int32_t local_varlist_scope_head = 0;

/* 現在の__new_var_initializer_{,local,global}()にて作成する型
 * new_var_initializer_{,local,global}()は、関数実行時点でのこの型のインスタンスを生成する
 */
int32_t cur_initializer_type = 0;

/* Varの内容を印字する
 * 主にデバッグ用
 */
void var_print(struct Var* var)
{
        if (var == NULL) {
                printf("struct Var NULL\n");
                return;
        }

        printf("struct Var, iden[%s], is_lvalue[%d], base_ptr[%d], total_len[%d], unit_len",
               var->iden, var->is_lvalue, var->base_ptr, var->total_len);

        int32_t i;
        for (i = 0; i < var->dim_len; i++) {
                printf("[%d]", var->unit_len[i]);
        }

        printf(", dim_len[%d], indirect_len[%d], type[%d]",
               var->dim_len, var->indirect_len, var->type);

        if (var->const_variable != NULL)
                printf(" ,const_variable[%d]", *((int*)var->const_variable));

        printf("\n");
}

/* Varへパラメーターをセットする
 */
struct Var* var_set_param(struct Var* var,
                          const char* iden,
                          const int32_t base_ptr,
                          int32_t* unit_len,
                          const int32_t dim_len,
                          const int32_t total_len,
                          const int32_t indirect_len,
                          const int32_t type,
                          const int32_t is_lvalue,
                          void* const_variable)
{
        strcpy(var->iden, iden);
        var->base_ptr = base_ptr;

        int32_t i;
        for (i = 0; i < dim_len; i++)
                var->unit_len[i] = unit_len[i];

        var->dim_len = dim_len;
        var->total_len = total_len;
        var->indirect_len = indirect_len;
        var->type = type;
        var->is_lvalue = is_lvalue;
        var->const_variable = const_variable;

        return var;
}

/* 空のVarインスタンスを生成する */
struct Var* new_var(void)
{
        struct Var* var = malloc(sizeof(*var));
        if (var == NULL)
                yyerror("system err: new_var(), malloc()");

        var->iden[0] = '\0';
        var->base_ptr = 0;
        var->total_len = 0;
        var->dim_len = 0;
        var->indirect_len = 0;
        var->type = TYPE_SIGNED | TYPE_INT; /* デフォルトは符号付きint */
        var->is_lvalue = 0;
        var->const_variable = NULL;

        return var;
}

/* スタックからのポップ。
 * ただしVar->is_lvalue, Var->dim_lenに応じて間接参照・直接参照を切り替える
 */
void var_pop_stack(struct Var* var, const char* register_name)
{
        if (var->is_lvalue && (var->dim_len <= 0)) {
                pop_stack("stack_socket");
                read_mem(register_name, "stack_socket");
        } else {
                pop_stack(register_name);
        }
}

/* 現在のlocal_varlist_headの値をlocal_varlist_scopeへプッシュする
 *
 * スコープが異なっていれば、同名のローカル変数を作成できる。
 * すなわち、あるスコープ内での変数名は常にユニークとなる。
 */
void local_varlist_scope_push(void)
{
        local_varlist_scope_head++;

        if (local_varlist_scope_head >= VARLIST_SCOPE_LEN)
                yyerror("system err: local_varlist_scope_push()");

        local_varlist_scope[local_varlist_scope_head] = local_varlist_head;
}

/* local_varlist_scopeからポップし、local_varlist_headへセットする
 */
void local_varlist_scope_pop(void)
{
        if (local_varlist_scope_head < 0)
                yyerror("system err: local_varlist_scope_pop()");

        local_varlist_head = local_varlist_scope[local_varlist_scope_head];
        local_varlist_scope_head--;
}

/* グローバル変数リストに既に同名が登録されているかを、グローバル変数の範囲内で確認する。
 */
struct Var* global_varlist_search(const char* iden)
{
        int32_t i = global_varlist_head;
        while (i-->0) {
                if (strcmp(iden, global_varlist[i].iden) == 0)
                        return global_varlist + i;
        }

        return NULL;
}

/* ローカル変数リストに既に同名が登録されているかを、現在のローカル変数スコープの範囲内で確認する。
 */
struct Var* local_varlist_search(const char* iden)
{
        int32_t i = local_varlist_head;
        while (i-->0) {
                if (strcmp(iden, local_varlist[i].iden) == 0)
                        return local_varlist + i;
        }

        return NULL;
}

/* 変数リストに既に同名が登録されているかを、{local,global}_varlist_head以下から確認する。
 * 検索順序はローカル->グローバルの順となる。
 * それぞれのリストの検索方向は {local,global}varlist_head 側から開始して、0方向へと向かう。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
struct Var* varlist_search(const char* iden)
{
        struct Var* var = local_varlist_search(iden);
        if (var == NULL)
                var = global_varlist_search(iden);

        return var;
}

/* unit_len[], dim_len から total_len を計算する
 */
static int32_t get_total_len(int32_t* unit_len, const int32_t dim_len)
{
        int32_t total_len = 1;
        int32_t i;
        for (i = 0; i < dim_len; i++) {
                if (unit_len[i] <= 0)
                        yyerror("syntax err: 配列サイズに0以下を指定しました");

                total_len *= unit_len[i];
        }

        return total_len;
}

/* グローバル変数リストに新たに変数を追加する。
 */
static struct Var*
global_varlist_add(const char* iden,
                   int32_t* unit_len,
                   const int32_t dim_len,
                   const int32_t indirect_len,
                   const int32_t type)
{
        struct Var* cur = global_varlist + global_varlist_head;
        struct Var* prev = global_varlist + global_varlist_head - 1;

        int32_t base_ptr = 0;
        if (global_varlist_head >= 1) {
                /* 最後の +1 は、スタック変数において参照先アドレスに保存用に用いる */
                base_ptr = prev->base_ptr + prev->total_len + 1;
        }

        global_varlist_head++;

        const int32_t total_len = get_total_len(unit_len, dim_len);
        const int32_t is_lvalue = 1; /* 左辺値 */

        return var_set_param(cur, iden, base_ptr, unit_len, dim_len, total_len,
                             indirect_len, type, is_lvalue, NULL);

}

/* ローカル変数リストに新たに変数を追加する。
 */
static struct Var*
local_varlist_add(const char* iden,
                  int32_t* unit_len,
                  const int32_t dim_len,
                  const int32_t indirect_len,
                  const int32_t type)
{
        struct Var* cur = local_varlist + local_varlist_head;
        struct Var* prev = local_varlist + local_varlist_head - 1;

        int32_t base_ptr = 0;
        if (local_varlist_head >= 1) {
                /* 最後の +1 は、スタック変数において参照先アドレスに保存用に用いる */
                base_ptr = prev->base_ptr + prev->total_len + 1;
        }

        local_varlist_head++;

        const int32_t total_len = get_total_len(unit_len, dim_len);
        const int32_t is_lvalue = 1; /* 左辺値 */

        return var_set_param(cur, iden, base_ptr, unit_len, dim_len, total_len,
                             indirect_len, type, is_lvalue, NULL);
}

/* 変数リストに新たに変数を追加する。
 * unit_len: この変数の配列の各要素の長さを指定する。
 * dim_len: この変数の次元数を指定する。 スカラーならば0。
 * indirect_len: この変数の間接参照の深さを指定する。 非ポインター型ならば0。
 *
 * これらの値はint32型。（fix32型ではないので注意)
 */
static struct Var*
varlist_add(const char* iden,
            int32_t* unit_len,
            const int32_t dim_len,
            const int32_t indirect_len,
            const int32_t type)
{
        if (dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        struct Var* var;
        if (type & TYPE_AUTO)
                var = local_varlist_add(iden, unit_len, dim_len, indirect_len, type);
        else
                var = global_varlist_add(iden, unit_len, dim_len, indirect_len, type);

#ifdef DEBUG_VARLIST
        printf("unit_len");
        int32_t i;
        for (i = 0; i < dim_len; i++) {
                printf("[%d]", var->unit_len[i]);
        }
        printf(", ");

        printf("total_len[%d], base_ptr[%d], indirect_len[%d]\n",
                var->total_len, var->base_ptr, var->indirect_len);
#endif /* DEBUG_VARLIST */

        return var;
}

/* ローカル変数リストの現在の最後の変数を、新しいスコープの先頭とみなして、それの base_ptr に0をセットする
 *
 * 新しいスコープ内にて、新たにローカル変数 a, b, c を宣言する場合の例:
 * local_varlist_add("a", unit, len, 0, TYPE_INT); // とりあえず a を宣言する
 * local_varlist_set_scope_head(); // これでヒープの最後の変数である a の base_ptr へ 0 がセットされる
 * local_varlist_add("b", unit, len, 0, TYPE_INT); // その後 b, c は普通に宣言していけばいい
 * local_varlist_add("c", unit, len, 0, TYPE_INT);
 */
void local_varlist_set_scope_head(void)
{
        if (local_varlist_head >= 1) {
                struct Var* prev = local_varlist + local_varlist_head - 1;
                prev->base_ptr = 0;
        }
}

/* 変数インスタンス関連
 */

/* ローカル変数のインスタンス生成
 *
 * ローカル変数の、スタック上でのメモリーイメージ:
 * 3 : ↑
 * 2 : 実際の値 x[1] の格納位置
 * 1 : 実際の値 x[0] の格納位置
 * 0 : 変数読み書き時に参照する位置。 ここにx[0](または間接参照)へのアドレスが入る
 */
static struct Var* __new_var_initializer_local(struct Var* var)
{
        if (local_varlist_search(var->iden) != NULL)
               yyerror("syntax err: 同名のローカル変数を重複して宣言しました");

        if (var->dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        /* これはコンパイル時の変数状態を設定するにすぎない。
         * 実際の動作時のメモリー確保（シーク位置レジスターの移動等）の命令は出力しない。
         */
        varlist_add(var->iden,
                    var->unit_len,
                    var->dim_len,
                    var->indirect_len,
                    cur_initializer_type | TYPE_AUTO);

        struct Var* ret = local_varlist_search(var->iden);
        if (ret == NULL);
                yyerror("system err: ローカル変数の作成に失敗しました");

        /* 現在のstack_headを変数への間接参照アドレスの格納位置とし、
         * ここへ stack_head + 1 のアドレスをセットする
         */
        pA("stack_socket = stack_head + 1");
        write_mem("stack_socket", "stack_head");

        /* スタック変数の為のメモリー領域確保を、その分だけスタックを進めることで行う。
         * +1 はスタック変数において参照先アドレスの保存用に用いた分。
         */
        pA("stack_head += %d;", ret->total_len + 1);

        return ret;
}

/* グローバル変数のインスタンス生成
 */
static struct Var* __new_var_initializer_global(struct Var* var)
{
        if (global_varlist_search(var->iden) != NULL)
                yyerror("syntax err: 同名のグローバル変数を重複して宣言しました");

        if (var->dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        /* これはコンパイル時の変数状態を設定するにすぎない。
         * 実際の動作時のメモリー確保（シーク位置レジスターの移動等）の命令は出力しない。
         */
        varlist_add(var->iden,
                    var->unit_len,
                    var->dim_len,
                    var->indirect_len,
                    cur_initializer_type & (~TYPE_AUTO));

        struct Var* ret = global_varlist_search(var->iden);
        if (ret == NULL)
                yyerror("system err: グローバル変数の作成に失敗しました");

        return ret;
}

struct Var* __new_var_initializer(struct Var* var)
{
        if (var->type & TYPE_AUTO)
                return __new_var_initializer_local(var);
        else
                return __new_var_initializer_global(var);
}
