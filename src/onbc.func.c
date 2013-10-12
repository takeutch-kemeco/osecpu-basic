/* onbc.func.c
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
#include <stdint.h>
#include <string.h>
#include "onbc.print.h"
#include "onbc.label.h"
#include "onbc.var.h"

/* プリセット関数やアキュムレーターを呼び出し命令に対して、追加でさらに共通の定型命令を出力する。
 * すなわち、関数呼び出しのラッパ。
 * （ラベルスタックへの戻りラベルのプッシュ、関数実行、関数後位置への戻りラベル設定）
 *
 * 呼び出し先の関数は、中でさらに再帰を行っても良いが、
 * 最終的には必ず pop_labelstack を伴ったリターン（すなわち retF()）をしなければならない。
 * （さもなくばラベルスタックの整合性が壊れてしまう）
 * このリターンに関しては別の関数に任す形となる。（callF()からはコントロールできないので）
 *
 * 引数 label には、別途、各関数およびアキュムレーターに対してユニークに定義された定数を渡す。
 */
void callF(const int32_t label)
{
        pA("PLIMM(%s, %d);", CUR_RETURN_LABEL, cur_label_index_head);
        push_labelstack();
        pA("PLIMM(P3F, %d);", label);

        pA("LB(1, %d);", cur_label_index_head);
        cur_label_index_head++;
}

/* pop_labelstack を伴ったリターンの定型命令を出力する
 * すなわち、関数リターンのラッパ。
 */
void retF(void)
{
        pop_labelstack();
        pA("PCP(P3F, %s);", CUR_RETURN_LABEL);
}

/* ユーザー定義関数関連
 */

/* 関数呼び出し
 */
void __call_user_function(const char* iden)
{
        /* ラベルリストに名前が存在しなければエラー */
        if (labellist_search_unsafe(iden) == -1)
                yyerror("syntax err: 未定義の関数を実行しようとしました");

        pA("PLIMM(%s, %d);", CUR_RETURN_LABEL, cur_label_index_head);
        push_labelstack();
        pA("PLIMM(P3F, %d);", labellist_search(iden));
        pA("LB(1, %d);", cur_label_index_head);
        cur_label_index_head++;
}

/* 関数定義の前半部
 * __STATE_FUNCTION __IDENTIFIER __LB identifier_list __RB __BLOCK_LB
 */
void __define_user_function_begin(const char* iden,
                                  const int32_t arglen,
                                  const int32_t skip_label)
{
        /* 通常フロー中ではここに到達し、その場合はこの関数定義は読み飛ばす
         * 関数の最後位置へ skip_label 番号のラベルが存在する前提で、そこへのジャンプ命令をここに書く。
         *
         * すなわち __define_use_function_begin() と、同_end() の、これら関数はペアで呼ばれるが、
         * その際に引数の skip_label には同じ値を渡す必要がある。
         * （ペア同士ならば、引数 skip_label が同じ値である暗黙の前提）
         */
        pA("PLIMM(P3F, %d);", skip_label);

        /* 関数呼び出し時には、この位置が関数の先頭、すなわちジャンプ先アドレスとなる */
        pA("LB(1, %d);", labellist_search(iden));

        /* スコープ復帰位置をプッシュし、一段深いローカルスコープの開始（コンパイル時）
         */
        local_varlist_scope_push();

        /* ローカル変数として @stack_prev_frame を作成し、
         * その後、それのオフセットに 0 をセットする（コンパイル時）
         */
        struct Var* var = new_var();
        strcpy(var->iden, "@stack_prev_frame");
        var->dim_len = 0;
        var->indirect_len = 0;
        __new_var_initializer(var, TYPE_INT | TYPE_AUTO);
        local_varlist_set_scope_head();

        /* スタック上に格納された引数順序と対応した順序となるように、ローカル変数を作成していく。
         * （作成したローカル変数へ値を代入する手間が省ける）
         */
        int32_t i;
        for (i = 0; i < arglen; i++) {
                char iden[0x1000];
                idenlist_pop(iden);

                struct Var* var = new_var();
                strcpy(var->iden, iden);
                var->dim_len = 0;
                var->indirect_len = 0;
                __new_var_initializer(var, TYPE_INT | TYPE_AUTO);
        }

        /* 現在の stack_frame に stack_head - (arglen + 1) をセットする。
         * この位置はローカル変数 @stack_prev_frame が参照する位置であり、また
         * 関数の関数終了後には、この位置にリターン値がセットされた状態となる。
         */
        pA("stack_frame = stack_head - %d;", arglen + 1);

#ifdef DEBUG_SCOPE
        pA("junkApi_putConstString('inc_scope(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
        pA("junkApi_putConstString(', stack_frame=');");
        pA("junkApi_putStringDec('\\1', stack_frame, 11, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_SCOPE */
}

/* 現在の関数からのリターン
 * リターンさせる値をあらかじめ fixA にセットしておくこと
 */
void __define_user_function_return(void)
{
        /* スコープを1段戻す場合の定形処理
         */
        /* stack_head 位置を stack_frame にする */
        pA("stack_head = stack_frame;");

        /* ローカル変数 @stack_prev_frame の値を stack_frame へセットする。
         * その後、stack_head を stack_frame
         */
        read_mem("fixA1", "stack_frame");
        pA("stack_frame = fixA1;");

#ifdef DEBUG_SCOPE
        pA("junkApi_putConstString('dec_scope(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
        pA("junkApi_putConstString(', stack_frame=');");
        pA("junkApi_putStringDec('\\1', stack_frame, 11, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_SCOPE */

        push_stack("fixA");

        /* 関数呼び出し元の位置まで戻る */
        pop_labelstack();
        pA("PCP(P3F, %s);", CUR_RETURN_LABEL);
}

/* 関数定義の後半部
 * declaration_list __BLOCK_RB
 */
void __define_user_function_end(const int32_t skip_label)
{
        /* 現在の関数からのリターン
         * プログラムフローがこの位置へ至る状態は、関数内でreturnが実行されなかった場合。
         * しかし、関数は expression なので、終了後に"必ず"スタックが +1 された状態でなければならないので、
         * fixAにデフォルト値として 0 をセットし、 return 0 と同様の処理となる。
         */
        pA("fixA = 0;");
        __define_user_function_return();

        /* スコープ復帰位置をポップし、ローカルスコープから一段復帰する（コンパイル時）
         */
        local_varlist_scope_pop();

        /* 通常フロー中では、この関数定義を読み飛ばし、ここへとジャンプしてくる前提
         * また、この skip_label の値は、
         * この関数とペアで呼ばれる関数 __define_user_function_begin() へのそれと同じ値である前提。
         */
        pA("LB(0, %d);", skip_label);
}
