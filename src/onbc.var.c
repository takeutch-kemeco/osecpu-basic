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

/* すべてのVarはこの配列に所属する */
#define VARLIST_LEN 0x1000
static struct Var varlist[VARLIST_LEN];

/* varlist の現在の先頭から数えて最初の空位置 */
static int32_t varlist_head = 0;

/* varlist のスコープ位置を記録しておくスタック */
#define VARLIST_SCOPE_LEN VARLIST_LEN
static int32_t varlist_scope[VARLIST_SCOPE_LEN] = {[0] = 0};
static int32_t varlist_scope_head = 0;

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
 * ただしVar->is_lvalue、および Var->dim_lenに応じて間接参照・直接参照を切り替える
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

/* 現在のvarlist_headの値をvarlist_scopeへプッシュする
 *
 * これを現在のスコープ位置と考えることで、
 * varlist_scope[varlist_scope_head] 位置から varlist_head 未満までをローカル変数と考える場合に便利。
 * varlist_scope_head に連動させて varlist_head を操作するだけで、ローカル変数を破棄できる。
 */
void varlist_scope_push(void)
{
        varlist_scope_head++;

        if (varlist_scope_head >= VARLIST_SCOPE_LEN)
                yyerror("system err: varlist_scope_push()");

        varlist_scope[varlist_scope_head] = varlist_head;
}

/* varlist_scopeからポップし、varlist_headへセットする
 */
void varlist_scope_pop(void)
{
        if (varlist_scope_head < 0)
                yyerror("system err: varlist_scope_pop()");

        varlist_head = varlist_scope[varlist_scope_head];
        varlist_scope_head--;
}

/* 変数リストに既に同名が登録されているかを、varlist_headからvarlist_bottomの範囲内で確認する。
 * 確認する順序は varlist_head 側から開始して、varlist_bottomへと向かう方向。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 *
 * varlist_search()とvarlist_search_local()の共通ルーチンを抜き出したもの。
 */
struct Var* varlist_search_common(const char* iden, const int32_t varlist_bottom)
{
        int32_t i = varlist_head;
        while (i-->varlist_bottom) {
                if (strcmp(iden, varlist[i].iden) == 0)
                        return &(varlist[i]);
        }

        return NULL;
}

/* 変数リストに既に同名が登録されているかを、グローバル変数スコープの範囲内で確認する。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
struct Var* varlist_search_global(const char* iden)
{
        if (varlist_scope_head <= 0)
                return varlist_search_common(iden, 0);

        int32_t i = varlist_scope[1];
        while (i-->0) {
                if (strcmp(iden, varlist[i].iden) == 0)
                        return &(varlist[i]);
        }

        return NULL;
}

/* 変数リストに既に同名が登録されているかを、最後尾側（varlist_head側）から現在のスコープの範囲内で確認する。
 * 確認する順序は最後尾側から開始して、現在のスコープ側へと向かう方向。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
struct Var* varlist_search_local(const char* iden)
{
        return varlist_search_common(iden, varlist_scope[varlist_scope_head]);
}

/* 変数リストに既に同名が登録されているかを、最後尾側（varlist_head側）からvarlistの先頭まで確認してくる。
 * 確認する順序は最後尾側から開始して、varlistの先頭側へと向かう方向。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
struct Var* varlist_search(const char* iden)
{
        return varlist_search_common(iden, 0);
}

/* 変数リストに新たに変数を無条件に追加する。
 * 既に同名の変数が存在するかの確認は行わない。常に追加する。
 * unit_len: この変数の配列の各要素の長さを指定する。
 * dim_len: この変数の次元数を指定する。 スカラーならば0。
 * indirect_len: この変数の間接参照の深さを指定する。 非ポインター型ならば0。
 *
 * これらの値はint32型。（fix32型ではないので注意)
 */
void varlist_add_common(const char* iden,
                        int32_t* unit_len,
                        const int32_t dim_len,
                        const int32_t indirect_len,
                        const int32_t type)
{
        if (dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        struct Var* cur = varlist + varlist_head;
        struct Var* prev = varlist + varlist_head - 1;

        int32_t total_len = 1;
        int32_t i;
        for (i = 0; i < dim_len; i++) {
                if (unit_len[i] <= 0)
                        yyerror("syntax err: 配列サイズに0以下を指定しました");

                cur->unit_len[i] = unit_len[i];
                total_len *= unit_len[i];
        }

        strcpy(cur->iden, iden);
        cur->base_ptr = (varlist_head == 0) ? 0 : prev->base_ptr + prev->total_len;
        cur->total_len = total_len;
        cur->dim_len = dim_len;
        cur->indirect_len = indirect_len;
        cur->type = type;
        cur->is_lvalue = 1; /* 変数は左辺値 */

        varlist_head++;

#ifdef DEBUG_VARLIST
        for (i = 0; i < dim_len; i++) {
                printf("unit_len%d[%d], ", cur->unit_len[i]);
        }
        printf("total_len[%d], base_ptr[%d], indirect_len[%d]\n",
                cur->total_len, cur->base_ptr, cur->indirect_len);
#endif /* DEBUG_VARLIST */
}

/* 変数リストに新たにグローバル変数を追加する。
 * 現在のスコープ内に重複する同名のグローバル変数が存在した場合は何もしない。
 */
void varlist_add_global(const char* str,
                        int32_t* unit_len,
                        const int32_t dim_len,
                        const int32_t indirect_len,
                        const int32_t type)
{
        if (varlist_search_global(str) == NULL)
                varlist_add_common(str, unit_len, dim_len, indirect_len, type & (~TYPE_AUTO));
        else
                yyerror("syntax err: 同名のグローバル変数を重複して宣言しました");
}

/* 変数リストに新たにローカル変数を追加する。
 * 現在のスコープ内に重複する同名のローカル変数が存在した場合は何もしない。
 */
void varlist_add_local(const char* str,
                       int32_t* unit_len,
                       const int32_t dim_len,
                       const int32_t indirect_len,
                       const int32_t type)
{
        if (varlist_search_local(str) == NULL)
                varlist_add_common(str, unit_len, dim_len, indirect_len, type | TYPE_AUTO);
        else
                yyerror("syntax err: 同名のローカル変数を重複して宣言しました");
}

/* 変数リストの現在の最後の変数を、新しいスコープの先頭とみなして、それの base_ptr に0をセットする
 *
 * 新しいスコープ内にて、新たにローカル変数 a, b, c を宣言する場合の例:
 * varlist_add_local("a", unit, len, 0, TYPE_INT, 0, 0); // とりあえず a を宣言する
 * varlist_set_scope_head(); // これでヒープの最後の変数である a の base_ptr へ 0 がセットされる
 * varlist_add_local("b", unit, len, 0, TYPE_INT, 0, 0); // その後 b, c は普通に宣言していけばいい
 * varlist_add_local("c", unit, len, 0, TYPE_INT, 0, 0);
 */
void varlist_set_scope_head(void)
{
        if (varlist_head > 0) {
                struct Var* prev = varlist + varlist_head - 1;
                prev->base_ptr = 0;
        }
}

/* 変数インスタンス関連
 */

/* ローカル変数のインスタンス生成
 */
struct Var* __new_var_initializer_local(struct Var* var)
{
        if (var->dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        /* これはコンパイル時の変数状態を設定するにすぎない。
         * 実際の動作時のメモリー確保（シーク位置レジスターの移動等）の命令は出力しない。
         */
        varlist_add_local(var->iden,
                          var->unit_len,
                          var->dim_len,
                          var->indirect_len,
                          cur_initializer_type | TYPE_AUTO);

        var = varlist_search_local(var->iden);
        if (var == NULL)
                yyerror("system err: __new_var_initializer_local()");

        /* 実際の動作時にメモリー確保するルーチンはこちら側
         */
        if (var->type & TYPE_AUTO)
                pA("stack_head += %d;", var->total_len);

        return var;
}

/* グローバル変数のインスタンス生成
 */
struct Var* __new_var_initializer_global(struct Var* var)
{
        if (var->dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        /* これはコンパイル時の変数状態を設定するにすぎない。
         * 実際の動作時のメモリー確保（シーク位置レジスターの移動等）の命令は出力しない。
         */
        varlist_add_global(var->iden,
                           var->unit_len,
                           var->dim_len,
                           var->indirect_len,
                           cur_initializer_type);

        var = varlist_search_global(var->iden);
        if (var == NULL)
                yyerror("system err: __new_var_initializer_global()");

        return var;
}

struct Var* __new_var_initializer(struct Var* var)
{
        if (varlist_scope_head == 0)
                var = __new_var_initializer_global(var);
        else
                var = __new_var_initializer_local(var);

        return var;
}
