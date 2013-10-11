/* onbc.label.c
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

#include <string.h>
#include <stdint.h>
#include "onbc.print.h"
#include "onbc.label.h"

/* 現在の使用可能なラベルインデックスのヘッド
 * この値から LABEL_INDEX_LEN 未満までの間が、まだ未使用なユニークラベルのサフィックス番号。
 * ユニークラベルをどこかに設定する度に、この値をインクリメントすること。
 */
int32_t cur_label_index_head = 0;

#define LABEL_STR_LEN 0x100
struct Label {
        char str[LABEL_STR_LEN];
        int32_t val;
};

static struct Label labellist[LABEL_INDEX_LEN];

/* ラベルリストに既に同名が登録されているかを確認し、そのラベル番号を得る。
 * 無ければ -1 を返す。
 */
int32_t labellist_search_unsafe(const char* str)
{
        int i;
        for (i = 0; i < LABEL_INDEX_LEN; i++) {
                if (strcmp(str, labellist[i].str) == 0)
                        return labellist[i].val;
        }

        return -1;
}

/* ラベルリストに既に同名が登録されているかを確認し、そのラベル番号を得る。
 * 無ければエラー出力して終了
 */
int32_t labellist_search(const char* str)
{
        const int32_t tmp = labellist_search_unsafe(str);
        if (tmp == -1)
                yyerror("syntax err: 存在しないラベルを指定しました");

        return tmp;
}

/* ラベルリストに新たにラベルを追加し、名前とラベル番号を結びつける。
 * これは名前とラベル番号による連想配列。
 * 既に同名の変数が存在した場合はエラー終了する。
 */
void labellist_add(const char* str)
{
        if (labellist_search_unsafe(str) != -1)
                yyerror("syntax err: 既に同名のラベルが存在します");

        if (cur_label_index_head >= LABEL_INDEX_LEN)
                yyerror("system err: コンパイラーが設定可能なラベル数を越えました");

        int i;
        for (i = 0; i < LABEL_INDEX_LEN; i++) {
                if (labellist[i].str[0] == '\0') {
                        strcpy(labellist[i].str, str);

                        labellist[i].val = cur_label_index_head;
                        cur_label_index_head++;

                        return;
                }
        }
}

/* ラベルスタックにラベル型（VPtr型）をプッシュする
 * 事前に以下のレジスタをセットしておくこと:
 * labelstack_socket : プッシュしたい値。（VPtr型）
 */
void push_labelstack(void)
{
        pA("PSMEM0(labelstack_socket, T_VPTR, labelstack_ptr);");
        pA("PADDI(labelstack_ptr, T_VPTR, labelstack_ptr, 1);");
}

/* ラベルスタックからラベル型（VPtr型）をポップする
 * ポップした値は labelstack_socket に格納される。
 */
void pop_labelstack(void)
{
        pA("PADDI(labelstack_ptr, T_VPTR, labelstack_ptr, -1);");
        pA("PLMEM0(labelstack_socket, T_VPTR, labelstack_ptr);");
}

/* ラベルスタックの初期化
 * gosub, return の実装において、呼び出しを再帰的に行った場合でも return での戻りラベルを正しく扱えるように、
 * ラベルをスタックに積むためのもの。
 *
 * labelstack_socket は CUR_RETURN_LABELが指すレジスターと同一なので、
 * （命令次元におけるVPtr型と、コンパイル次元における文字列型との、次元の違いこそあるが）
 * 感覚としてはこれら２つの名前は union の関係。
 *
 * ラベルは、一般的なプログラムにおけるジャンプ先アドレスと考えて問題ない。
 * （ただしこのジャンプ先は、予め明示的に指定する必要が有り、それ以外へのジャンプ方法が存在しないという制限がかかる。
 * また特殊なレジスタでしか扱えない）
 */
void init_labelstack(void)
{
        pA("VPtr labelstack_ptr:P02;");
        pA("junkApi_malloc(labelstack_ptr, T_VPTR, %d);", LABEL_INDEX_LEN);
        pA("VPtr labelstack_socket:%s;", CUR_RETURN_LABEL);
};
