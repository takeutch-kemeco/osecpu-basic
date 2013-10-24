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
#include "onbc.stackframe.h"

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

/* 現在の関数からのリターン
 * リターンさせる値をあらかじめ fixA にセットしておくこと
 */
void __define_user_function_return(void)
{
        /* 引数をスタックに積む前の状態の stack_frame まで戻す */
        pop_stackframe();

        /* stack_head 位置を stack_frame にする */
        pA("stack_head = stack_frame;");

        /* 関数実行前の状態の stack_frame まで戻す */
        pop_stackframe();

#ifdef DEBUG_SCOPE
        pA_mes("__define_user_function_return(): ");
        pA_reg("stack_frame");
        pA_mes(", ");
        pA_reg("stack_head");
        pA_mes("\\n");
#endif /* DEBUG_SCOPE */

        push_stack("fixA");

        /* 関数呼び出し元の位置まで戻る */
        pop_labelstack();
        pA("PCP(P3F, %s);", CUR_RETURN_LABEL);
}
