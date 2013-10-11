/* onbc.bison.y
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

%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <math.h>
#include "onbc.print.h"
#include "onbc.iden.h"
#include "onbc.var.h"

#define YYMAXDEPTH 0x10000000

/* 変数スペックのリストコンテナ
 */
#define VARLIST_LEN 0x1000
struct VarList {
        struct Var* var[VARLIST_LEN];
        int32_t varlist_len;
};

/* 構造体スペックリスト関連
 */

/* 構造体が持てるメンバー数の上限 */
#define STRUCTLIST_MEMBER_MAX 0x1000

/* 構造体のスペック
 */
struct StructSpec {
        char iden[IDENLIST_STR_LEN];    /* 構造体の名前 */
        int32_t struct_len;             /* 構造体全体の長さ */
        struct Var* member_ptr[STRUCTLIST_MEMBER_MAX];  /* 各メンバー変数スペックへのポインターのリスト */
        int32_t member_offset[STRUCTLIST_MEMBER_MAX];   /* 各メンバー変数のオフセット */
        int32_t member_len;             /* メンバー変数の個数 */
};

/* 構造体メンバースペックのメモリー領域を確保し、値をセットし、アドレスを返す
 */
static struct Var* structmemberspec_new(const char* iden,
                                        int32_t* unit_len,
                                        const int32_t dim_len,
                                        const int32_t indirect_len,
                                        const int32_t type)
{
        if (dim_len >= VAR_DIM_MAX)
                yyerror("syntax err: 配列の次元が高すぎます");

        struct Var* member = new_var();

        strcpy(member->iden, iden);

        member->dim_len = dim_len;
        member->indirect_len = indirect_len;
        member->type = type;

        int32_t total_len = 1;
        int32_t i;
        for (i = 0; i < dim_len; i++) {
                member->unit_len[i] = unit_len[i];
                total_len *= unit_len[i];
        }

        member->total_len = total_len;

        return member;
}

/* 構造体メンバースペックの内容を一覧表示する。
 * 主にデバッグ用。
 * tab は字下げインデント用の文字列。
 */
static void structmemberspec_print(struct Var* member,
                                   const char* tab)
{
        printf("%sStructMemberSpec: iden[%s], indirect_len[%d], dim_len[%d],",
               tab, member->iden, member->indirect_len, member->dim_len);

        int32_t i;
        for (i = 0; i < member->dim_len; i++) {
                printf("[%d]", member->unit_len[i]);
        }
        printf("\n");
}

/* 構造体スペックの内容を一覧表示する。
 * 主にデバッグ用。
 * tab は字下げインデント用の文字列。
 */
static void structspec_print(struct StructSpec* spec, const char* tab)
{
        printf("%sStructSpec: iden[%s], struct_len[%d], member_len[%d]\n",
               tab, spec->iden, spec->struct_len, spec->member_len);

        char tab2[0x100];
        strcpy(tab2, tab);
        strcat(tab2, "\t");

        int i;
        for (i = 0; i < spec->member_len; i++) {
                printf("%smember_offset%d[%d]\n",
                       tab2, i, spec->member_offset[i]);

                structmemberspec_print(spec->member_ptr[i], tab2);
        }
}

/* 構造体スペックに任意の名前のメンバーが登録されてるかを検索し、メンバーの変数スペックを返す。
 * 存在しなければ NULL を返す。
 */
static struct Var* structspec_search(struct StructSpec* spec, const char* iden)
{
        int i = spec->member_len;
        while (i-->0) {
                struct Var* p = spec->member_ptr[i];
                if (strcmp(p->iden, iden) == 0)
                        return p;
        }

        return NULL;
}

/* 構造体スペックに構造体メンバーの変数スペックを追加する
 */
static void structspec_add_member(struct StructSpec* spec, struct Var* member)
{
        /* 既に重複したメンバー名が登録されていた場合はエラー */
        if (structspec_search(spec, member->iden) != NULL)
                yyerror("syntax err: 構造体のメンバー名が重複しています");

        spec->member_ptr[spec->member_len] = member;

        /* 構造体中での、メンバーのオフセット位置をセット。
         * 新規追加する構造体メンバーのオフセット位置は、その時点での構造体サイズとなる。
         */
        spec->member_offset[spec->member_len] = spec->struct_len;

        /* メンバーを追加したので、その分だけ増えた構造体サイズを更新する */
        spec->struct_len += member->total_len;

        /* メンバーを追加したので、構造体に含まれるメンバー個数を更新する */
        spec->member_len++;

#ifdef DEBUG_STRUCTSPEC
        printf("structspec: iden[%s], struct_len[%d], member_len[%d]\n",
               spec->iden, spec->struct_len, spec->member_len);
#endif /* DEBUG_STRUCTSPEC */
}

/* 無名の構造体スペックのメモリー領域を確保し、初期状態をセットして、アドレスを返す
 */
static struct StructSpec* structspec_new(void)
{
        struct StructSpec* spec = malloc(sizeof(*spec));
        if (spec == NULL)
                yyerror("system err: structspec_new(), malloc()");

        spec->iden[0] = '\0';
        spec->struct_len = 0;
        spec->member_len = 0;

        return spec;
}

/* 無名の構造体スペックに名前をつける
 */
static void structspec_set_iden(struct StructSpec* spec,
                                const char* iden)
{
        if (spec->iden[0] != '\0')
                yyerror("system err: structspec_set_name(), spec->iden != NULL");

        strcpy(spec->iden, iden);

#ifdef DEBUG_STRUCTSPEC
        printf("structspec_set_iden(): iden[%s], struct_len[%d], member_len[%d]\n",
               spec->iden, spec->struct_len, spec->member_len);
#endif /* DEBUG_STRUCTSPEC */
}

/* 構造体スペックのポインターリスト
 */
#define STRUCTSPEC_PTRLIST_LEN 0x1000
static struct StructSpec* structspec_ptrlist[STRUCTSPEC_PTRLIST_LEN];

/* 現在の構造体スペックのポインターリストの先頭位置 */
static int32_t cur_structspec_ptrlist_head = 0;

/* 構造体スペックのポインターリストから、任意の名前の構造体スペックが登録されてるかを調べてアドレスを返す。
 * 無ければ NULL を返す。
 */
static struct StructSpec* structspec_ptrlist_search(const char* iden)
{
        int i = cur_structspec_ptrlist_head;
        while (i-->0) {
                struct StructSpec* spec = structspec_ptrlist[i];
                if (strcmp(spec->iden, iden) == 0)
                        return spec;
        }

        return NULL;
}

/* 構造体スペックのポインターリストに登録されてる構造体の一覧表を表示する。
 * 主にデバッグ用。
 */
static void structspec_ptrlist_print(void)
{
        int i;
        for (i = 0; i < cur_structspec_ptrlist_head; i++) {
                printf("structspec_ptrlist: cur_structspec_ptrlist_head[%d]\n",
                       cur_structspec_ptrlist_head);

                structspec_print(structspec_ptrlist[i], "\t");
        }
}

/* 構造体スペックのポインターリストへ、新たな構造体スペックを追加登録する
 */
static void structspec_ptrlist_add(struct StructSpec* spec)
{
        if (structspec_ptrlist_search(spec->iden) != NULL)
                yyerror("syntax err: 構造体のメンバー名が重複しています");

        structspec_ptrlist[cur_structspec_ptrlist_head] = spec;
        cur_structspec_ptrlist_head++;

#ifdef DEBUG_STRUCTSPEC_PTRLIST
        structspec_ptrlist_print();
#endif /* DEBUG_STRUCTSPEC_PTRLIST */
}

/* 現在の使用可能なラベルインデックスのヘッド
 * この値から LABEL_INDEX_LEN 未満までの間が、まだ未使用なユニークラベルのサフィックス番号。
 * ユニークラベルをどこかに設定する度に、この値をインクリメントすること。
 */
static int32_t cur_label_index_head = 0;

/* ラベルの使用可能最大数 */
#define LABEL_INDEX_LEN 2048
#define LABEL_INDEX_LEN_STR "2048"

#define LABEL_STR_LEN 0x100
struct Label {
        char str[LABEL_STR_LEN];
        int32_t val;
};

static struct Label labellist[LABEL_INDEX_LEN];

/* ラベルリストに既に同名が登録されているかを確認し、そのラベル番号を得る。
 * 無ければ -1 を返す。
 */
static int32_t labellist_search_unsafe(const char* str)
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
static int32_t labellist_search(const char* str)
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

/* gosub での return 先ラベルの保存用に使うポインターレジスター */
#define CUR_RETURN_LABEL "P03"

/* ラベルスタックにラベル型（VPtr型）をプッシュする
 * 事前に以下のレジスタをセットしておくこと:
 * labelstack_socket : プッシュしたい値。（VPtr型）
 */
static void push_labelstack(void)
{
        pA("PSMEM0(labelstack_socket, T_VPTR, labelstack_ptr);");
        pA("PADDI(labelstack_ptr, T_VPTR, labelstack_ptr, 1);");
}

/* ラベルスタックからラベル型（VPtr型）をポップする
 * ポップした値は labelstack_socket に格納される。
 */
static void pop_labelstack(void)
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
static char init_labelstack[] = {
        "VPtr labelstack_ptr:P02;\n"
        "junkApi_malloc(labelstack_ptr, T_VPTR, " LABEL_INDEX_LEN_STR ");\n"
        "VPtr labelstack_socket:" CUR_RETURN_LABEL ";\n"
};

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
static void callF(const int32_t label)
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
static void retF(void)
{
        pop_labelstack();
        pA("PCP(P3F, %s);", CUR_RETURN_LABEL);
}

/* beginF, endF
 * プリセット関数及びアキュムレーターをサブルーチン命令化する仕掛け、を記したマクロ。
 * このマクロをプリセット関数及びアキュムレーターの先頭に beginF() を書き、最後に endF() を書くだけで、それをサブルーチン命令化できる。
 *
 * unique_func_label には、その関数に設定されるユニークラベル番号が設定される。
 * これは、このマクロが含まれる関数が始めて呼び出された時点での cur_label_index_head が用いられる。
 * また同時に、内部処理用に unique_func_label + 1 のラベルも消費される。
 * （つまり、関数辺り、2個のユニークラベルが消費される）
 * もちろん、cur_label_index_head は、副作用の無さそうなタイミングで +2 される。
 *
 * 何故こんなハック的な解決方法を採ってるかというと、ただ単に大げさな方法による全面改修をするのが面倒くさかったから。
 */
#define beginF()                                                        \
        static int32_t unique_func_label;                               \
                                                                        \
        static int func_label_init_flag = 0;                            \
        if (func_label_init_flag == 1) {                                \
                callF(unique_func_label);                               \
                return;                                                 \
        }                                                               \
                                                                        \
        unique_func_label = cur_label_index_head;                       \
        const int32_t end_label = unique_func_label + 1;                \
        cur_label_index_head += 2;                                      \
                                                                        \
        callF(unique_func_label);                                       \
        pA("PLIMM(P3F, %d);", end_label);                               \
                                                                        \
        pA("LB(0, %d);", unique_func_label);

#define endF()                                                          \
        retF();                                                         \
        pA("LB(0, %d);", end_label);                                    \
        func_label_init_flag = 1;

/* ヒープメモリー関連
 */

/* ヒープメモリーの初期化
 */
static void init_heap(void)
{
        pA("SInt32 heap_base:R04;");
        pA("SInt32 heap_socket:R05;");
        pA("SInt32 heap_offset:R06;");
        pA("heap_base = 0;");
};

/* ヒープメモリー関連の各種レジスターの値を、実行時に画面に印字する
 * 主にデバッグ用
 */
static void debug_heap(void)
{
        pA("junkApi_putConstString('heap_socket[');");
        pA("junkApi_putStringDec('\\1', heap_socket, 11, 1);");
        pA("junkApi_putConstString('], heap_base[');");
        pA("junkApi_putStringDec('\\1', heap_base, 11, 1);");
        pA("junkApi_putConstString('], heap_offset[');");
        pA("junkApi_putStringDec('\\1', heap_offset, 11, 1);");
        pA("junkApi_putConstString(']\\n');");
}

/* <expression> <OPE_?> <expression> の状態から、左右の <expression> の値をそれぞれ fixL, fixR へ読み込む
 */
static void read_eoe_arg(void)
{
        pop_stack("fixR");
        pop_stack("fixL");
}

/* eoe用レジスタをスタックへプッシュする
 */
static void push_eoe(void)
{
        beginF();

        push_stack("fixL");
        push_stack("fixR");
        push_stack("fixLx");
        push_stack("fixRx");
        push_stack("fixS");
        push_stack("fixT");
        push_stack("fixT1");
        push_stack("fixT2");
        push_stack("fixT3");
        push_stack("fixT4");

        endF();
}

/* eoe用レジスタをスタックからポップする
 */
static void pop_eoe(void)
{
        beginF();

        pop_stack("fixT4");
        pop_stack("fixT3");
        pop_stack("fixT2");
        pop_stack("fixT1");
        pop_stack("fixT");
        pop_stack("fixS");
        pop_stack("fixRx");
        pop_stack("fixLx");
        pop_stack("fixR");
        pop_stack("fixL");

        endF();
};

static char debug_eoe[] = {
        "junkApi_putConstString('\\nfixL:');"
        "junkApi_putStringDec('\\1', fixL, 11, 1);"
        "junkApi_putConstString(' fixR:');"
        "junkApi_putStringDec('\\1', fixR, 11, 1);"
        "junkApi_putConstString(' fixLx:');"
        "junkApi_putStringDec('\\1', fixLx, 11, 1);"
        "junkApi_putConstString(' fixRx:');"
        "junkApi_putStringDec('\\1', fixRx, 11, 1);"
        "junkApi_putConstString(' fixT:');"
        "junkApi_putStringDec('\\1', fixT, 11, 1);"
        "junkApi_putConstString(' fixT1:');"
        "junkApi_putStringDec('\\1', fixT1, 11, 1);"
        "junkApi_putConstString(' fixT2:');"
        "junkApi_putStringDec('\\1', fixT2, 11, 1);"
        "junkApi_putConstString(' fixT3:');"
        "junkApi_putStringDec('\\1', fixT3, 11, 1);"
        "junkApi_putConstString(' fixT4:');"
        "junkApi_putStringDec('\\1', fixT4, 11, 1);"
        "junkApi_putConstString(' fixS:');"
        "junkApi_putStringDec('\\1', fixS, 11, 1);"
        "junkApi_putConstString(' fixA:');"
        "junkApi_putStringDec('\\1', fixA, 11, 1);"
        "junkApi_putConstString(' fixA1:');"
        "junkApi_putStringDec('\\1', fixA1, 11, 1);"
        "junkApi_putConstString(' fixA2:');"
        "junkApi_putStringDec('\\1', fixA2, 11, 1);"
        "junkApi_putConstString(' fixA3:');"
        "junkApi_putStringDec('\\1', fixA3, 11, 1);"
        "junkApi_putConstString('\\n');"
};

/* read_eoe_arg 用変数の初期化
 *
 * push_eoe(), pop_eoe() ともに、例外として fixA スタックへ退避しない。
 * この fixA は eoe 間で値を受け渡しする為に用いるので、push_eoe(), pop_eoe() に影響されないようにしてある。
 * （push後に行った演算の結果をfixAに入れておくことで、その後にpopした後でも演算結果を引き継げるように）
 *
 * fixA1 ～ fixA3 も、 fixA 同様に戻り値の受け渡しに使える。
 */
static char init_eoe_arg[] = {
        "SInt32 fixA:R07;\n"
        "SInt32 fixL:R08;\n"
        "SInt32 fixR:R09;\n"
        "SInt32 fixLx:R0A;\n"
        "SInt32 fixRx:R0B;\n"
        "SInt32 fixS:R0C;\n"
        "SInt32 fixT:R0D;\n"
        "SInt32 fixT1:R0E;\n"
        "SInt32 fixT2:R0F;\n"
        "SInt32 fixT3:R10;\n"
        "SInt32 fixT4:R11;\n"
        "SInt32 fixA1:R12;\n"
        "SInt32 fixA2:R13;\n"
        "SInt32 fixA3:R14;\n"
};

/* 全ての初期化
 */
void init_all(void)
{
        pA("#include \"osecpu_ask.h\"\n");

        pA("LOCALLABELS(%d);\n", LABEL_INDEX_LEN);

        init_mem();
        init_heap();
        init_stack();
        pA(init_labelstack);
        pA(init_eoe_arg);
}

/* 各種アキュムレーター
 */

/* int 型用アキュムレーター
 * 加算、減算、乗算、除算、余り算、符号反転、
 * AND, OR, XOR, ビット反転, NOT,
 * 左シフト、算術右シフト
 */

/* int同士での加算命令を出力する
 * fixL + fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_add_int(void)
{
        pA("fixA = fixL + fixR;");
}

/* int同士での減算命令を出力する
 * fixL - fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_sub_int(void)
{
        pA("fixA = fixL - fixR;");
}

/* int同士での乗算命令を出力する
 * fixL * fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mul_int(void)
{
        pA("fixA = fixL * fixR;");
}

/* int同士での除算命令を出力する
 * fixL / fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_div_int(void)
{
        pA("fixA = fixL / fixR;");
}

/* int同士での余り算命令を出力する
 * fixL MOD fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mod_int(void)
{
        pA("fixA = fixL % fixR;");
}

/* intの符号反転命令を出力する
 * -fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_minus_int(void)
{
        pA("fixA = -fixL;");
}

/* int同士でのAND命令を出力する
 * fixL AND fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_and_int(void)
{
        pA("fixA = fixL & fixR;");
}

/* int同士でのOR命令を出力する
 * fixL OR fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_or_int(void)
{
        pA("fixA = fixL | fixR;");
}

/* int同士でのXOR命令を出力する
 * fixL XOR fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_xor_int(void)
{
        pA("fixA = fixL ^ fixR;");
}

/* intのビット反転命令を出力する
 * ~fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_invert_int(void)
{
        pA("fixA = fixL ^ (-1);");
}

/* intの左シフト命令を出力する
 * fixL << fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_lshift_int(void)
{
        pA("fixA = fixL << fixR;");
}

/* intの右シフト命令を出力する（算術シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 算術シフトとして動作する。
 */
static void __func_arithmetic_rshift_int(void)
{
        pA("if (fixR >= 32) {");
                pA("fixA = 0;");
        pA("} else {");
                pA("if (fixL < 0) {");
                        pA("fixL = ~fixL;");
                        pA("fixL++;");
                        pA("fixL >>= fixR;");
                        pA("fixL = ~fixL;");
                        pA("fixL++;");
                        pA("fixA = fixL;");
                pA("} else {");
                        pA("fixA = fixL >> fixR;");
                pA("}");
        pA("}");
}

/* intの右シフト命令を出力する（論理シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 論理シフトとして動作する。
 */
static void __func_logical_rshift_int(void)
{
        pA("if (fixR >= 32) {");
                pA("fixA = 0;");
        pA("} else {");
                pA("if ((fixL < 0) & (fixR >= 1)) {");
                        pA("fixL &= 0x7fffffff;");
                        pA("fixL >>= fixR;");
                        pA("fixR--;");
                        pA("fixA = 0x40000000 >> fixR;");
                        pA("fixA |= fixL;");
                pA("} else {");
                        pA("fixA = fixL >> fixR;");
                pA("}");
        pA("}");
}

/* float 型用アキュムレーター
 * 加算、減算、乗算、除算、余り算、符号反転
 *
 * 名前は float だけど実際は1:15:16の固定小数
 */

/* float同士での加算命令を出力する
 * fixL + fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_add_float(void)
{
        pA("fixA = fixL + fixR;");
}

/* float同士での減算命令を出力する
 * fixL - fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_sub_float(void)
{
        pA("fixA = fixL - fixR;");
}

/* float同士での乗算命令を出力する
 * fixL * fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mul_inline_float(void)
{
        /* 符号を保存しておき、+へ変換する*/
        pA("fixS = 0;");
        pA("if (fixL < 0) {fixL = -fixL; fixS |= 1;}");
        pA("if (fixR < 0) {fixR = -fixR; fixS |= 2;}");

        pA("fixRx = (fixR & 0xffff0000) >> 16;");
        pA("fixLx = (fixL & 0xffff0000);");

        pA("fixR = fixR & 0x0000ffff;");
        pA("fixL = fixL & 0x0000ffff;");

        pA("fixA = "
           "(((fixL >> 1) * fixR) >> 15) + "
           "((fixLx >> 16) * fixR) + "
           "(fixLx * fixRx) + "
           "(fixL * fixRx);");

        /* 符号を元に戻す
         * fixS の値は、 & 0x00000003 した状態と同様の値のみである前提
         */
        pA("if ((fixS == 0x00000001) | (fixS == 0x00000002)) {fixA = -fixA;}");
}

static void __func_mul_float(void)
{
        beginF();

       __func_mul_inline_float();

        endF();
}

/* float同士での除算命令を出力する
 * fixL / fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_div_float(void)
{
        beginF();

        /* R の逆数を得る
         *
         * （通常は 0x00010000 を 1 と考えるが、）
         * 0x40000000 を 1 と考えると、通常との差は << 14 なので、
         * 0x40000000 / R の結果も << 14 に対する演算結果として得られ、
         * （除算の場合は単位分 >> するので（すなわち >> 16））、
         * したがって結果を << 2 すれば（16 - 14 = 2だから） 0x00010000 を 1 とした場合での値となるはず。
         */

        /* 絶対に0除算が起きないように、0ならば最小数に置き換えてから除算 */
        pA("if (fixR == 0) {fixR = 1;}");
        pA("fixRx = 0x40000000 / fixR;");

        pA("fixR = fixRx << 2;");

        /* 逆数を乗算することで除算とする */
        __func_mul_inline_float();

        endF();
}

/* float同士での符号付き剰余命令を出力する
 * fixL MOD fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mod_float(void)
{
        beginF();

        /* 符号付き剰余
         */

        /* fixL, fixR それぞれの絶対値
         */
        pA("if (fixL >= 0) {fixLx = fixL;} else {fixLx = -fixL;}");
        pA("if (fixR >= 0) {fixRx = fixR;} else {fixRx = -fixR;}");

        pA("fixS = 0;");

        /* fixL, fixR の符号が異なる場合の検出
         */
        pA("if (fixL > 0) {if (fixR < 0) {fixS = 1;}}");
        pA("if (fixL < 0) {if (fixR > 0) {fixS = 2;}}");

        /* 符号が異なり、かつ、絶対値比較で fixL の方が小さい場合
         */
        pA("if (fixLx < fixRx) {");
                pA("if (fixS == 1) {fixS = 3; fixA = fixL + fixR;}");
                pA("if (fixS == 2) {fixS = 3; fixA = fixL + fixR;}");
        pA("}");

        /* それ以外の場合
         */
        pA("if (fixS != 3) {");
                /* 絶対に0除算が起きないように、0ならば最小数に置き換えてから除算
                 */
                pA("if (fixR == 0) {fixR = 1;}");
                pA("fixT = fixL / fixR;");

                /* floor
                 */
                pA("if (fixT < 0) {fixT -= 1;}");
                pA("fixRx = fixT * fixR;");
                pA("fixA = fixL - fixRx;");
        pA("}");

        endF();
}

/* floatの符号反転命令を出力する
 * -fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_minus_float(void)
{
        pA("fixA = -fixL;");
}

/* floatのand演算命令を出力する
 * fixL and fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_and_float(void)
{
        pA("fixA = fixL & fixR;");

        yywarning("syntax warning: 非整数型へAND演算を行ってます");
}

/* floatのor演算命令を出力する
 * fixL or fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_or_float(void)
{
        pA("fixA = fixL | fixR;");

        yywarning("syntax warning: 非整数型へOR演算を行ってます");
}

/* floatのxor演算命令を出力する
 * fixL and fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_xor_float(void)
{
        pA("fixA = fixL ^ fixR;");

        yywarning("syntax warning: 非整数型へXOR演算を行ってます");
}

/* floatのビット反転命令を出力する
 * ~fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_invert_float(void)
{
        pA("fixA = fixL ^ (-1);");

        yywarning("syntax warning: 非整数型へビット反転を行ってます");
}

/* floatの左シフト命令を出力する
 * fixL << fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_lshift_float(void)
{
        pA("fixA = fixL << fixR;");

        yywarning("syntax warning: 非整数型へ左シフト演算を行ってます");
}

/* floatの右シフト命令を出力する(算術シフト)
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_arithmetic_rshift_float(void)
{
        __func_arithmetic_rshift_int();

        yywarning("syntax warning: 非整数型へ算術右シフト演算を行ってます");
}

/* intの右シフト命令を出力する（論理シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 論理シフトとして動作する。
 */
static void __func_logical_rshift_float(void)
{
        __func_logical_rshift_int();

        yywarning("syntax warning: 非整数型へ論理右シフト演算を行ってます");
}

/* 型変換関連
 */

/* 2項演算の場合のキャスト結果のVarを生成して返す
 */
static struct Var* var_cast_new(struct Var* var1, struct Var* var2)
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
static void cast_regval(const char* register_name,
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

/* ユーザー定義関数関連
 */

/* 関数呼び出し
 */
static void __call_user_function(const char* iden)
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
static void __define_user_function_begin(const char* iden,
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
        inc_cur_scope_depth();
        varlist_scope_push();

        /* ローカル変数として @stack_prev_frame を作成し、
         * その後、それのオフセットに 0 をセットする（コンパイル時）
         */
        const char stack_prev_frame_iden[] = "@stack_prev_frame";
        varlist_add_local(stack_prev_frame_iden, NULL, 0, 0, TYPE_AUTO);
        varlist_set_scope_head();

        /* スタック上に格納された引数順序と対応した順序となるように、ローカル変数を作成していく。
         * （作成したローカル変数へ値を代入する手間が省ける）
         */
        int32_t i;
        for (i = 0; i < arglen; i++) {
                char iden[0x1000];
                idenlist_pop(iden);

                varlist_add_local(iden, NULL, 0, 0, TYPE_INT | TYPE_AUTO);

                /* 変数のスペックを得る。（コンパイル時） */
                struct Var* var = varlist_search_local(iden);
                if (var == NULL)
                        yyerror("system err: functionによる関数定義において、ローカル変数の作成に失敗しました");
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
static void __define_user_function_return(void)
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
static void __define_user_function_end(const int32_t skip_label)
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
        dec_cur_scope_depth();
        varlist_scope_pop();

        /* 通常フロー中では、この関数定義を読み飛ばし、ここへとジャンプしてくる前提
         * また、この skip_label の値は、
         * この関数とペアで呼ばれる関数 __define_user_function_begin() へのそれと同じ値である前提。
         */
        pA("LB(0, %d);", skip_label);
}

/* 共通アキュムレーター
 */

typedef void (*void_func)(void);

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
static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
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

static struct Var*
__var_func_eq_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL == fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

static struct Var*
__var_func_ne_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL != fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

static struct Var*
__var_func_lt_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL < fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

static struct Var*
__var_func_gt_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL > fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

static struct Var*
__var_func_le_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL <= fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

static struct Var*
__var_func_ge_new(struct Var* var1, struct Var* var2)
{
        struct Var* var0 = new_var();

        __var_func_eq_common(var1, var2);

        pA("if (fixL >= fixR) {fixA = 1;} else {fixA = 0;}");
        push_stack("fixA");

        return var0;
}

static struct Var*
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

/* ExpressionContainer 関連
 */

/* EC の演算種類を示すフラグ
 */
#define EC_ASSIGNMENT           1       /* 代入 */
#define EC_CONDITIONAL          3       /* (a == b) ? x : y; 構文による分岐 */
#define EC_CALC                 5       /* 二項演算。論理演算(a || b など)も含む */
#define EC_UNARY                7       /* 前置演算子による演算 */
#define EC_POSTFIX              8       /* 後置演算子による演算 */
#define EC_PRIMARY              9       /* 参照演算 */
#define EC_CONSTANT             10      /* 定数 */
#define EC_CAST                 11      /* 型変換 */
#define EC_ARGUMENT_EXPRESSION_LIST 12  /* 関数コール時の引数リスト */
#define EC_EXPRESSION           13      /* expression単位 */
#define EC_EXPRESSION_STATEMENT 14      /* expression命令 */
#define EC_INLINE_ASSEMBLER_STATEMENT 15 /* inline_assembler命令 */
#define EC_JUMP_STATEMENT       16      /* jump命令 */
#define EC_ITERATION_STATEMENT  17      /* 反復命令 */
#define EC_SELECTION_STATEMENT  18      /* 分岐命令 */
#define EC_COMPOUND_STATEMENT   19      /* 命令ブロック */
#define EC_LABELED_STATEMENT    20      /* ラベル定義命令 */
#define EC_STATEMENT            21      /* 命令単位 */
#define EC_STATEMENT_LIST       22      /* 命令リスト */
#define EC_DECLARATION          23      /* 宣言命令単位 */
#define EC_DECLARATION_LIST     24      /* 宣言命令リスト */
#define EC_INIT_DECLARATOR      25      /* 初期宣言単位 */
#define EC_INIT_DECLARATOR_LIST 26      /* 初期化宣言リスト */
#define EC_DECLARATOR           27      /* 宣言単位 */
#define EC_DIRECT_DECLARATOR    28      /* 間接参照を伴わない宣言単位 */
#define EC_PARAMETER_TYPE_LIST  29      /* 関数引数リストのラッパー */
#define EC_PARAMETER_LIST       30      /* 関数引数リスト */
#define EC_PARAMETER_DECLARATION 31     /* 関数引数の宣言命令単位 */
#define EC_FUNCTION_DEFINITION  32      /* 関数定義 */

/* EC の演算子を示すフラグ
 */
#define EC_OPE_MUL              1
#define EC_OPE_DIV              2
#define EC_OPE_MOD              3
#define EC_OPE_ADD              4
#define EC_OPE_SUB              5
#define EC_OPE_LSHIFT           6
#define EC_OPE_RSHIFT           7
#define EC_OPE_AND              8
#define EC_OPE_OR               9
#define EC_OPE_XOR              10
#define EC_OPE_INV              29      /* ~ */
#define EC_OPE_NOT              11      /* ! */
#define EC_OPE_EQ               12      /* == */
#define EC_OPE_NE               13      /* != */
#define EC_OPE_LT               14      /* < */
#define EC_OPE_GT               15      /* > */
#define EC_OPE_LE               16      /* <= */
#define EC_OPE_GE               17      /* >= */
#define EC_OPE_LOGICAL_AND      18      /* && */
#define EC_OPE_LOGICAL_OR       19      /* || */
#define EC_OPE_INC              20      /* ++ */
#define EC_OPE_DEC              21      /* -- */
#define EC_OPE_ADDRESS          22      /* & によるアドレス取得 */
#define EC_OPE_POINTER          23      /* ポインター * によるアクセス */
#define EC_OPE_SIZEOF           24      /* sizeof */
#define EC_OPE_ARRAY            25      /* [] による配列アクセス */
#define EC_OPE_FUNCTION         26      /* f() による関数コール */
#define EC_OPE_DIRECT_STRUCT    27      /* . による構造体メンバーへの直接アクセス */
#define EC_OPE_INDIRECT_STRUCT  28      /* -> による構造体メンバーへの間接アクセス */
#define EC_OPE_VARIABLE         29      /* 変数アクセス */
#define EC_OPE_SUBST            30      /* = */
#define EC_OPE_LIST             31      /* , によって列挙されたリスト */
#define EC_OPE_CAST             32      /* 型変換 */
#define EC_OPE_GOTO             33
#define EC_OPE_RETURN           34
#define EC_OPE_ASM_STATEMENT    35      /* アセンブラ命令リスト */
#define EC_OPE_ASM_SUBST_VTOR   36      /* 変数からレジスターへの代入 */
#define EC_OPE_ASM_SUBST_RTOV   37      /* レジスターから変数への代入 */
#define EC_OPE_IF               38
#define EC_OPE_WHILE            39
#define EC_OPE_DO_WHILE         40
#define EC_OPE_FOR              41

/* EC (ExpressionContainer)
 * 構文解析の expression_statement 以下から終端記号までの情報を保持するためのコンテナ
 *
 * type_operator: 演算子
 * type_expression: 演算種類
 * child_ptr[]: この EC をルートとして広がる枝ECへのポインター
 * child_len: child_ptr[] に登録されている枝の数
 */
struct EC {
        char iden[IDENLIST_STR_LEN];
        struct Var* var;
        uint32_t type_operator;
        uint32_t type_expression;
        struct EC* child_ptr[4];
        int32_t child_len;
};

/* 白紙のECインスタンスをメモリー領域を確保して生成
 */
static struct EC* new_ec(void)
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
static void delete_ec(struct EC* ec)
{
        free((void*)ec);
}

/* EC木のアセンブラへの翻訳関連
 */

static void translate_ec(struct EC* ec)
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

%}

%union {
        int32_t ival;
        float fval;
        char sval[0x1000];
        int32_t ival_list[0x400];
        struct VarList* varlistptr;
        struct Var* varptr;
        struct StructSpec* structspecptr;
        struct StructMemberSpec* structmemberspecptr;
        struct EC* ec;
}

%token __STATE_IF __STATE_ELSE
%token __STATE_SWITCH __STATE_CASE __STATE_DEFAULT
%token __OPE_SELECTION
%token __STATE_WHILE __STATE_DO
%token __STATE_FOR
%token __STATE_READ __STATE_DATA
%token __STATE_GOTO __STATE_RETURN __STATE_CONTINUE __STATE_BREAK

%token __OPE_SUBST
%token __OPE_AND_SUBST __OPE_OR_SUBST __OPE_XOR_SUBST
%token __OPE_LSHIFT_SUBST __OPE_RSHIFT_SUBST
%token __OPE_ADD_SUBST __OPE_SUB_SUBST
%token __OPE_MUL_SUBST __OPE_DIV_SUBST __OPE_MOD_SUBST
%token __OPE_INC __OPE_DEC

%token __OPE_SIZEOF

%token __OPE_LOGICAL_OR __OPE_LOGICAL_AND

%token __TYPE_VOID
%token __TYPE_CHAR __TYPE_SHORT __TYPE_INT __TYPE_LONG
%token __TYPE_FLOAT __TYPE_DOUBLE
%token __TYPE_SIGNED __TYPE_UNSIGNED

%token __TYPE_AUTO __TYPE_REGISTER
%token __TYPE_STATIC __TYPE_EXTERN
%token __TYPE_TYPEDEF

%token __TYPE_CONST
%token __TYPE_VOLATILE

%token __TYPE_STRUCT __TYPE_UNION __TYPE_ENUM

%token __STATE_ASM
%token __STATE_FUNCTION

%left  __OPE_EQ __OPE_NE __OPE_LT __OPE_LE __OPE_GT __OPE_GE
%left  __OPE_ADD __OPE_SUB
%left  __OPE_MUL __OPE_DIV __OPE_MOD
%left  __OPE_OR __OPE_AND __OPE_XOR __OPE_INVERT __OPE_NOT
%left  __OPE_LSHIFT __OPE_RSHIFT
%left  __OPE_COMMA __OPE_COLON __OPE_DOT __OPE_ARROW __OPE_VALEN
%token __OPE_PLUS __OPE_MINUS
%token __OPE_ADDRESS __OPE_POINTER
%token __LB __RB __DECL_END __IDENTIFIER __DEFINE_LABEL __EOF
%token __ARRAY_LB __ARRAY_RB
%token __BLOCK_LB __BLOCK_RB

%token __INTEGER_CONSTANT __CHARACTER_CONSTANT __FLOATING_CONSTANT
%token __STRING_CONSTANT

%type <ival> __INTEGER_CONSTANT
%type <fval> __FLOATING_CONSTANT
%type <ival> __CHARACTER_CONSTANT
%type <sval> __STRING_CONSTANT string
%type <sval> __IDENTIFIER __DEFINE_LABEL

%type <ival> declaration_specifiers
%type <ival> type_specifier type_specifier_unit
%type <ival> pointer

%type <ec> function_definition
%type <ec> declaration
%type <ec> declaration_list

%type <ec> init_declarator_list
%type <ec> init_declarator
%type <ec> declarator
%type <ec> direct_declarator

%type <ec> parameter_type_list
%type <ec> parameter_list
%type <ec> parameter_declaration

%type <ec> initializer

%type <ec> statement
%type <ec> inline_assembler_statement
%type <ec> labeled_statement
%type <ec> expression_statement
%type <ec> compound_statement
%type <ec> statement_list
%type <ec> selection_statement
%type <ec> iteration_statement
%type <ec> jump_statement
%type <ec> expression
%type <ec> assignment_expression
%type <ec> conditional_expression
%type <ec> logical_or_expression
%type <ec> logical_and_expression
%type <ec> inclusive_or_expression
%type <ec> exclusive_or_expression
%type <ec> and_expression
%type <ec> equality_expression
%type <ec> relational_expression
%type <ec> shift_expression
%type <ec> additive_expression
%type <ec> multiplicative_expression
%type <ec> cast_expression
%type <ec> unary_expression
%type <ec> postfix_expression
%type <ec> primary_expression
%type <ec> argument_expression_list
%type <ec> constant

%type <ival_list> initializer_param

%type <sval> define_struct
%type <structspecptr> initializer_struct_member_list
%type <varlistptr> initializer_struct_member

%type <ival> __storage_class_specifier __type_specifier __type_qualifier

%start translation_unit

%%

translation_unit
        : __EOF {
                YYACCEPT;
        }
        | external_declaration
        | external_declaration translation_unit
        ;

external_declaration
        : function_definition {
                translate_ec($1);
        }
        | declaration {
                translate_ec($1);
        }
        ;

function_definition
        : declaration_specifiers declarator compound_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_FUNCTION_DEFINITION;
                ec->var->type = $1;
                ec->child_ptr[0] = $2;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

declaration
        : declaration_specifiers init_declarator_list __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_DECLARATION;
                ec->var->type = $1;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | statement
        | define_struct
        ;

declaration_list
        : /* empty */ {
                struct EC* ec = new_ec();
                ec->type_expression = EC_DECLARATION_LIST;
                $$ = ec;
        }
        | declaration {
                struct EC* ec = new_ec();
                ec->type_expression = EC_DECLARATION_LIST;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | declaration declaration_list {
                struct EC* ec = new_ec();
                ec->type_expression = EC_DECLARATION_LIST;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $2;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

declaration_specifiers
        : /* empty */ {
                $$ = 0;
        }
        | type_specifier
        | type_specifier declaration_specifiers {
                $$ = $1 | $2;
        }
        ;

type_specifier
        : type_specifier_unit
        | type_specifier_unit type_specifier {
                $$ = $1 | $2;
        }
        ;

type_specifier_unit
        : __TYPE_VOID {
                $$ = TYPE_VOID;
        }
        | __TYPE_CHAR {
                $$ = TYPE_CHAR;
        }
        | __TYPE_SHORT {
                $$ = TYPE_SHORT;
        }
        | __TYPE_INT {
                $$ = TYPE_INT;
        }
        | __TYPE_LONG {
                $$ = TYPE_LONG;
        }
        | __TYPE_FLOAT {
                $$ = TYPE_FLOAT;
        }
        | __TYPE_DOUBLE {
                $$ = TYPE_DOUBLE;
        }
        | __TYPE_SIGNED {
                $$ = TYPE_SIGNED;
        }
        | __TYPE_UNSIGNED {
                $$ = TYPE_UNSIGNED;
        }
        ;

init_declarator_list
        : init_declarator
        | init_declarator_list __OPE_COMMA init_declarator {
                struct EC* ec = new_ec();
                ec->type_expression = EC_INIT_DECLARATOR_LIST;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

init_declarator
        : declarator
        | declarator __OPE_SUBST initializer {
                struct EC* ec = new_ec();
                ec->type_expression = EC_INIT_DECLARATOR;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

declarator
        : pointer direct_declarator {
                struct EC* ec = $2;
                ec->type_expression = EC_DECLARATOR;
                ec->var->indirect_len += $1;
                $$ = ec;
        }
        ;

direct_declarator
        : __IDENTIFIER {
                struct EC* ec = new_ec();
                ec->type_expression = EC_DIRECT_DECLARATOR;
                strcpy(ec->var->iden, $1);
                $$ = ec;
        }
        | __LB declarator __RB {
                $$ = $2;
        }
        | direct_declarator __ARRAY_LB __INTEGER_CONSTANT __ARRAY_RB {
                struct EC* ec = $1;
                ec->var->unit_len[ec->var->dim_len] = $3;
                ec->var->dim_len++;
                $$ = ec;

        }
        | direct_declarator __LB parameter_type_list __RB {
                struct EC* ec = $1;
                ec->var->type |= TYPE_FUNCTION;
                ec->child_ptr[0] = $3;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

pointer
        : /* empty */ {
                $$ = 0;
        }
        | __OPE_MUL %prec __OPE_POINTER {
                $$ = 1;
        }
        | __OPE_MUL pointer %prec __OPE_POINTER {
                $$ = 1 + $2;
        }
        ;

parameter_type_list
        : /* empty */ {
                struct EC* ec = new_ec();
                ec->type_expression = EC_PARAMETER_TYPE_LIST;
                $$ = ec;
        }
        | parameter_list {
                struct EC* ec = new_ec();
                ec->type_expression = EC_PARAMETER_TYPE_LIST;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

parameter_list
        : parameter_declaration {
                struct EC* ec = new_ec();
                ec->type_expression = EC_PARAMETER_LIST;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | parameter_list __OPE_COMMA parameter_declaration {
                struct EC* ec = new_ec();
                ec->type_expression = EC_PARAMETER_LIST;
                ec->child_ptr[0] = $3; /* 引数順序を前後逆転するため */
                ec->child_ptr[1] = $1;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

parameter_declaration
        : declaration_specifiers declarator {
                struct EC* ec = new_ec();
                ec->type_expression = EC_PARAMETER_DECLARATION;
                ec->var->type = $1;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

initializer_param
        : /* empty */ {
                $$[0] = 0;
                $$[1] = 0;
        }
        | __ARRAY_LB __INTEGER_CONSTANT __ARRAY_RB {
                $$[0] = 1;
                $$[1] = $2;
        }
        | __ARRAY_LB __INTEGER_CONSTANT __ARRAY_RB initializer_param {
                int32_t head = $4[0] + 1;
                int32_t i;
                for (i = 0; i < head; i++)
                        $$[i] = $4[i];

                $$[0] = head;
                $$[head] = $2;
        }
        ;

initializer
        : assignment_expression
        ;

initializer_struct_member
        : type_specifier pointer __IDENTIFIER initializer_param {
                struct VarList* vl = malloc(sizeof(*vl));
                vl->var[0] = structmemberspec_new($3, &($4[1]), $4[0], $2, $1);
                vl->varlist_len = 1;

                $$ = vl;
        }
        | initializer_struct_member __OPE_COMMA pointer __IDENTIFIER initializer_param {
                const int32_t type = $1->var[0]->type;
                $1->var[$1->varlist_len] = structmemberspec_new($4, &($5[1]), $5[0], $3, type);

                $$ = $1;
        }
        ;

initializer_struct_member_list
        : {
                $$ = structspec_new();
        }
        | initializer_struct_member __DECL_END {
                struct StructSpec* spec = structspec_new();

                int32_t i;
                for (i = 0; i < $1->varlist_len; i++) {
                        structspec_add_member(spec, $1->var[i]);
                }

                free($1);

                $$ = spec;
        }
        | initializer_struct_member_list initializer_struct_member __DECL_END {
                int32_t i;
                for (i = 0; i < $2->varlist_len; i++) {
                        structspec_add_member($1, $2->var[i]);
                }

                free($2);

                $$ = $1;
        }
        ;

define_struct
        : __TYPE_STRUCT __IDENTIFIER
          __BLOCK_LB initializer_struct_member_list __BLOCK_RB __DECL_END
        {
                structspec_set_iden($4, $2);
                structspec_ptrlist_add($4);
        }
        ;

statement
        : labeled_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | expression_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | compound_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | selection_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | iteration_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | jump_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | inline_assembler_statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

labeled_statement
        : __DEFINE_LABEL {
                struct EC* ec = new_ec();
                ec->type_expression = EC_LABELED_STATEMENT;
                strcpy(ec->var->iden, $1);
                $$ = ec;
        }
        ;

statement_list
        : /* empty */ {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT_LIST;
                $$ = ec;
        }
        | statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT_LIST;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | statement_list statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_STATEMENT_LIST;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $2;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

expression_statement
        : __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_EXPRESSION_STATEMENT;
                $$ = ec;
        }
        | expression __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_EXPRESSION_STATEMENT;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

compound_statement
        : __BLOCK_LB __BLOCK_RB {
                struct EC* ec = new_ec();
                ec->type_expression = EC_COMPOUND_STATEMENT;
                $$ = ec;
        }
        | __BLOCK_LB declaration_list statement_list __BLOCK_RB {
                struct EC* ec = new_ec();
                ec->type_expression = EC_COMPOUND_STATEMENT;
                ec->child_ptr[0] = $2;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

selection_statement
        : __STATE_IF __LB expression __RB statement __STATE_ELSE statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_SELECTION_STATEMENT;
                ec->type_operator = EC_OPE_IF;
                ec->child_ptr[0] = $3;
                ec->child_ptr[1] = $5;
                ec->child_ptr[2] = $7;
                ec->child_len = 3;
                $$ = ec;
        }
        | __STATE_IF __LB expression __RB statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_SELECTION_STATEMENT;
                ec->type_operator = EC_OPE_IF;
                ec->child_ptr[0] = $3;
                ec->child_ptr[1] = $5;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

iteration_statement
        : __STATE_WHILE __LB expression __RB statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_ITERATION_STATEMENT;
                ec->type_operator = EC_OPE_WHILE;
                ec->child_ptr[0] = $3;
                ec->child_ptr[1] = $5;
                ec->child_len = 2;
                $$ = ec;
        }
        | __STATE_FOR __LB expression __DECL_END expression __DECL_END expression __RB statement {
                struct EC* ec = new_ec();
                ec->type_expression = EC_ITERATION_STATEMENT;
                ec->type_operator = EC_OPE_FOR;
                ec->child_ptr[0] = $3;
                ec->child_ptr[1] = $5;
                ec->child_ptr[2] = $7;
                ec->child_ptr[3] = $9;
                ec->child_len = 4;
                $$ = ec;
        }
        ;

jump_statement
        : __STATE_GOTO __IDENTIFIER __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_JUMP_STATEMENT;
                ec->type_operator = EC_OPE_GOTO;
                strcpy(ec->var->iden, $2);
                $$ = ec;
        }
        | __STATE_RETURN expression __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_JUMP_STATEMENT;
                ec->type_operator = EC_OPE_RETURN;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __STATE_RETURN __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_JUMP_STATEMENT;
                ec->type_operator = EC_OPE_RETURN;
                $$ = ec;
        }
        ;

expression
        : assignment_expression
        | expression __OPE_COMMA assignment_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_EXPRESSION;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

assignment_expression
        : conditional_expression
        | unary_expression __OPE_SUBST assignment_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_ASSIGNMENT;
                ec->type_operator = EC_OPE_SUBST;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

conditional_expression
        : logical_or_expression
        ;

logical_or_expression
        : logical_and_expression
        ;

logical_and_expression
        : inclusive_or_expression
        ;

inclusive_or_expression
        : exclusive_or_expression
        | inclusive_or_expression __OPE_OR exclusive_or_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_OR;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

exclusive_or_expression
        : and_expression
        | exclusive_or_expression __OPE_XOR and_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_XOR;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

and_expression
        : equality_expression
        | and_expression __OPE_AND equality_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_AND;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

equality_expression
        : relational_expression
        | equality_expression __OPE_EQ relational_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_EQ;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | equality_expression __OPE_NE relational_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_NE;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

relational_expression
        : shift_expression
        | relational_expression __OPE_LT shift_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_LT;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | relational_expression __OPE_GT shift_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_GT;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | relational_expression __OPE_LE shift_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_LE;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | relational_expression __OPE_GE shift_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_GE;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

shift_expression
        : additive_expression
        | shift_expression __OPE_LSHIFT additive_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_LSHIFT;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | shift_expression __OPE_RSHIFT additive_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_RSHIFT;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

additive_expression
        : multiplicative_expression
        | additive_expression __OPE_ADD multiplicative_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_ADD;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | additive_expression __OPE_SUB multiplicative_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_SUB;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

multiplicative_expression
        : cast_expression
        | multiplicative_expression __OPE_MUL cast_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_MUL;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | multiplicative_expression __OPE_DIV cast_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_DIV;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | multiplicative_expression __OPE_MOD cast_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_MOD;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

cast_expression
        : unary_expression {
        }
        | __LB type_specifier pointer __RB cast_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CAST;
                ec->type_operator = EC_OPE_CAST;
                ec->var->indirect_len = $3;
                ec->var->type = $2;
                ec->child_ptr[0] = $5;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

unary_expression
        : postfix_expression
        | __OPE_AND cast_expression %prec __OPE_ADDRESS {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_ADDRESS;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __OPE_MUL cast_expression %prec __OPE_POINTER {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_POINTER;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __OPE_ADD cast_expression %prec __OPE_PLUS {
                $$ = $2;
        }
        | __OPE_SUB cast_expression %prec __OPE_MINUS {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_SUB;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __OPE_INVERT cast_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_INV;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __OPE_NOT cast_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_NOT;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __OPE_SIZEOF unary_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_SIZEOF;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

postfix_expression
        : primary_expression
        | postfix_expression __ARRAY_LB expression __ARRAY_RB {
                struct EC* ec = new_ec();
                ec->type_expression = EC_POSTFIX;
                ec->type_operator = EC_OPE_ARRAY;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | __IDENTIFIER __LB argument_expression_list __RB {
                struct EC* ec = new_ec();
                ec->type_expression = EC_POSTFIX;
                ec->type_operator = EC_OPE_FUNCTION;

                ec->var->type = TYPE_FUNCTION | TYPE_SIGNED | TYPE_INT;
                strcpy(ec->var->iden, $1);

                ec->child_ptr[0] = $3;
                ec->child_len = 1;
                $$ = ec;
        }
        ;

primary_expression
        : __IDENTIFIER {
                struct EC* ec = new_ec();
                ec->type_expression = EC_PRIMARY;
                ec->type_operator = EC_OPE_VARIABLE;
                strcpy(ec->iden, $1);
                ec->child_len = 0;
                $$ = ec;
        }
        | constant
        | __LB expression __RB {
                $$ = $2;
        }
        ;

argument_expression_list
        : {
                struct EC* ec = new_ec();
                ec->type_expression = EC_ARGUMENT_EXPRESSION_LIST;
                ec->child_len = 0;
                $$ = ec;
        }
        | assignment_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_ARGUMENT_EXPRESSION_LIST;
                ec->child_ptr[0] = $1;
                ec->child_len = 1;
                $$ = ec;
        }
        | argument_expression_list __OPE_COMMA assignment_expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_ARGUMENT_EXPRESSION_LIST;
                ec->child_ptr[0] = $3; /* 引数の最後側をリストの先頭側とするため */
                ec->child_ptr[1] = $1;
                ec->child_len = 2;
                $$ = ec;
        }
        ;

string
        : __STRING_CONSTANT
        | string __STRING_CONSTANT {
                strcpy($$, $1);
                strcat($$, $2);
        }
        ;

inline_assembler_statement
        : __STATE_ASM __LB string __RB  __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_INLINE_ASSEMBLER_STATEMENT;
                ec->type_operator = EC_OPE_ASM_STATEMENT;
                ec->var->const_variable = malloc(strlen($3) + 1);
                strcpy(ec->var->const_variable, $3);
                $$ = ec;
        }
        | __STATE_ASM __LB string __OPE_SUBST assignment_expression __RB __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_INLINE_ASSEMBLER_STATEMENT;
                ec->type_operator = EC_OPE_ASM_SUBST_VTOR;
                ec->child_ptr[0] = $5;
                ec->child_len = 1;
                strcpy(ec->iden, $3);
                $$ = ec;
        }
        | __STATE_ASM __LB unary_expression __OPE_SUBST string __RB __DECL_END {
                struct EC* ec = new_ec();
                ec->type_expression = EC_INLINE_ASSEMBLER_STATEMENT;
                ec->type_operator = EC_OPE_ASM_SUBST_RTOV;
                ec->child_ptr[0] = $3;
                ec->child_len = 1;
                ec->var->const_variable = malloc(strlen($5) + 1);
                strcpy(ec->iden, $5);
                $$ = ec;
        }
        ;

constant
        : __INTEGER_CONSTANT {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CONSTANT;
                sprintf(ec->iden, "@%d", $1);
                varlist_add_global(ec->iden, NULL, 0, 0, TYPE_SIGNED | TYPE_INT | TYPE_LITERAL);

                ec->var->const_variable = malloc(sizeof(int));
                *((int*)(ec->var->const_variable)) = $1;

                $$ = ec;
        }
        | __CHARACTER_CONSTANT {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CONSTANT;
                sprintf(ec->iden, "@%d", $1);
                varlist_add_global(ec->iden, NULL, 0, 0, TYPE_SIGNED | TYPE_CHAR | TYPE_LITERAL);

                ec->var->const_variable = malloc(sizeof(int));
                *((int*)(ec->var->const_variable)) = $1;

                $$ = ec;
        }
        | __FLOATING_CONSTANT {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CONSTANT;
                sprintf(ec->iden, "@%f", $1);
                varlist_add_global(ec->iden, NULL, 0, 0, TYPE_FLOAT | TYPE_LITERAL);

                double a;
                double b = modf($1, &a);
                int32_t ia = ((int32_t)a) << 16;
                int32_t ib = ((int32_t)(0x0000ffff * b)) & 0x0000ffff;

                ec->var->const_variable = malloc(sizeof(int));
                *((int*)(ec->var->const_variable)) = ia | ib; /* 実際は固定小数なのでint */

                $$ = ec;
        }
        ;

__translation_unit
        : __external_declaration
        | __translation_unit __external_declaration
        ;

__external_declaration
        : __function_declaration
        | __declaration
        ;

__function_declaration
        : __declaration_specifiers __declarator __declaration_list __compound_statement
        ;

__declaration
        : __declaration_specifiers __init_declarator_list __DECL_END
        ;

__declaration_list
        : /* empty */
        | __declaration
        | __declaration_list __declaration
        ;

__declaration_specifiers
        : /* empty */
        | __storage_class_specifier __declaration_specifiers
        | __type_specifier __declaration_specifiers
        | __type_qualifier __declaration_specifiers
        ;

__storage_class_specifier
        : __TYPE_AUTO
        | __TYPE_REGISTER
        | __TYPE_STATIC
        | __TYPE_EXTERN
        | __TYPE_TYPEDEF
        ;

__type_specifier
        : __TYPE_VOID
        | __TYPE_CHAR
        | __TYPE_SHORT
        | __TYPE_INT
        | __TYPE_LONG
        | __TYPE_FLOAT
        | __TYPE_DOUBLE
        | __TYPE_SIGNED
        | __TYPE_UNSIGNED
        | __struct_or_union_specifier
        | __enum_specifier
        | __typedef_name
        ;

__type_qualifier
        : __TYPE_CONST
        | __TYPE_VOLATILE
        ;

__struct_or_union_specifier
        : __struct_or_union __identifier __BLOCK_LB __struct_declaration_list __BLOCK_RB
        | __struct_or_union __identifier
        ;

__struct_or_union
        : __TYPE_STRUCT
        | __TYPE_UNION
        ;

__struct_declaration_list
        : __struct_declaration
        | __struct_declaration_list __struct_declaration
        ;

__init_declarator_list
        : /* empty */
        | __init_declarator
        | __init_declarator_list __OPE_COMMA __init_declarator
        ;

__init_declarator
        : __declarator
        | __declarator __OPE_SUBST __initializer
        ;

__struct_declaration
        : __specifier_qualifier_list __struct_declaration_list __DECL_END
        ;

__specifier_qualifier_list
        : /* empty */
        | __type_specifier __specifier_qualifier_list
        | __type_qualifier __specifier_qualifier_list
        ;

__struct_declarator_list
        : __struct_declarator
        | __struct_declarator_list __OPE_COMMA __struct_declarator
        ;

__struct_declarator
        : __declarator
        | __declarator __OPE_COLON __constant_expression
        ;

__enum_specifier
        : __TYPE_ENUM __identifier __BLOCK_LB __enumerator_list __BLOCK_RB
        | __TYPE_ENUM __identifier
        ;

__enumerator_list
        : __enumerator
        | __enumerator_list __OPE_COMMA __enumerator
        ;

__enumerator
        : __identifier
        | __identifier __OPE_SUBST __constant_expression
        ;

__declarator
        : /* empty */
        | __pointer __direct_declarator
        ;

__direct_declarator
        : __identifier
        | __LB __declarator __RB
        | __direct_declarator __ARRAY_LB __constant_expression __ARRAY_RB
        | __direct_declarator __LB __parameter_type_list __RB
        | __direct_declarator __LB __identifier_list __RB
        ;

__pointer
        : /* empty */
        | __OPE_MUL __type_qualifier_list %prec __OPE_POINTER
        | __OPE_MUL __type_qualifier_list __pointer %prec __OPE_POINTER
        ;

__type_qualifier_list
        : /* empty */
        | __type_qualifier
        | __type_qualifier_list __type_qualifier
        ;

__parameter_type_list
        : /* empty */
        | __parameter_list
        | __parameter_list __OPE_COMMA __OPE_VALEN
        ;

__parameter_list
        : __parameter_declaration
        | __parameter_list __OPE_COMMA __parameter_declaration
        ;

__parameter_declaration
        : __declaration_specifiers __declaration
        | __declaration_specifiers __abstract_declarator
        ;

__identifier_list
        : /* empty */
        | __identifier
        | __identifier_list __OPE_COMMA __identifier
        ;

__initializer
        : __assignment_expression
        | __BLOCK_LB __initializer_list __BLOCK_RB
        | __BLOCK_LB __initializer_list __OPE_COMMA __BLOCK_RB
        ;

__initializer_list
        : __initializer
        | __initializer_list __OPE_COMMA __initializer
        ;

__type_name
        : __specifier_qualifier_list __abstract_declarator
        ;

__abstract_declarator
        : /* empty */
        | __pointer
        | __pointer __direct_abstract_declarator
        ;

__direct_abstract_declarator
        : /* empty */
        | __LB __abstract_declarator __RB
        | __direct_abstract_declarator __ARRAY_LB __constant_expression __ARRAY_RB
        | __direct_abstract_declarator __LB __parameter_type_list __RB
        ;

__typedef_name
        : __identifier
        ;

__statement
        : __labeled_statement
        | __expression_statement
        | __compound_statement
        | __selection_statement
        | __iteration_statement
        | __jump_statement
        ;

__labeled_statement
        : __identifier __OPE_COLON __statement
        | __STATE_CASE __constant_expression __OPE_COLON __statement
        | __STATE_DEFAULT __OPE_COLON __statement
        ;

__expression_statement
        : __expression __DECL_END
        ;

__compound_statement
        : __BLOCK_LB __declaration_list __statement_list __BLOCK_RB
        ;

__statement_list
        : /* empty */
        | __statement
        | __statement_list __statement
        ;

__selection_statement
        : __STATE_IF __LB __expression __RB __statement
        | __STATE_IF __LB __expression __RB __statement __STATE_ELSE __statement
        | __STATE_SWITCH __LB expression __RB __statement
        ;

__iteration_statement
        : __STATE_WHILE __LB __expression __RB __statement
        | __STATE_DO __statement __STATE_WHILE __LB __expression __RB __DECL_END
        | __STATE_FOR __LB __expression __DECL_END __expression __DECL_END __expression __RB __statement
        ;

__jump_statement
        : __STATE_GOTO __identifier __DECL_END
        | __STATE_CONTINUE __DECL_END
        | __STATE_BREAK __DECL_END
        | __STATE_RETURN __expression __DECL_END
        ;

__expression
        : /* empty */
        | __assignment_expression
        | __expression __OPE_COMMA __assignment_expression
        ;

__assignment_expression
        : __conditional_expression
        | __unary_expression __assignment_operator __assignment_expression
        ;

__assignment_operator
        : __OPE_SUBST
        | __OPE_MUL_SUBST
        | __OPE_DIV_SUBST
        | __OPE_MOD_SUBST
        | __OPE_ADD_SUBST
        | __OPE_SUB_SUBST
        | __OPE_LSHIFT_SUBST
        | __OPE_RSHIFT_SUBST
        | __OPE_AND_SUBST
        | __OPE_XOR_SUBST
        | __OPE_OR_SUBST
        ;

__conditional_expression
        : __logical_OR_expression
        | __logical_OR_expression __OPE_SELECTION __expression __OPE_COLON __conditional_expression
        ;

__constant_expression
        : /* empty */
        | __conditional_expression
        ;

__logical_OR_expression
        : __logical_AND_expression
        | __logical_OR_expression __OPE_LOGICAL_OR __logical_AND_expression
        ;

__logical_AND_expression
        : __inclusive_OR_expression
        | __logical_AND_expression __OPE_LOGICAL_AND __inclusive_OR_expression
        ;

__inclusive_OR_expression
        : __exclusive_OR_expression
        | __inclusive_OR_expression __OPE_OR __exclusive_OR_expression
        ;

__exclusive_OR_expression
        : __AND_expression
        | __exclusive_OR_expression __OPE_XOR __AND_expression
        ;

__AND_expression
        : __equality_expression
        | __AND_expression __OPE_AND __equality_expression
        ;

__equality_expression
        : __relational_expression
        | __equality_expression __OPE_EQ __relational_expression
        | __equality_expression __OPE_NE __relational_expression
        ;

__relational_expression
        : __shift_expression
        | __relational_expression __OPE_LT __shift_expression
        | __relational_expression __OPE_GT __shift_expression
        | __relational_expression __OPE_LE __shift_expression
        | __relational_expression __OPE_GE __shift_expression
        ;

__shift_expression
        : __additive_expression
        | __shift_expression __OPE_LSHIFT __additive_expression
        | __shift_expression __OPE_RSHIFT __additive_expression
        ;

__additive_expression
        : __multiplicative_expression
        | __additive_expression __OPE_ADD __multiplicative_expression
        | __additive_expression __OPE_SUB __multiplicative_expression
        ;

__multiplicative_expression
        : __cast_expression
        | __multiplicative_expression __OPE_MUL __cast_expression
        | __multiplicative_expression __OPE_DIV __cast_expression
        | __multiplicative_expression __OPE_MOD __cast_expression
        ;

__cast_expression
        : __unary_expression
        | __LB __type_name __RB __cast_expression
        ;

__unary_expression
        : __postfix_expression
        | __OPE_INC __unary_expression
        | __OPE_DEC __unary_expression
        | __unary_operator __cast_expression
        | __OPE_SIZEOF __unary_expression
        | __OPE_SIZEOF __LB __identifier __RB
        ;

__unary_operator
        : __OPE_AND
        | __OPE_MUL
        | __OPE_ADD
        | __OPE_SUB
        | __OPE_INVERT
        | __OPE_NOT
        ;

__postfix_expression
        : __primary_expression
        | __postfix_expression __ARRAY_LB __expression __ARRAY_RB
        | __postfix_expression __LB __argument_expression_list __RB
        | __postfix_expression __OPE_DOT __identifier
        | __postfix_expression __OPE_ARROW __identifier
        | __postfix_expression __OPE_INC
        | __postfix_expression __OPE_DEC
        ;

__primary_expression
        : __identifier
        | __constant
        | __STRING_CONSTANT
        | __LB __expression __RB
        ;

__argument_expression_list
        : /* empty */
        | __assignment_expression
        | __argument_expression_list __OPE_COMMA __assignment_expression
        ;

__constant
        : __INTEGER_CONSTANT
        | __CHARACTER_CONSTANT
        | __FLOATING_CONSTANT
        | __enumeration_constant
        ;

__enumeration_constant
        :
        ;

__identifier
        : /* empty */
        | __IDENTIFIER
        ;

%%
