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
#include "onbc.windstack.h"
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

/* 次に呼び出される __local_varlist_add() によって変数を定義する際に、
 * その変数を新しいスコープの先頭とみなして、それの base_ptr に0をセットして定義するように予約する
 *
 * 新しいスコープ内にて、新たにローカル変数 a, b, c を宣言する場合の例:
 * next_local_varlist_add_set_new_scope = 1; // これで次に呼び出される __local_varlist_add() が、
 *                                           // base_ptr = 0 の変数を定義するように動作する。
 * local_varlist_add("a", unit, len, 0, TYPE_INT); // a は base_ptr = 0 として定義される
 * local_varlist_add("b", unit, len, 0, TYPE_INT); // 以降の b, c は普通に宣言していけばいい
 * local_varlist_add("c", unit, len, 0, TYPE_INT);
 */
int32_t next_local_varlist_add_set_new_scope = 0;

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

/* ローカル変数リストに既に同名が登録されているかを検索する場合の共通ルーチン。
 * 検索順序は top -> bottom の方向となる。
 */
static struct Var* local_varlist_search_common(const char* iden,
                                               const int32_t top,
                                               const int32_t bottom)
{
        struct Var* p = local_varlist;
        int i;
        for (i = top; i >= bottom; i--) {
                if (strcmp(iden, p->iden) == 0)
                        return p;

                p--;
        }

        return NULL;
}

/* ローカル変数リストに既に同名が登録されているかを、現在のローカル変数スコープ限定で確認する。
 */
static struct Var* local_varlist_search_scope(const char* iden)
{
        const int32_t top = local_varlist_head - 1;
        const int32_t bottom = local_varlist_scope[local_varlist_scope_head];

        return local_varlist_search_common(iden, top, bottom);
}

/* ローカル変数リストに既に同名が登録されているかを、現在のローカル変数スコープ以下の全スコープから確認する。
 */
static struct Var* local_varlist_search_all(const char* iden)
{
        const int32_t top = local_varlist_head - 1;
        const int32_t bottom = 0;

        return local_varlist_search_common(iden, top, bottom);
}

/* 変数リストに既に同名が登録されているかを、{local,global}_varlist_head以下から確認する。
 * 検索順序はローカル->グローバルの順となる。
 * それぞれのリストの検索方向は {local,global}varlist_head 側から開始して、0方向へと向かう。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
struct Var* varlist_search(const char* iden)
{
        struct Var* var = local_varlist_search_all(iden);
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
        if (next_local_varlist_add_set_new_scope)
                yyerror("system err: global_varlist_add()");

        struct Var* cur = global_varlist + global_varlist_head;
        struct Var* prev = global_varlist + global_varlist_head - 1;

        int32_t base_ptr = 0;
        if (global_varlist_head >= 1) {
                /* +1 は、変数において参照先アドレス保存用の領域分 */
                base_ptr = prev->base_ptr + 1 + prev->total_len;
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

        if (next_local_varlist_add_set_new_scope) {
                base_ptr = 0;
                next_local_varlist_add_set_new_scope = 0;
        } else {
                if (local_varlist_head >= 1) {
                        /* +1 は、変数において参照先アドレス保存用の領域分 */
                        if (prev->type & TYPE_WIND)
                                base_ptr = prev->base_ptr + 1;
                        else
                                base_ptr = prev->base_ptr + 1 + prev->total_len;
                }
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
        if ((type & TYPE_AUTO) || (type & TYPE_WIND))
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

        printf("iden[%s], total_len[%d], base_ptr[%d], indirect_len[%d]\n",
                var->iden, var->total_len, var->base_ptr, var->indirect_len);
#endif /* DEBUG_VARLIST */

        return var;
}

/* 変数インスタンス関連
 */

/* ローカル変数のインスタンス生成で、記憶域をスタックから新たに確保・設定する場合 */
static struct Var* __new_var_initializer_local_alloc(struct Var* var)
{
        /* 現在のstack_headを変数への間接参照アドレスの格納位置とし、
         * ここへ stack_head + 1 のアドレスをセットする
         */
        pA("stack_socket = stack_head + 1;");
        write_mem("stack_socket", "stack_head");

        /* スタック変数の為のメモリー領域確保を、その分だけスタックを進めることで行う。
         * +1 はスタック変数において参照先アドレスの保存用に用いた分。
         */
        pA("stack_head += %d;", var->total_len + 1);

        return var;
}

/* ローカル変数のインスタンス生成で、ワインドスタックからポップしたアドレスを用いて記憶域設定する場合 */
static struct Var* __new_var_initializer_local_wind(struct Var* var)
{
        /* 現在のstack_headを変数への間接参照アドレスの格納位置とし、
         * ここへ ワインドスタックからポップした値をセットする
         */
        pop_windstack("stack_socket");
        write_mem("stack_socket", "stack_head");

        /* スタック変数において参照先アドレスの保存用に用いた分、スタックを +1 進める */
        push_stack_dummy();

        return var;
}

/* ローカル変数のインスタンス生成
 *
 * ローカル変数の、スタック上でのメモリーイメージ:
 *      3 : ↑
 *      2 : 実際の値 x[1] の格納位置
 *      1 : 実際の値 x[0] の格納位置
 *      0 : 変数読み書き時に参照する位置。 ここにx[0](または間接参照)へのアドレスが入る
 *
 * 関数引数の場合(ワインドの場合)のメモリーイメージ:
 *      0 : 変数読み書き時に参照する位置。 ここに間接参照のアドレス (アドレス x + 0) が入る
 *
 *      x + 2 : ↑
 *      x + 1 : どこかに存在する、実際の値 x[1]
 *      x + 0 : どこかに存在する、実際の値 x[0]
 *
 *      p : ワインドスタックからポップした値。ここに x[0] のアドレスを得られる。
 */
static struct Var* __new_var_initializer_local(struct Var* var, const int32_t type)
{
        if (local_varlist_search_scope(var->iden) != NULL)
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
                    type | TYPE_AUTO);

        struct Var* ret = local_varlist_search_scope(var->iden);
        if (ret == NULL)
                yyerror("system err: ローカル変数の作成に失敗しました");

        /* 変数のメモリー領域の確保方法の違い */
        if (type & TYPE_WIND)
                return __new_var_initializer_local_wind(ret);
        else
                return __new_var_initializer_local_alloc(ret);
}

/* グローバル変数のインスタンス生成
 */
static struct Var* __new_var_initializer_global(struct Var* var, const int32_t type)
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
                    type & (~TYPE_AUTO));

        struct Var* ret = global_varlist_search(var->iden);
        if (ret == NULL)
                yyerror("system err: グローバル変数の作成に失敗しました");

        return ret;
}

struct Var* __new_var_initializer(struct Var* var, int32_t type)
{
        /* スコープが 1 以上(ブロックに入ってる状態)であれば、
         * デフォルトを TYPE_AUTO とする。
         */
        if (local_varlist_scope_head >= 1)
                type |= TYPE_AUTO;

        /* static | literal | function であれば TYPE_AUTO を外す
         */
        if ((type & TYPE_STATIC) || (type & TYPE_LITERAL) || (type & TYPE_FUNCTION))
                type &= ~(TYPE_AUTO);

        if ((type & TYPE_AUTO) || (type & TYPE_WIND))
                return __new_var_initializer_local(var, type);
        else
                return __new_var_initializer_global(var, type);
}
