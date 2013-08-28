/* osecpubasic.bison.y
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

#define YYMAXDEPTH 0x10000000

extern int32_t linenumber;
extern char* linelist[0x10000];

/* 警告表示 */
static void yywarning(const char *s)
{
        printf("line %05d: %s\n", linenumber, s);
        printf("            %s\n", linelist[linenumber]);
}

/* エラー表示 */
void yyerror(const char *s)
{
        yywarning(s);
        exit(EXIT_FAILURE);
}

extern FILE* yyin;
extern FILE* yyout;
extern FILE* yyaskA;
extern FILE* yyaskB;

/* 出力ファイル yyaskA へ文字列を書き出す関数 */
static void pA(const char* fmt, ...)
{
        va_list ap;
        va_start(ap, fmt);

        vfprintf(yyaskA, fmt, ap);
        va_end(ap);

        fputs("\n", yyaskA);
}

/* 出力ファイル yyaskA へ文字列を書き出す関数（改行無し）
 *
 * 主に } else { 用。
 * （elseを挟む中括弧を改行をするとエラーになるので）
 */
static void pA_nl(const char* fmt, ...)
{
        va_list ap;
        va_start(ap, fmt);

        vfprintf(yyaskA, fmt, ap);
        va_end(ap);
}

/* IDENTIFIER 文字列用のスタック */
#define IDENLIST_STR_LEN 0x100
#define IDENLIST_LEN 0x1000
static char* idenlist[IDENLIST_LEN] = {[0 ... IDENLIST_LEN - 1] = NULL};
static int32_t idenlist_head = 0;

/* idenlist に IDENTIFIER 文字列をプッシュする
 *
 * idenlist[idenlist_head]が0の場合はmallocされる。その領域が以後も使いまわされる。
 * （開放はしない。確保したまま）
 */
void idenlist_push(const char* src)
{
        if (idenlist_head >= IDENLIST_LEN)
                yyerror("system err: idenlist_push()");

        if(idenlist[idenlist_head] == NULL)
                idenlist[idenlist_head] = malloc(IDENLIST_STR_LEN);

        strcpy(idenlist[idenlist_head], src);
        idenlist_head++;
}

/* idenlist から文字列をdstへポップする
 *
 * コピー渡しなので、十分な長さが確保されたdstを渡すこと
 */
void idenlist_pop(char* dst)
{
        idenlist_head--;

        if (idenlist_head < 0)
                yyerror("system err: idenlist_pop()");

        strcpy(dst, idenlist[idenlist_head]);
}

#define VAR_STR_LEN IDENLIST_STR_LEN
struct Var {
        char str[VAR_STR_LEN];
        int32_t base_ptr;       /* ベースアドレス */
        int32_t array_len;      /* 配列全体の長さ */
        int32_t col_len;        /* 行の長さ */
        int32_t row_len;        /* 列の長さ */
};

#define VARLIST_LEN 0x1000
static struct Var varlist[VARLIST_LEN];

/* varlist の現在の先頭から数えて最初の空位置 */
static int32_t varlist_head = 0;

/* varlist のスコープ位置を記録しておくスタック */
#define VARLIST_SCOPE_LEN VARLIST_LEN
static int32_t varlist_scope[VARLIST_SCOPE_LEN] = {[0] = 0};
static int32_t varlist_scope_head = 0;

/* 現在のvarlist_headの値をvarlist_scopeへプッシュする
 *
 * これを現在のスコープ位置と考えることで、
 * varlist_scope[varlist_scope_head] 位置から varlist_head 未満までをローカル変数と考える場合に便利。
 * varlist_scope_head に連動させて varlist_head を操作するだけで、ローカル変数を破棄できる。
 */
static void varlist_scope_push(void)
{
        varlist_scope_head++;

        if (varlist_scope_head >= VARLIST_SCOPE_LEN)
                yyerror("system err: varlist_scope_push()");

        varlist_scope[varlist_scope_head] = varlist_head;
}

/* varlist_scopeからポップし、varlist_headへセットする
 */
static void varlist_scope_pop(void)
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
static struct Var* varlist_search_common(const char* str, const int32_t varlist_bottom)
{
        int32_t i = varlist_head;
        while (i-->varlist_bottom) {
                if (strcmp(str, varlist[i].str) == 0)
                        return &(varlist[i]);
        }

        return NULL;
}

/* 変数リストに既に同名が登録されているかを、最後尾側（varlist_head側）から現在のスコープの範囲内で確認する。
 * 確認する順序は最後尾側から開始して、現在のスコープ側へと向かう方向。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
static struct Var* varlist_search_local(const char* str)
{
        return varlist_search_common(str, varlist_scope[varlist_scope_head]);
}

/* 変数リストに既に同名が登録されているかを、最後尾側（varlist_head側）からvarlistの先頭まで確認してくる。
 * 確認する順序は最後尾側から開始して、varlistの先頭側へと向かう方向。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
static struct Var* varlist_search(const char* str)
{
        return varlist_search_common(str, 0);
}

/* 変数リストに新たに変数を無条件に追加する。
 * 既に同名の変数が存在するかの確認は行わない。常に追加する。
 * row_len : この変数の行（たて方向、y方向）の長さを指定する。 スカラーまたは１次元配列の場合は 1 でなければならない。
 * col_len : この変数の列（よこ方向、x方向）の長さを指定する。 スカラーならば 1 でなければならない。
 * これらの値はint32型。（fix32型ではないので注意)
 *
 * col_len, row_len に 1 未満の数を指定した場合は syntax err となる。
 *
 * varlist_add() および varlist_add_local() の共通ルーチンを抜き出したもの。
 */
static void varlist_add_common(const char* str, const int32_t row_len, const int32_t col_len)
{
        if (row_len <= 0)
                yyerror("syntax err: 配列の行（たて方向、y方向）サイズに0を指定しました");

        if (col_len <= 0)
                yyerror("syntax err: 配列の列（よこ方向、x方向）サイズに0を指定しました");

        struct Var* cur = varlist + varlist_head;
        struct Var* prev = varlist + varlist_head - 1;

        strcpy(cur->str, str);
        cur->col_len = col_len;
        cur->row_len = row_len;
        cur->array_len = col_len * row_len;
        cur->base_ptr = (varlist_head == 0) ? 0 : prev->base_ptr + prev->array_len;

        varlist_head++;
}

/* 変数リストに新たにローカル変数を追加する。
 * 現在のスコープ内に重複する同名のローカル変数が存在した場合は何もしない。
 * row_len : この変数の行（たて方向、y方向）の長さを指定する。 スカラーまたは１次元配列の場合は 1 でなければならない。
 * col_len : この変数の列（よこ方向、x方向）の長さを指定する。 スカラーならば 1 でなければならない。
 * これらの値はint32型。（fix32型ではないので注意)
 *
 * col_len, row_len に 1 未満の数を指定した場合は syntax err となる。
 */
static void varlist_add_local(const char* str, const int32_t row_len, const int32_t col_len)
{
        if (varlist_search_local(str) != NULL)
                return;

        varlist_add_common(str, row_len, col_len);
}

/* 変数リストに新たに変数を追加する。
 * 既に同名の変数が存在した場合は何もしない。
 * row_len : この変数の行（たて方向、y方向）の長さを指定する。 スカラーまたは１次元配列の場合は 1 でなければならない。
 * col_len : この変数の列（よこ方向、x方向）の長さを指定する。 スカラーならば 1 でなければならない。
 * これらの値はint32型。（fix32型ではないので注意)
 *
 * col_len, row_len に 1 未満の数を指定した場合は syntax err となる。
 */
static void varlist_add(const char* str, const int32_t row_len, const int32_t col_len)
{
        if (varlist_search(str) != NULL)
                return;

        varlist_add_common(str, row_len, col_len);
}

/* 任意のレジスターの値をスタックにプッシュする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
static void push_stack_direct(const char* register_name)
{
        pA("PASMEM0(%s, T_SINT32, stack_ptr, stack_head);", register_name);
        pA("stack_head++;");
}

/* スタックから任意のレジスターへ値をポップする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
static void pop_stack_direct(const char* register_name)
{
        pA("stack_head--;");
        pA("PALMEM0(%s, T_SINT32, stack_ptr, stack_head);", register_name);
}

/* スタックの初期化
 */
static char init_stack[] = {
        "VPtr stack_ptr:P03;\n"
        "junkApi_malloc(stack_ptr, T_SINT32, 0x100000);\n"
        "SInt32 stack_socket:R02;\n"
        "SInt32 stack_head:R03;\n"
        "stack_head = 0;\n"
};

/* 現在の使用可能なラベルインデックスのヘッド
 * この値から LABEL_INDEX_LEN 未満までの間が、まだ未使用なユニークラベルのサフィックス番号。
 * ユニークラベルをどこかに設定する度に、この値をインクリメントすること。
 */
static int32_t cur_label_index_head = 0;

/* ラベルの仕様可能最大数 */
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
#define CUR_RETURN_LABEL "P02"

/* ラベルスタックにラベル型（VPtr型）をプッシュする
 * 事前に以下のレジスタをセットしておくこと:
 * labelstack_socket : プッシュしたい値。（VPtr型）
 */
static char push_labelstack[] = {
        "PAPSMEM0(labelstack_socket, T_VPTR, labelstack_ptr, labelstack_head);\n"
        "labelstack_head++;\n"
};

/* ラベルスタックからラベル型（VPtr型）をポップする
 * ポップした値は labelstack_socket に格納される。
 */
static char pop_labelstack[] = {
        "labelstack_head--;\n"
        "PAPLMEM0(labelstack_socket, T_VPTR, labelstack_ptr, labelstack_head);\n"
};

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
        "VPtr labelstack_ptr:P01;\n"
        "junkApi_malloc(labelstack_ptr, T_VPTR, " LABEL_INDEX_LEN_STR ");\n"
        "VPtr labelstack_socket:" CUR_RETURN_LABEL ";\n"
        "SInt32 labelstack_head:R01;\n"
        "labelstack_head = 0;\n"
};

/* 任意のレジスターの値(SInt32型)を、アタッチスタックにプッシュする
 * 事前に attachstack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 * また、代入プロセスが省略できるので高速化する
 */
static void push_attachstack_direct(const char* register_name)
{
        pA("PASMEM0(%s, T_SINT32, attachstack_ptr, attachstack_head);", register_name);
        pA("attachstack_head++;");
}

/* アタッチスタックからアドレス(SInt32型)を、任意のレジスターへプッシュする
 * 事前に attachstack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 * また、代入プロセスが省略できるので高速化する
 */
static void pop_attachstack_direct(const char* register_name)
{
        pA("attachstack_head--;");
        pA("PALMEM0(%s, T_SINT32, attachstack_ptr, attachstack_head);", register_name);
}

/* アタッチスタックの初期化
 * アタッチスタックは、アタッチに用いるためのアドレスをスタックで管理するためのもの。
 */
static char init_attachstack[] = {
        "VPtr attachstack_ptr:P05;\n"
        "junkApi_malloc(attachstack_ptr, T_SINT32, 0x100000);\n"
        "SInt32 attachstack_socket:R20;\n"
        "SInt32 attachstack_head:R21;\n"
        "attachstack_head = 0;\n"
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
        pA("PLIMM(%s, %d);\n", CUR_RETURN_LABEL, cur_label_index_head);
        pA(push_labelstack);
        pA("PLIMM(P3F, %d);\n", label);

        pA("LB(1, %d);\n", cur_label_index_head);
        cur_label_index_head++;
}

/* pop_labelstack を伴ったリターンの定型命令を出力する
 * すなわち、関数リターンのラッパ。
 */
static void retF(void)
{
        pA(pop_labelstack);
        pA("PCP(P3F, %s);\n", CUR_RETURN_LABEL);
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
        pA("PLIMM(P3F, %d);\n", end_label);                             \
                                                                        \
        pA("LB(1, %d);\n", unique_func_label);

#define endF()                                                          \
        retF();                                                         \
        pA("LB(1, %d);\n", end_label);                                  \
        func_label_init_flag = 1;

/* ヒープメモリー上の、任意アドレスからの任意オフセット位置へ、任意のレジスタの内容を書き込む。
 * 概ね write_heap_inline() と同様だが、
 * セットする値を heap_socket ではなく直接レジスターで指定できる点が異なる。
 *
 * また、他の多くの _direct() も同様だが、
 * サフィックス _direct() の関数は、その内部処理を beginF(), endF() で囲んでいない。（囲めないので）
 *
 * この関数自体を beginF(), endF() で囲む分には問題無い。
 */
static void write_heap_inline_direct(const char* register_name)
{
        pA("heap_offset >>= 16;");
        pA("heap_offset &= 0x0000ffff;");
        pA("heap_base += heap_offset;");
        pA("PASMEM0(%s, T_SINT32, heap_ptr, heap_base);", register_name);
}

/* ヒープメモリー上の、任意アドレスからの任意オフセット位置へfix32型を書き込む。
 * 事前に以下のレジスタに値をセットしておくこと:
 * heap_base   : 書き込みのベースアドレス。Int32型単位なので注意。（fix32型では”無い”）
 * heap_socket : ヒープに書き込みたい値。fix32型単位なので注意。
 * heap_offset : identifier に割り当てられた領域中でのインデックス。fix32型単位なので注意。
 *
 * 以前は identifier から struct Var* を得て base_ptr を heap_base へセットする所までこの関数が行っていたが、
 * 今はそれらの処理は別途、自分で書く必要がある。
 * （これらの処理はコンパイル時定数となるので beginF(), endF() で囲めない原因となっていた）
 *
 * コンパイル時の定数設定は不要となったので beginF(), endF() で囲めるようになった。
 */
static void write_heap_inline(void)
{
        write_heap_inline_direct("heap_socket");
}

/* ヒープメモリー上の、任意アドレスからの任意オフセット位置から、任意のレジスタへ内容を読み込む。
 * 概ね read_heap_inline() と同様だが、
 * セットする値を heap_socket ではなく直接レジスターで指定できる点が異なる。
 *
 * また、他の多くの _direct() も同様だが、
 * サフィックス _direct() の関数は、その内部処理を beginF(), endF() で囲んでいない。（囲めないので）
 *
 * この関数自体を beginF(), endF() で囲む分には問題無い。
 */
static void read_heap_inline_direct(const char* register_name)
{
        pA("heap_offset >>= 16;");
        pA("heap_offset &= 0x0000ffff;");
        pA("heap_base += heap_offset;");
        pA("PALMEM0(%s, T_SINT32, heap_ptr, heap_base);", register_name);
}

/* ヒープメモリー上の、identifier に割り当てられた領域内の任意オフセット位置からfix32型を読み込む。
 * 事前に以下のレジスタに値をセットしておくこと:
 * heap_base   : 読み込みのベースアドレス。Int32型単位なので注意。（fix32型では”無い”）
 * heap_offset : identifier に割り当てられた領域中でのインデックス。fix32型単位なので注意。
 *
 * 読み込んだ値は heap_socket へ格納される。これはfix32型なので注意。
 *
 * 以前は identifier から struct Var* を得て base_ptr を heap_base へセットする所までこの関数が行っていたが、
 * 今はそれらの処理は別途、自分で書く必要がある。
 * （これらの処理はコンパイル時定数となるので beginF(), endF() で囲めない原因となっていた）
 *
 * コンパイル時の定数設定は不要となったので beginF(), endF() で囲めるようになった。
 */
static void read_heap_inline(void)
{
        read_heap_inline_direct("heap_socket");
}

/* ヒープメモリーの初期化
 */
static char init_heap[] = {
        "VPtr heap_ptr:P04;\n"
        "junkApi_malloc(heap_ptr, T_SINT32, 0x100000);\n"
        "SInt32 heap_socket:R04;\n"
        "SInt32 heap_base:R06;\n"
        "SInt32 heap_offset:R05;\n"
        "heap_base = 0;\n"
};

/* <expression> <OPE_?> <expression> の状態から、左右の <expression> の値をそれぞれ fixL, fixR へ読み込む
 */
static void read_eoe_arg(void)
{
        pop_stack_direct("fixR");
        pop_stack_direct("fixL");
}

/* eoe用レジスタをスタックへプッシュする
 */
static void push_eoe(void)
{
        beginF();

        push_stack_direct("fixL");
        push_stack_direct("fixR");
        push_stack_direct("fixLx");
        push_stack_direct("fixRx");
        push_stack_direct("fixS");
        push_stack_direct("fixT");
        push_stack_direct("fixT1");
        push_stack_direct("fixT2");
        push_stack_direct("fixT3");
        push_stack_direct("fixT4");

        endF();
}

/* eoe用レジスタをスタックからポップする
 */
static void pop_eoe(void)
{
        beginF();

        pop_stack_direct("fixT4");
        pop_stack_direct("fixT3");
        pop_stack_direct("fixT2");
        pop_stack_direct("fixT1");
        pop_stack_direct("fixT");
        pop_stack_direct("fixS");
        pop_stack_direct("fixRx");
        pop_stack_direct("fixLx");
        pop_stack_direct("fixR");
        pop_stack_direct("fixL");

        endF();
};

static char debug_eoe[] = {
        "junkApi_putConstString('\\nfixL:');"
        "junkApi_putStringDec('\\1', fixL, 10, 1);"
        "junkApi_putConstString(' fixR:');"
        "junkApi_putStringDec('\\1', fixR, 10, 1);"
        "junkApi_putConstString(' fixLx:');"
        "junkApi_putStringDec('\\1', fixLx, 10, 1);"
        "junkApi_putConstString(' fixRx:');"
        "junkApi_putStringDec('\\1', fixRx, 10, 1);"
        "junkApi_putConstString(' fixT:');"
        "junkApi_putStringDec('\\1', fixT, 10, 1);"
        "junkApi_putConstString(' fixT1:');"
        "junkApi_putStringDec('\\1', fixT1, 10, 1);"
        "junkApi_putConstString(' fixT2:');"
        "junkApi_putStringDec('\\1', fixT2, 10, 1);"
        "junkApi_putConstString(' fixT3:');"
        "junkApi_putStringDec('\\1', fixT3, 10, 1);"
        "junkApi_putConstString(' fixT4:');"
        "junkApi_putStringDec('\\1', fixT4, 10, 1);"
        "junkApi_putConstString(' fixS:');"
        "junkApi_putStringDec('\\1', fixS, 10, 1);"
        "junkApi_putConstString(' fixA:');"
        "junkApi_putStringDec('\\1', fixA, 10, 1);"
        "junkApi_putConstString(' fixA1:');"
        "junkApi_putStringDec('\\1', fixA1, 10, 1);"
        "junkApi_putConstString(' fixA2:');"
        "junkApi_putStringDec('\\1', fixA2, 10, 1);"
        "junkApi_putConstString(' fixA3:');"
        "junkApi_putStringDec('\\1', fixA3, 10, 1);"
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
        "SInt32 fixA:R07;"
        "SInt32 fixL:R08;"
        "SInt32 fixR:R09;"
        "SInt32 fixLx:R0A;"
        "SInt32 fixRx:R0B;"
        "SInt32 fixS:R0C;"
        "SInt32 fixT:R0D;"
        "SInt32 fixT1:R0E;"
        "SInt32 fixT2:R0F;"
        "SInt32 fixT3:R10;"
        "SInt32 fixT4:R25;"
        "SInt32 fixA1:R22;"
        "SInt32 fixA2:R23;"
        "SInt32 fixA3:R24;"
};

/* ope_matrix 用変数の初期化
 *
 * 3 * 3 行列以下の小さな行列演算の高速化を書きやすいように、一部の変数はunionの関係となっている。
 */
static char init_matrix[] = {
        /* 主にループ処理の必要な大きな行列処理時に用いる想定
         */
        "SInt32 matfixL: R14;"
        "SInt32 matfixR: R15;"
        "SInt32 matfixA: R16;"
        "SInt32 matfixtmp: R17;"
        "SInt32 matcountcol: R18;"
        "SInt32 matcountrow: R19;"
        "SInt32 matcol: R1A;"
        "SInt32 matrow: R1B;"

        /* 主に3*3以下の小さな行列処理時に用いる想定
         * （ループ目的の場合の名前とは、一部のレジスターがunion関係となっている）
         */
        "SInt32 matfixE0: R14;"
        "SInt32 matfixE1: R15;"
        "SInt32 matfixE2: R16;"
        "SInt32 matfixE3: R17;"
        "SInt32 matfixE4: R18;"
        "SInt32 matfixE5: R19;"
        "SInt32 matfixE6: R1A;"
        "SInt32 matfixE7: R1B;"
        "SInt32 matfixE8: R1C;"

        /* 3項それぞれのベースアドレス保存用。（アタッチへの対応用）
         */
        "SInt32 matbpL: R26;"
        "SInt32 matbpR: R27;"
        "SInt32 matbpA: R28;"
};

/* 全ての初期化
 */
void init_all(void)
{
        pA("#include \"osecpu_ask.h\"\n");

        pA("LOCALLABELS(%d);\n", LABEL_INDEX_LEN);

        /* forループ処理の作業用 */
        pA("SInt32 forfixL: R11;");
        pA("SInt32 forfixR: R12;");
        pA("SInt32 forfixtmp: R13;\n");

        /* matの作業用 */

        pA(init_heap);
        pA(init_stack);
        pA(init_labelstack);
        pA(init_attachstack);
        pA(init_eoe_arg);
        pA(init_matrix);
}

/* 以下、各種アキュムレーター */

/* 加算命令を出力する
 * fixL + fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_add(void)
{
        pA("fixA = fixL + fixR;");
}

/* 減算命令を出力する
 * fixL - fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_sub(void)
{
        pA("fixA = fixL - fixR;");
}

/* 乗算命令を出力する
 * fixL * fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mul_inline(void)
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

static void __func_mul(void)
{
        beginF();

       __func_mul_inline();

        endF();
}

/* 除算命令を出力する
 * fixL / fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_div(void)
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
        __func_mul_inline();

        endF();
}

/* 符号付き剰余命令を出力する
 * fixL mod fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mod(void)
{
        beginF();

        /* 符号付き剰余 */

        /* fixL, fixR それぞれの絶対値 */
        pA("if (fixL >= 0) {fixLx = fixL;} else {fixLx = -fixL;}");
        pA("if (fixR >= 0) {fixRx = fixR;} else {fixRx = -fixR;}");

        pA("fixS = 0;");

        /* fixL, fixR の符号が異なる場合の検出 */
        pA("if (fixL > 0) {if (fixR < 0) {fixS = 1;}}");
        pA("if (fixL < 0) {if (fixR > 0) {fixS = 2;}}");

        /* 符号が異なり、かつ、絶対値比較で fixL の方が小さい場合 */
        pA("if (fixLx < fixRx) {");
                pA("if (fixS == 1) {fixS = 3; fixA = fixL + fixR;}");
                pA("if (fixS == 2) {fixS = 3; fixA = fixL + fixR;}");
        pA("}");

        /* それ以外の場合 */
        pA("if (fixS != 3) {");
                /* 絶対に0除算が起きないように、0ならば最小数に置き換えてから除算 */
                pA("if (fixR == 0) {fixR = 1;}");
                pA("fixT = fixL / fixR;");

                /* floor */
                pA("if (fixT < 0) {fixT -= 1;}");
                pA("fixRx = fixT * fixR;");
                pA("fixA = fixL - fixRx;");
        pA("}");

        endF();
}

/* powのバックエンドに用いる sqrt 命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * nr x (xn - (xn ^ p - x) / (p * xn ^ (p - 1))
 *    L  R     R * R    L     2    R     ---
 */

static void __func_sqrt(void)
{
        beginF();

        /* 終了位置ラベル用（コンパイル時） */
        static int32_t __func_sqrt_end_label = -1;

        /* コンパイル時に、この関数の呼び出しの最初ならば、ラベル番号を確保する（コンパイル時） */
        if (__func_sqrt_end_label == -1) {
                __func_sqrt_end_label = cur_label_index_head;
                cur_label_index_head++;
        }

        /* fixL, fixT -> fixT */
        void nr(void)
        {
                push_eoe();
                pA("fixL = fixR;");
                __func_mul();
                pop_eoe();
                pA("fixLx = fixA;");
                pA("fixLx -= fixL;");

                push_eoe();
                pA("fixL = 0x00020000;");
                __func_mul();
                pop_eoe();
                pA("fixRx = fixA;");

                push_eoe();
                pA("fixL = fixLx;");
                pA("fixR = fixRx;");
                __func_div();
                pop_eoe();

                pA("fixT = fixA;");
                pA("fixA = fixR - fixT;");

                pA("if (fixT < 0) {fixT = -fixT;}");
                pA("if (fixT < 0x00000100) {PLIMM(P3F, %d);}", __func_sqrt_end_label);
        }

        push_eoe();
        pA("fixR = 0x00020000;");
        __func_div();
        pop_eoe();

        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();
        pA("fixR = fixA;");     nr();

        pA("LB(1, %d);", __func_sqrt_end_label);

        endF();
}

/* powのバックエンドに用いる ±a ^ +b (ただし b = 整数、かつ a != 0) 限定のpow。（bが正の場合限定のpow）
 * fixL ^ fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_pow_p(void)
{
        beginF();

        void tt(void)
        {
                push_eoe();
                pA("fixL = fixT;");
                pA("fixR = fixT;");
                __func_mul();
                pop_eoe();
                pA("fixT = fixA;");
        }

        void rt(void)
        {
                push_eoe();
                pA("fixL = fixT;");
                __func_sqrt();
                pop_eoe();
                pA("fixT = fixA;");
        }

        void st(void)
        {
                push_eoe();
                pA("fixL = fixS;");
                pA("fixR = fixT;");
                __func_mul();
                pop_eoe();
                pA("fixS = fixA;");
        }

        pA("fixS = 0x00010000;");

        pA("fixT = fixL;");
        pA("if ((fixR & 0x00010000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00020000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00040000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00080000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00100000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00200000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00400000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x00800000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x01000000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x02000000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x04000000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x08000000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x10000000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x20000000) != 0) {"); st(); pA("}"); tt();
        pA("if ((fixR & 0x40000000) != 0) {"); st(); pA("}");

        pA("fixT = fixL;"); rt();
        pA("if ((fixR & 0x00008000) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00004000) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00002000) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00001000) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000800) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000400) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000200) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000100) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000080) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000040) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000020) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000010) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000008) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000004) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000002) != 0) {"); st(); pA("}"); rt();
        pA("if ((fixR & 0x00000001) != 0) {"); st(); pA("}");

        pA("fixA = fixS;");

        endF();
}

/* powのバックエンドに用いる ±a ^ -b (ただし b = 整数、かつ a != 0) 限定のpow。（bが負の場合限定のpow）
 * fixL ^ fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_pow_m(void)
{
        beginF();

        pA("fixR = -fixR;");
        __func_pow_p();

        pA("fixL = 0x00010000;");
        pA("fixR = fixA;");
        __func_div();

        endF();
}

/* 冪乗命令を出力する
 * fixL ^ fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_pow(void)
{
        beginF();

        /* 左辺が0以外で正の場合 */
        pA("if (fixL > 0) {");
                /* 右辺が0 または 正の整数の場合 */
                pA("if (fixR >= 0) {");
                        push_eoe();
                        __func_pow_p();
                        pop_eoe();
                pA("}");

                /* 右辺が負の整数の場合 */
                pA("if (fixR < 0) {");
                        push_eoe();
                        __func_pow_m();
                        pop_eoe();
                pA("}");
        pA("}");

        /* 左辺が0以外で負の場合 */
        pA("if (fixL < 0) {");
                /* 右辺が非整数の場合 */
                pA("if ((fixR & 0x0000ffff) != 0) {");
                        pA("junkApi_putConstString('system err: -a ^ 0.1 is not support.');");
                        pA("jnukApi_exit(1);");
                pA("}");

                /* 右辺が0 または 正の整数の場合 */
                pA("if (fixR >= 0) {");
                        push_eoe();
                        __func_pow_p();
                        pop_eoe();
                pA("}");

                /* 右辺が負の整数の場合 */
                pA("if (fixR < 0) {");
                        push_eoe();
                        __func_pow_m();
                        pop_eoe();
                pA("}");
        pA("}");

        /* 左辺が0の場合 */
        pA("if (fixL == 0) {");
                /* 右辺が0または負の場合は、計算未定義と表示して終了 */
                pA("if(fixR <= 0) {");
                        pA("junkApi_putConstString('system err: 0 ^ 0 or 0 ^ -x is not support.');");
                        pA("jnukApi_exit(1);");

                /* 右辺が正の場合は、常に0を返す */
                pA("} else {");
                        pA("fixA = 0;");
                pA("}");
        pA("}");

        endF();
}

/* and命令を出力する
 * fixL & fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_and(void)
{
        pA("fixA = fixL & fixR;");
}

/* or命令を出力する
 * fixL | fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_or(void)
{
        pA("fixA = fixL | fixR;");
}

/* xor命令を出力する
 * fixL ^ fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_xor(void)
{
        pA("fixA = fixL ^ fixR;");
}

/* not命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_not(void)
{
        pA("fixA = fixL ^ (-1);");
}

/* 左シフト命令を出力する
 * fixL << fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_lshift(void)
{
        pA("fixR >>= 16;");
        pA("fixA = fixL << fixR;");
}

/* 右シフト命令を出力する（算術シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 論理シフトとして動作する。
 */
static void __func_rshift(void)
{
        beginF();

        pA("fixR >>= 16;");

        pA("if (fixR >= 1) {");
                pA("if ((fixL & 0x80000000) != 0) {");
                        pA("fixL &= 0x7fffffff;");
                        pA("fixL >>= 1;");
                        pA("fixL |= 0x40000000;");

                        pA("fixR--;");
                pA("}");
        pA("}");

        pA("fixA = fixL >> fixR;");

        endF();
}

/* 符号反転命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_minus(void)
{
        pA("fixA = -fixL;");
}

/* 以下、各種代入関数 */

/* 名前がidenのスカラー変数へ、値を代入する。
 *
 * iden へは代入先の配列変数名を渡す
 *
 * 値はあらかじめスタックにプッシュされてる前提。
 * また、アタッチも同様にあらかじめアタッチスタックにプッシュされてる前提。
 */
static void __assignment_scaler(const char* iden)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("syntax err: 未定義のスカラー変数へ代入しようとしました");

        /* 変数が配列な場合はエラー（コンパイル時） */
        if (var->row_len != 1 || var->col_len != 1)
                yyerror("syntax err: 配列変数へスカラーによる書き込みを行おうとしました");

        /* ヒープ書き込み位置のデフォルト値をセットする命令を出力する（コンパイル時） */
        pA("heap_base = %d;", var->base_ptr);

        /* 書き込む値を読んでおく */
        pop_stack_direct("stack_socket");

        /* スカラーなので書き込みオフセットは0 */
        pA("heap_offset = 0;");

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする
         * （アタッチではない場合は、すでにセットされているデフォルトのheap_baseの値のまま）
         */
        pop_attachstack_direct("attachstack_socket");
        pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;}");

        write_heap_inline_direct("stack_socket");
}

/* 名前がidenの配列変数中の、任意インデックス番目の要素へ、値を代入する。
 *
 * iden へは代入先の配列変数名を渡す
 * dimlen へは iden への添字の次元を渡す（構文エラーの判別に用います）
 *
 * 値はあらかじめスタックにプッシュされてる前提。
 * 連続でポップした場合の順番は、
 *     スカラーならば 書き込み値
 *     １次元配列ならば 書き込み値、 添字
 *     2次元配列ならば 書き込み値、 列添字、 行添字
 * という順番でスタックに詰まれている前提。
 *
 * また、アタッチも同様にあらかじめアタッチスタックにプッシュされてる前提。
 */
static void __assignment_array(const char* iden, const int32_t dimlen)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("syntax err: 未定義の配列変数へ代入しようとしました");

        /* 変数がスカラーな場合は警告（コンパイル時） */
        if (var->row_len == 1 && var->col_len == 1) {
                yywarning("syntax warning: スカラー変数へ添字による書き込みを行おうとしました。"
                          "これは不正ではありませんが、意図的な記述で無いならばミスの可能性が高いです");
        }

        /* 変数の次元に対して、指定された添字の次元が異なる場合を調べてエラー表示する（コンパイル時）
         */

        /* 変数が1次元配列なのに、添字の次元がそれとは異なる場合は警告（コンパイル時） */
        if (var->row_len == 1 && dimlen != 1) {
                yywarning("syntax warning: 1次元配列として宣言された変数に対して、異なる次元の添字を指定しました。"
                          "これは不正ではありませんが、意図的な記述で無いならばミスの可能性が高いです");
        }

        /* 変数が2次元配列なのに、添字の次元がそれとは異なる場合は警告（コンパイル時） */
        if (var->row_len >= 2 && dimlen != 2)
                yywarning("syntax warning: 2次元配列として宣言された変数に対して、異なる次元の添字を指定しました。"
                          "これは不正ではありませんが、意図的な記述で無いならばミスの可能性が高いです");

        /* 配列の添字が0次元の場合はエラー（コンパイル時） */
        if (dimlen == 0)
                yyerror("syntax err: 配列の添字がありません");

        /* 配列の添字が3次元以上の場合はエラー（コンパイル時） */
        if (dimlen >= 3)
                yyerror("syntax err: 配列の添字の個数が多すぎます。この言語では２次元配列までしか使えません");

        /* ヒープ書き込み位置のデフォルト値をセットする命令を出力する（コンパイル時） */
        pA("heap_base = %d;", var->base_ptr);

        /* 書き込む値をスタックから読み込む命令を出力（コンパイル時） */
        pop_stack_direct("heap_socket");

        /* ヒープ書き込みオフセット位置をセットする命令を出力する（コンパイル時）
         * これは配列の次元によって分岐する
         */
        /* １次元配列の場合 */
        if (var->row_len == 1) {
                pop_stack_direct("heap_offset");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* これは[行, 列]の列 */
                pop_stack_direct("heap_offset");

                /* これは[行, 列]の行 */
                pop_stack_direct("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: assignment, var->row_len の値が不正です");
        }

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする
         * （アタッチではない場合は、すでにセットされているデフォルトのheap_baseの値のまま）
         */
        pop_attachstack_direct("attachstack_socket");
        pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;}");

        write_heap_inline_direct("heap_socket");
}

/* 以下、各種リード関数 */

static void __read_variable_ptr_scaler(const char* iden)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("syntax err: 未定義のスカラー変数のアドレスを得ようとしました");

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
         */
        pop_attachstack_direct("attachstack_socket");
        pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
           "else {heap_base = %d;}", var->base_ptr);

        /* heap_base自体を（アドレス自体を）スタックにプッシュする */
        push_stack_direct("heap_base");
}

static void __read_variable_ptr_array(const char* iden, const int32_t dim)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("syntax err: 未定義の配列変数のアドレスを得ようとしました");

        /* 変数がスカラーな場合はエラー */
        if (var->row_len == 1 && var->col_len == 1)
                yyerror("syntax err: スカラー変数へ添字による指定をしました");

        /* 配列の次元に対して、添字の次元が異なる場合にエラーとする
        */
        /* 変数が1次元配列なのに、添字の次元がそれとは異なる場合 */
        if (var->row_len == 1 && dim != 1)
                yyerror("syntax err: 1次元配列に対して、異なる次元の添字を指定しました");

        /* 変数が2次元配列なのに、添字の次元がそれとは異なる場合 */
        else if (var->row_len >= 2 && dim != 2)
                yyerror("syntax err: 2次元配列に対して、異なる次元の添字を指定しました");

        /* 配列の次元によって分岐（コンパイル時）
         */
        /* １次元配列の場合 */
        if (var->row_len == 1) {
                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 */
                pop_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", var->base_ptr);

                /* heap_base へオフセットを足す
                 */
                pop_stack_direct("heap_offset");
                pA("heap_offset >>= 16;");
                pA("heap_base += heap_offset;");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 */
                pop_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", var->base_ptr);

                /* heap_base へオフセットを足す
                 */
                /* これは[行, 列]の列 */
                pop_stack_direct("heap_offset");

                /* これは[行, 列]の行。
                 * これと変数の列サイズと乗算した値を更に足すことで、変数の先頭からのオフセット位置
                 */
                pop_stack_direct("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

                pA("heap_offset >>= 16;");
                pA("heap_base += heap_offset;");

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: __OPE_ADDRESS read_variable, col_len の値が不正です");
        }

        /* heap_base自体を（アドレス自体を）スタックにプッシュする */
        push_stack_direct("heap_base");
}

static void __read_variable_scaler(const char* iden)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("syntax err: 未定義のスカラー変数から読もうとしました");

        /* 変数が配列な場合はエラー */
        if (var->row_len != 1 || var->col_len != 1)
                yyerror("syntax err: 配列変数へスカラーによる読み込みを行おうとしました");

        /* スカラーなので読み込みオフセットは 0 */
        pA("heap_offset = 0;");

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時） */
        pop_attachstack_direct("attachstack_socket");
        pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
           "else {heap_base = %d;}", var->base_ptr);

        read_heap_inline_direct("stack_socket");

        /* 結果をスタックにプッシュする */
        push_stack_direct("stack_socket");
}

static void __read_variable_array(const char* iden, const int32_t dim)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("syntax err: 未定義の配列変数から読もうとしました");

        /* 変数がスカラーな場合はエラー */
        if (var->row_len == 1 && var->col_len == 1)
                yyerror("syntax err: スカラー変数へ添字による読み込みを行おうとしました");

        /* 配列の次元に対して、添字の次元が異なる場合にエラーとする
        */
        /* 変数が1次元配列なのに、添字の次元がそれとは異なる場合 */
        if (var->row_len == 1 && dim != 1)
                yyerror("syntax err: 1次元配列に対して、異なる次元の添字を指定しました");

        /* 変数が2次元配列なのに、添字の次元がそれとは異なる場合 */
        else if (var->row_len >= 2 && dim != 2)
                yyerror("syntax err: 2次元配列に対して、異なる次元の添字を指定しました");

        /* 配列の次元によって分岐（コンパイル時）
         */
        /* １次元配列の場合 */
        if (var->row_len == 1) {
                pop_stack_direct("heap_offset");

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時） */
                pop_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", var->base_ptr);

                read_heap_inline_direct("stack_socket");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* これは[行, 列]の列 */
                pop_stack_direct("heap_offset");

                /* これは[行, 列]の行。
                 * これと変数の列サイズと乗算した値を更に足すことで、変数の先頭からのオフセット位置
                 */
                pop_stack_direct("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時） */
                pop_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", var->base_ptr);

                read_heap_inline_direct("stack_socket");

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: read_variable, col_len の値が不正です");
        }

        /* 結果をスタックにプッシュする */
        push_stack_direct("stack_socket");
}

/* 以下、ユーザー定義関数関連 */

/* 関数呼び出し
 */
static void __call_user_function(const char* iden)
{
        /* ラベルリストに名前が存在しなければエラー */
        if (labellist_search_unsafe(iden) == -1)
                yyerror("syntac err: 未定義の関数を実行しようとしました");

        /* gosub とほぼ同じ */
        pA("PLIMM(%s, %d);\n", CUR_RETURN_LABEL, cur_label_index_head);
        pA(push_labelstack);
        pA("PLIMM(P3F, %d);\n", labellist_search(iden));
        pA("LB(1, %d);\n", cur_label_index_head);
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
        pA("LB(1, %d);\n", labellist_search(iden));

        varlist_scope_push();

        int32_t i;
        for (i = 0; i < arglen; i++) {
                char iden[0x1000];
                idenlist_pop(iden);

                varlist_add_local(iden, 1, 1);

                /* 変数のスペックを得る。（コンパイル時） */
                struct Var* var = varlist_search_local(iden);
                if (var == NULL)
                        yyerror("system err: functionによる関数定義において、ローカル変数の作成に失敗しました");

                pA("heap_offset = 0;");

                /* 現状ではアタッチは未サポートで、変数自身のbase_ptrをheap_baseにセットする。（コンパイル時） */
                pA("heap_base = %d;", var->base_ptr);

                pop_stack_direct("stack_socket");
                write_heap_inline_direct("stack_socket");
        }

        /* 戻り値の代入用に、関数名と同名のローカル変数（スカラー）を作成する */
        varlist_add_local(iden, 1, 1);
}

/* 関数定義の後半部
 * declaration_list __BLOCK_RB
 */
static void __define_user_function_end(const char* iden,
                                       const int32_t skip_label)
{
        /* 関数名と同名のローカル変数の値を、スタックにプッシュして、これを戻り値とする
         */
        /* 勘数名変数（戻り値代入先）のスペックを得る。（コンパイル時） */
        struct Var* var = varlist_search(iden);
        if (var == NULL)
                yyerror("system err: functionによる関数定義において、関数名と同名のローカル変数の作成に失敗しました");

        pA("heap_offset = 0;");

        /* 現状ではアタッチは未サポートで、変数自身のbase_ptrをheap_baseにセットする。（コンパイル時） */
        pA("heap_base = %d;", var->base_ptr);

        read_heap_inline_direct("stack_socket");

        push_stack_direct("stack_socket");

        /* ローカル変数を破棄する */
        varlist_scope_pop();

        /* 関数呼び出し元の位置まで戻る */
        pA(pop_labelstack);
        pA("PCP(P3F, %s);\n", CUR_RETURN_LABEL);

        /* 通常フロー中では、この関数定義を読み飛ばし、ここへとジャンプしてくる前提
         * また、この skip_label の値は、
         * この関数とペアで呼ばれる関数 __define_user_function_begin() へのそれと同じ値である前提。
         */
        pA("LB(1, %d);", skip_label);
}

/* 以下、各種プリセット関数 */

/* 文字列出力命令を出力する
 * fixL -> null
 * 予め fixL に値をセットしておくこと。 演算結果は存在しない。
 */
static void __func_print(void)
{
        beginF();

        /* 符号を保存しておき、正に変換 */
        pA("if (fixL < 0) {fixS = 1; fixL = -fixL;} else {fixS = 0;}");

        /* 負の場合は-符号を表示する */
        pA("if (fixS == 1) {junkApi_putConstString('-');}");

        /* 整数側の表示 */
        pA("fixLx = fixL >> 16;");
        pA("junkApi_putStringDec('\\1', fixLx, 6, 1);");

        /* 小数点を表示 */
        pA("junkApi_putConstString('.');");

        /* 小数側の表示 */
        pA("fixR = 0;");
        pA("if ((fixL & 0x00008000) != 0) {fixR += 5000;}");
        pA("if ((fixL & 0x00004000) != 0) {fixR += 2500;}");
        pA("if ((fixL & 0x00002000) != 0) {fixR += 1250;}");
        pA("if ((fixL & 0x00001000) != 0) {fixR += 625;}");
        pA("if ((fixL & 0x00000800) != 0) {fixR += 312;}");
        pA("if ((fixL & 0x00000400) != 0) {fixR += 156;}");
        pA("if ((fixL & 0x00000200) != 0) {fixR += 78;}");
        pA("if ((fixL & 0x00000100) != 0) {fixR += 39;}");
        pA("if ((fixL & 0x00000080) != 0) {fixR += 19;}");
        pA("if ((fixL & 0x00000040) != 0) {fixR += 10;}");
        pA("if ((fixL & 0x00000020) != 0) {fixR += 5;}");
        pA("if ((fixL & 0x00000010) != 0) {fixR += 2;}");
        pA("if ((fixL & 0x00000008) != 0) {fixR += 1;}");
        pA("if ((fixL & 0x00000004) != 0) {fixR += 1;}");

        pA("junkApi_putStringDec('\\1', fixR, 4, 6);\n");

        /* 自動改行はさせない （最後にスペースを表示するのみ） */
        pA("junkApi_putConstString(' ');");

        endF();
}

/* ヒープメモリー上の任意アドレスから１ワード読み込む
 * fixL -> fixA
 * 予め fixL に読み込み先アドレスをセットしておくこと。 演算結果は fixA へ出力される。
 *
 * アドレスはFix32ではなくSInt32型の数として指定します。（Fix32型を >> 16 した値で指定します）
 *
 * アドレス指定も、読み込み単位も、バイト単位ではなくワード単位です。(１ワードはSInt32)
 */
static void __func_peek(void)
{
        pA("PALMEM0(fixA, T_SINT32, fixL, heap_head);");
}

/* ヒープメモリー上の任意アドレスへ１ワード書き込む
 * fixL, fixR -> null
 * 予め fixL に書き込み先アドレス、 fixR に書き込む値（１ワード）をセットしておくこと。 演算結果は存在しない。
 *
 * アドレスはFix32ではなくSInt32型の数として指定します。（Fix32型を >> 16 した値で指定します）
 *
 * アドレス指定も、書き込み単位も、バイト単位ではなくワード単位です。(１ワードはSInt32)
 */
static void __func_poke(void)
{
        pA("PASMEM0(fixR, T_SINT32, fixL, heap_head);");
}

/* sin命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_sin(void)
{
        beginF();

        /* fixL -> fixA */
        void u(const int32_t p, const int32_t b)
        {
                push_eoe();
                pA("fixR = %d;", p);
                __func_pow();
                pA("fixL = fixA;");

                pA("fixR = %d;", b);
                __func_mul();
                pop_eoe();
        }

        /* 値を(±π/2)の範囲へ正規化する命令を出力する
         * fixL -> fixL
         *
         * osecpu-basicでは、整数の有効桁が15bitしか無いので、6^7すら計算できない（6^7=279936 > 32768）
         * その為、2π等をそのまま計算すると、展開式に当てはめた際に計算不能となってしまう。
         * また、整数部が大きければ演算後の小数部の誤差も大きくなる傾向があるので、これらの理由から
         * 整数部は極力小さくした方が計算精度を稼げる。（また、それをしなければ、10^-3程度の精度すら出せない）
         *
         * そこで、まず値を±(π/2)の範囲内へ丸める必要がある
         */
        const int32_t pi = 205887;
        const int32_t pi_h = 102943;
        const int32_t pi_2 = 411774;

        push_eoe();
        pA("fixR = %d;", pi_2);
        __func_mod();
        pop_eoe();
        pA("fixS = fixA;");

        pA("if (fixS >= 0) {if (fixS <= %d) {fixL = fixS;}}", pi_h);
        pA("if (fixS >= %d) {if (fixS <= %d) {fixL = %d - fixS;}}", pi_h, pi, pi);
        pA("if (fixS >= %d) {if (fixS <= %d) {fixL = fixS - %d; fixL = -%d - fixL;}}", pi, pi + pi_h, pi_2, pi);
        pA("if (fixS >= %d) {if (fixS <= %d) {fixL = fixS - %d;}}", pi + pi_h, pi_2, pi_2);

        /* sin(0)のテーラー展開式を用いてsinを求める
         */
        pA("fixT = fixL;");
        u(196608, 10923);
        pA("fixT -= fixA;");
        u(327680, 546);
        pA("fixT += fixA;");
        u(458752, 13);
        pA("fixT -= fixA;");

        pA("fixA = fixT;");

        endF();
}

/* cos命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_cos(void)
{
        beginF();

        const int32_t pi_h = 102943;
        const int32_t pi_2 = 411774;

        /* ±(π/2)の範囲内へ丸める */
        push_eoe();
        pA("fixR = %d;", pi_2);
        __func_mod();
        pop_eoe();

        /* +pi/2 して sin で代用する */
        pA("fixL = fixA + %d;", pi_h);
        __func_sin();

        endF();
}

/* tan命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_tan(void)
{
        beginF();

        /* fixL -> fixA */
        void u(const int32_t p, const int32_t a, const int32_t b)
        {
                push_eoe();
                pA("fixR = %d;", p << 16);
                __func_pow();
                pA("fixL = fixA;");

                pA("fixR = %d;", a << 16);
                __func_mul();
                pA("fixL = fixA;");

                pA("fixR = %d;", b << 16);
                __func_div();
                pop_eoe();
        }

        pA("fixT = fixL;");
        u(3, 1, 3);
        pA("fixT += fixA;");
        u(5, 2, 15);
        pA("fixT += fixA;");
        u(7, 17, 315);
        pA("fixT += fixA;");
        u(9, 62, 2835);
        pA("fixT += fixA;");

        pA("fixA = fixT;");

        endF();
}

/* 描画領域を初期設定をして開く
 * fixL, fixR -> null
 * あらかじめ fix? に配列の値をセットしておくこと。 演算結果は存在しない。
 *
 * fixL: 描画領域のwidth
 * fixR: 描画り領域のheight
 */
static void __func_openwin(void)
{
        pA("fixR >>= 16;");
        pA("fixL >>= 16;");
        pA("junkApi_openWin(fixL, fixR);");
}

/* 指定ミリ秒間だけスリープする
 * fixL, fixR -> null
 * あらかじめ fix? に配列の値をセットしておくこと。 演算結果は存在しない。
 *
 * fixL: mode
 * fixR: スリープ時間（ミリ秒単位）
 */
static void __func_sleep(void)
{
        pA("fixR >>= 16;");
        pA("fixL >>= 16;");
        pA("junkApi_sleep(fixL, fixR);");
}

/* 三色の数値をRGBへとまとめる
 * fixL, fixR, fixS -> fixA
 * あらかじめ fix? に配列の値をセットしておくこと。 演算結果はfixAへと出力される。
 *
 * fixL: 赤 (0 ～ 255)
 * fixR: 緑 (0 ～ 255)
 * fixS: 青 (0 ～ 255)
 *
 * 赤・緑・青を、32bitのRGB値へと変換する。フォーマットは 0x00RRGGBB
 * 多くの関数で色値が必要な場合は、この値を渡せばいい。
 */
static void __func_torgb(void)
{
        beginF();

        pA("fixL &= 0x00ff0000;");      /* R */
        pA("fixR &= 0x00ff0000;");      /* G */
        pA("fixS &= 0x00ff0000;");      /* B */

        pA("fixA = fixL;");
        pA("fixA |= fixR >> 8;");
        pA("fixA |= fixS >> 16;");

        endF();
}

/* 描画領域に点を描く
 * fixT, fixL, fixR, fixS -> null
 * あらかじめ fix? に配列の値をセットしておくこと。 演算結果は存在しない。
 *
 * fixT: mode
 * fixL: x座標
 * fixR: y座標
 * fixS: RGB （32bitカラー。フォーマットは0x00RRGGBB）
 */
static void __func_drawpoint(void)
{
        beginF();

        pA("fixT >>= 16;");     /* mode */
        pA("fixL >>= 16;");     /* x */
        pA("fixR >>= 16;");     /* y */
        pA("junkApi_drawPoint(fixT, fixL, fixR, fixS);");

        endF();
}

/* 描画領域に線を描く
 * fixT, fixL, fixR, fixLx, fixRx, fixS -> null
 * あらかじめ fix? に配列の値をセットしておくこと。 演算結果は存在しない。
 *
 * fixT: mode
 * fixL: 始点x座標
 * fixR: 始点y座標
 * fixLx: 終点x座標
 * fixRx: 終点y座標
 * fixS: RGB （32bitカラー。フォーマットは0x00RRGGBB）
 */
static void __func_drawline(void)
{
        beginF();

        pA("fixT >>= 16;");     /* mode */
        pA("fixL >>= 16;");     /* x0 */
        pA("fixR >>= 16;");     /* y0 */
        pA("fixLx >>= 16;");    /* x1 */
        pA("fixRx >>= 16;");    /* y1 */
        pA("junkApi_drawLine(fixT, fixL, fixR, fixLx, fixRx, fixS);");

        endF();
}

/* 描画領域の指定領域を塗りつぶす
 * fixT, fixL, fixR, fixLx, fixRx, fixS -> null
 * あらかじめ fix? に配列の値をセットしておくこと。 演算結果は存在しない。
 *
 * fixT: mode
 * fixL: 領域のよこ幅
 * fixR: 領域のたて幅
 * fixLx: 終点x座標
 * fixRx: 終点y座標
 * fixS: RGB （32bitカラー。フォーマットは0x00RRGGBB）
 */
static void __func_fillrect(void)
{
        beginF();

        pA("fixT >>= 16;");     /* mode */
        pA("fixL >>= 16;");     /* x0 */
        pA("fixR >>= 16;");     /* y0 */
        pA("fixLx >>= 16;");    /* x1 */
        pA("fixRx >>= 16;");    /* y1 */
        pA("junkApi_fillRect(fixT, fixL, fixR, fixLx, fixRx, fixS);");

        endF();
}

/* 線分ベクトルの絶対値を得る命令を出力する
 * あらかじめ各 fix? に所定の値をセットしておくこと。 演算結果はfixAへ出力される。
 * fixL:x0, fixR:y0, fixLx:x1, fixRx:y1 -> fixA
 *
 * 非公開関数
 */
static void __func_lineabs(void)
{
        beginF();

        /* (x1 - x0) ^ 2 -> fixT1
         */
        push_eoe();
        pA("fixL = fixLx - fixL;");
        pA("fixR = fixL;");
        __func_mul();
        pop_eoe();
        pA("fixT1 = fixA;");

        /* (y1 - y0) ^ 2 -> fixT2
         */
        push_eoe();
        pA("fixR = fixRx - fixR;");
        pA("fixL = fixR;");
        __func_mul();
        pop_eoe();
        pA("fixT2 = fixA;");

        /* sqrt(fixT1 + fixT2)
         */
        push_eoe();
        pA("fixL = fixT1 + fixT2;");
        __func_sqrt();
        pop_eoe();

        endF();
}

/* 線分ベクトルの単位ベクトルを得る命令を出力する
 * あらかじめ各 fix? に所定の値をセットしておくこと。 演算結果はfixA, fixA1へ出力される。
 * fixL:x0, fixR:y0, fixLx:x1, fixRx:y1 -> fixA:x2, fixA1:y2
 *
 * 非公開関数
 */
static void __func_lineunit(void)
{
        beginF();

        /* fixT = r
         */
        push_eoe();
        __func_lineabs();
        pop_eoe();

        pA("fixT = fixA;");

        /* (y1 - y0) / r
         */
        push_eoe();
        pA("fixL = fixRx - fixR;");
        pA("fixR = fixT;");
        __func_div();
        pop_eoe();

        pA("fixA1 = fixA;");

        /* (x1 - x0) / r
         */
        push_eoe();
        pA("fixL = fixLx - fixL;");
        pA("fixR = fixT;");
        __func_div();
        pop_eoe();

        endF();
}

/* 線分の傾きaを得る（ただしx=ay）
 * あらかじめ各 fix? に所定の値をセットしておくこと。 演算結果は fixA へ出力される。
 * fixL:x0, fixR:y0, fixLx:x1, fixRx:y1 -> fixA
 *
 * 非公開関数
 */
static void __func_linebias_ay(void)
{
        beginF();

        pA("fixL = fixLx - fixL;");
        pA("fixR = fixRx - fixR;");
        __func_div();

        endF();
}

/* 線分をy分割した場合のxを得る
 * あらかじめ各 fix? に所定の値をセットしておくこと。 演算結果は fixA へ出力される。
 * fixL:x0, fixR:y0, fixLx:x1, fixRx:y1, fixS:spritY
 *
 * 非公開関数
 */
static void __func_linesprit_y(void)
{
        beginF();

        pA("fixS -= fixR;");

        push_eoe();
        __func_linebias_ay();
        pop_eoe();

        push_eoe();
        pA("fixL = fixA;");
        pA("fixR = fixS;");
        __func_mul();
        pop_eoe();

        pA("fixA += fixL;");

        endF();
}

/* 直線区間a,bを絶対値dで微分する命令を出力する
 * あらかじめ各 fix? に所定の値をセットしておくこと。演算結果はfixAへ出力される。
 * fixL:a, fixR:b, fixT:d
 *
 * 非公開関数
 */
static void __func_dsection(void)
{
        beginF();

        pA("fixL = fixR - fixL;");
        pA("fixR = fixT;");
        push_eoe();
        __func_div();
        pop_eoe();

        endF();
}

/* 3項から最大値インデックスを探す命令を出力する
 * あらかじめ fixL, fixR, fixS に値をセットしておくこと。演算結果はfixAへ出力される。
 *
 * 結果は [0] = fixL, [1] = fixR, [2] = fixS と考えた場合のインデックス値
 *
 * 非公開関数
 */
static void __func_search_max3(void)
{
        beginF();

        pA("fixA = 0;");
        pA("if ((fixR >= fixS) & (fixR >= fixL)) {fixA = 1;}");
        pA("if ((fixS >= fixL) & (fixS >= fixR)) {fixA = 2;}");

        endF();
}

/* 2項から最小値インデックスを探す命令を出力する
 * あらかじめ fixL, fixR に値をセットしておくこと。演算結果はfixAへ出力される。
 *
 * 結果は [0] = fixL, [1] = fixR と考えた場合のインデックス値
 *
 * 非公開関数
 */
static void __func_search_min2(void)
{
        beginF();

        pA("fixA = 0;");
        pA("if (fixR <= fixL) {fixA = 1;}");

        endF();
}

/* 3項から最大値、中間値、最小値のインデックスを探す命令を出力する
 * あらかじめ fixL, fixR, fixS に値をセットしておくこと。演算結果はfixAへ出力される。
 *
 * 結果は [0] = fixL, [1] = fixR, [2] = fixS と考えた場合のインデックス値を、2bit毎に配列した値
 * 0-1bit = min, 2-3bit = mid, 4-5bit = max
 *
 * 非公開関数
 */
static void __func_search_minmidmax3(void)
{
        beginF();

        __func_search_max3();
        pA("fixT = fixA;");
        pA("fixT1 = fixT << 4;");

        pA("if (fixT == 0) {");
                pA("fixL = fixS;");
                __func_search_min2();
                pA("if (fixA == 0) {fixA = fixT1 | %d | %d;}", (1 << 2), (2 << 0));
                pA("if (fixA == 1) {fixA = fixT1 | %d | %d;}", (2 << 2), (1 << 0));
        pA("}");

        pA("if (fixT == 1) {");
                pA("fixR = fixS;");
                __func_search_min2();
                pA("if (fixA == 0) {fixA = fixT1 | %d | %d;}", (2 << 2), (0 << 0));
                pA("if (fixA == 1) {fixA = fixT1 | %d | %d;}", (0 << 2), (2 << 0));
        pA("}");

        pA("if (fixT == 2) {");
                __func_search_min2();
                pA("if (fixA == 0) {fixA = fixT1 | %d | %d;}", (1 << 2), (0 << 0));
                pA("if (fixA == 1) {fixA = fixT1 | %d | %d;}", (0 << 2), (1 << 0));
        pA("}");

        endF();
}

/* 頂点 a,b,c (ay = by) をスキャンライン単位で三角形塗りつぶしする命令を出力する。
 * あらかじめ以下のルールで値をセットしておくこと。 演算結果は存在しない。
 * fixL = x0, fixR = y0, fixLx = x1, fixRx = y1, fixT1 = x2, fixT2 = y2
 * fixT = mode, fixS = RGB
 *
 * ope_comparison には ">=" か "<=" の文字列を与える想定。
 * for_step には "+" か "-" の文字列を与える想定。
 * これらは +方向、-方向用、それぞれ専用の決め打ち関数を生成するため。
 *
 * 非公開関数
 */
static void __func_filltri_sl_common(const char* ope_comparison, const char* for_step)
{
        /* ope_comparison毎に、コンパイル時に複数生成される想定なので、
         * 関数内を beginF(), endF() で囲んではいけない。
         *
         * この関数自体を囲むことには問題は無い。
         */

        /* line a,c 側の dx を fixT3 へ得る
         */
        push_eoe();
                pA("fixL = fixT1 - fixL;");
                pA("fixR = fixT2 - fixR;");
                __func_div();
        pop_eoe();
        pA("fixT3 = fixA;");

        /* line b,c 側の dx を fixT4 へ得る
         */
        push_eoe();
                pA("fixL = fixT1 - fixLx;");
                pA("fixR = fixT2 - fixRx;");
                __func_div();
        pop_eoe();
        pA("fixT4 = fixA;");

        /* forループ
         */

        /* 局所ループ用に無名ラベルをセット （外側forの戻り位置）
         */
        const int32_t local_label_y = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label_y);

        pA("if (fixR %s fixT2) {", ope_comparison);
                push_eoe();
                        pA("fixL >>= 16;");
                        pA("fixR >>= 16;");
                        pA("fixLx >>= 16;");
                        pA("junkApi_drawLine(fixT, fixL, fixR, fixLx, fixR, fixS);");

                        /* 隙間対策
                         */
                        pA("fixR++;");
                        pA("junkApi_drawLine(fixT, fixL, fixR, fixLx, fixR, fixS);");
                pop_eoe();

                pA("fixR %s= %d;", for_step, (1 << 16));

                pA("fixL %s= fixT3;", for_step);
                pA("fixLx %s= fixT4;", for_step);

                /* ループの復帰
                 */
                pA("PLIMM(P3F, %d);", local_label_y);
        pA("}");
}

/* 頂点 a,b,c による三角形塗りつぶしする命令を出力する。
 * あらかじめ以下のルールで値をセットしておくこと。 演算結果は存在しない。
 * fixL = x0, fixR = y0, fixLx = x1, fixRx = y1, fixT1 = x2, fixT2 = y2,
 * fixT = mode, fixS = RGB
 */
static void __func_filltri(void)
{
        beginF();

        /* min, mid, max を調べて min,max 間の中点座標単位を fixT3, fixT4 に得て、
         * それら中点座標を用いて、2つのスキャンライン三角形に分割し、それぞれを描画する。
         */

        /* y0,y1,y2 のmin,mid,maxを得る。
         * 結果は fixT3
         */
        push_eoe();
                pA("fixL = fixR;");
                pA("fixR = fixRx;");
                pA("fixS = fixT2;");
                __func_search_minmidmax3();
        pop_eoe();

        pA("fixT3 = fixA;");

        /* 頂点をmin,mid,max順に再配置
         */

        /* 012 */
        pA("if (fixT3 == %d) {", (0 << 4) | (1 << 2) | (2 << 0));
                pA("fixA = fixT1; fixT1 = fixL; fixL = fixA;");
                pA("fixA = fixT2; fixT2 = fixR; fixR = fixA;");
        pA("}");

        /* 021 */
        pA("if (fixT3 == %d) {", (0 << 4) | (2 << 2) | (1 << 0));
                pA("fixA = fixT1; fixT1 = fixL; fixL = fixLx; fixLx = fixA;");
                pA("fixA = fixT2; fixT2 = fixR; fixR = fixRx; fixRx = fixA;");
        pA("}");

        /* 120 */
        pA("if (fixT3 == %d) {", (1 << 4) | (2 << 2) | (0 << 0));
                pA("fixA = fixT1; fixT1 = fixLx; fixLx = fixA;");
                pA("fixA = fixT2; fixT2 = fixRx; fixRx = fixA;");
        pA("}");

        /* 102 */
        pA("if (fixT3 == %d) {", (1 << 4) | (0 << 2) | (2 << 0));
                pA("fixA = fixT1; fixT1 = fixLx; fixLx = fixL; fixL = fixA;");
                pA("fixA = fixT2; fixT2 = fixRx; fixRx = fixR; fixR = fixA;");
        pA("}");

        /* 201 */
        pA("if (fixT3 == %d) {", (2 << 4) | (0 << 2) | (1 << 0));
                pA("fixA = fixLx; fixLx = fixL; fixL = fixA;");
                pA("fixA = fixRx; fixRx = fixR; fixR = fixA;");
        pA("}");

        /* 210 の場合は変化無し */

        /* min,max間を midYで分割した場合のsx,syを得る
         * fixT3:sx, fixT4:sy
         */
        push_eoe();
                pA("fixS = fixRx;");

                pA("fixLx = fixT1;");
                pA("fixRx = fixT2;");

                __func_linesprit_y();
        pop_eoe();

        pA("fixT3 = fixA;");
        pA("fixT4 = fixRx;");

        /* 三角形 s,mid,min の描画
         */
        push_eoe();
                pA("fixT1 = fixL;");
                pA("fixT2 = fixR;");

                pA("fixL = fixT3;");
                pA("fixR = fixT4;");

                __func_filltri_sl_common(">=", "-");
        pop_eoe();

        /* 三角形 s,mid,max の描画
         */
        push_eoe();
                pA("fixL = fixT3;");
                pA("fixR = fixT4;");

                __func_filltri_sl_common("<=", "+");
        pop_eoe();

        endF();
}

/* 行列のコピー命令を出力する
 * 行および列が同じ大きさの場合のみ、対応する各要素同士をコピーする。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_copy(const char* strA, const char* strL)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);
        struct Var* varL = varlist_search(strL);

        /* コピーする配列の要素数が異なる場合はエラーとする（コンパイル時） */
        if ((varA->col_len != varL->col_len) || (varA->row_len != varL->row_len))
                yyerror("syntax err: 行か列が異なる行列のコピーは未サポートです");

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varL->array_len - 1);

        beginF();

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpL;");
                read_heap_inline_direct("heap_socket");

                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpA;");
                write_heap_inline_direct("heap_socket");

                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label);
        pA("}");

        endF();
}

/* 行列の全ての要素に任意のスカラー値をセットする
 * あらかじめ matfixL に値をセットしておくこと（fix32型）
 * matfixLに0をセットしておけば mat a := zer 相当になる。
 * matfixLに(1 << 16)をセットしておけば mat a := con 相当になる。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_scalar(const char* strA)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varA->array_len - 1);

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        beginF();

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpA;");
                write_heap_inline_direct("matfixL");

                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label);
        pA("}");

        endF();
}

/* 行列に単位行列をセットする
 * 正方行列でない場合はエラーとなる。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_idn(const char* strA)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);

        /* 正方行列では無い場合はエラーとする（コンパイル時） */
        if (varA->col_len != varA->row_len)
                yyerror("syntax err: 正方行列ではない行列へ単位行列をセットしようとしました");

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varA->array_len - 1);

        /* 対角成分となる要素のインデックスは、 col_len + 1 の倍数インデックスであるはず */
        pA("matfixtmp = %d;", varA->col_len + 1);

        beginF();

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label_row = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label_row);

        pA("if (matcountrow >= 0) {");
                /* インデックスが col_len + 1 の倍数であれば対角成分 */
                pA("if ((matcountrow %% matfixtmp) == 0) {");
                        pA("heap_socket = %d;", 1 << 16);
                        pA("heap_offset = matcountrow << 16;");
                        pA("heap_base = matbpA;");
                        write_heap_inline_direct("heap_socket");

                /* 対角成分では無い場合 */
                pA("} else {");
                        pA("heap_socket = 0;");
                        pA("heap_offset = matcountrow << 16;");
                        pA("heap_base = matbpA;");
                        write_heap_inline_direct("heap_socket");

                pA("}");

                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label_row);
        pA("}");

        endF();
}

/* 行列の転置行列を得る
 * 行列strLの転置行列を、行列strAへセットする。
 *
 * strAの行サイズとstrLの列サイズが同じで、かつstrAの列サイズとstrLの行サイズが同じ場合のみ動作する。
 * すなわち転置後の行列サイズが噛み合わない場合はエラーとなる。
 * 例:
 * dim a(x,y); dim b(y,x); ならば動作する。
 * dim a(x,x); dim b(x,x); ならば動作する。
 * dim a(x,y); dim b(x,y); ならばエラー。 (x != y)
 *
 * strA と strL が同じ記憶領域だった場合でも問題無く動作する
 * （バッファーを噛ませてあるので、スワップによる値の破壊は無い）
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_trn(const char* strA, const char* strL)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);
        struct Var* varL = varlist_search(strL);

        /* 転置後の行列サイズと噛み合わない場合はエラー（コンパイル時） */
        if ((varA->col_len != varL->row_len) || (varA->row_len != varL->col_len))
                yyerror("syntax err: 転置後の行列サイズと合いません。列->行、行->列、で要素数が対応している必要があります");

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matcol = %d;", varA->col_len);
        pA("matrow = %d;", varA->row_len);

        beginF();

        /* 2重のforループ
         */
        pA("matcountrow = 0;");

        /* 局所ループ用に無名ラベルをセット （外側forの戻り位置）
         */
        const int32_t local_label_row = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label_row);

        pA("if (matcountrow < matrow) {");
                pA("matcountcol = 0;");

                /* 局所ループ用に無名ラベルをセット （内側forの戻り位置）
                 */
                const int32_t local_label_col = cur_label_index_head;
                cur_label_index_head++;
                pA("LB(1, %d);", local_label_col);

                pA("if (matcountcol < matcol) {");
                        /* strL の読み込みオフセットを計算
                         */
                        pA("matfixL = matrow * matcountcol;");
                        pA("matfixL += matcountrow;");
                        pA("matfixL <<= 16;");

                        /* strA の書き込みオフセットを計算（strLの行と列を入れ替えたオフセット）
                         */
                        pA("matfixA = matcol * matcountrow;");
                        pA("matfixA += matcountcol;");
                        pA("matfixA <<= 16;");

                        /* 要素のスワップ
                         * strA, strL の記憶領域が同一の場合でも動作するように一時変数を噛ませてスワップ
                         */
                        pA("heap_offset = matfixA;");
                        pA("heap_base == matbpA;");
                        read_heap_inline_direct("matfixtmp");

                        pA("heap_offset = matfixL;");
                        pA("heap_base = matbpL;");
                        read_heap_inline_direct("heap_socket");
                        pA("heap_offset = matfixA;");
                        pA("heap_base = matbpA;");
                        write_heap_inline_direct("heap_socket");

                        pA("heap_offset = matfixL;");
                        pA("heap_base = matbpL;");
                        write_heap_inline_direct("matfixtmp");

                        /* 内側forループの復帰
                         */
                        pA("matcountcol++;");
                        pA("PLIMM(P3F, %d);", local_label_col);
                pA("}");

                /* 外側forループの復帰
                 */
                pA("matcountrow++;");
                pA("PLIMM(P3F, %d);", local_label_row);
        pA("}");

        endF();
}

#define OPE_MATRIX_MERGE_COMMON_TYPE_ADD 0
#define OPE_MATRIX_MERGE_COMMON_TYPE_SUB 1

/* 行列の各要素同士での加算、減算を行う。
 * 行および列が同じ大きさの場合のみ、対応する各要素同士を加算する。
 *
 * type に OPE_MATRIX_MERGE_COMMON_TYPE_ADD を渡せば行列の各要素同士の加算。
 * type に OPE_MATRIX_MERGE_COMMON_TYPE_SUB を渡せば行列の各要素同士の減算。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_merge_common(const char* strA, const char* strL, const char* strR,
                                    const int32_t type)
{
        /* type の値が不正な場合はエラー（コンパイル時） */
        switch (type) {
        case OPE_MATRIX_MERGE_COMMON_TYPE_ADD:
        case OPE_MATRIX_MERGE_COMMON_TYPE_SUB:
                break;

        default:
                yyerror("system err: ope_matrix_merge_common(), type");
        }

        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* コピーする配列の要素数が異なる場合はエラーとする（コンパイル時） */
        if (!
                ((varA->col_len == varL->col_len) && (varA->col_len == varR->col_len) &&
                 (varA->row_len == varL->row_len) && (varA->row_len == varR->row_len))
        )
                yyerror("syntax err: 行か列が異なる行列（またはベクトル）の和、差、積の演算は未サポートです");

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varA->array_len - 1);

        /* 演算種類のフラグをセット */
        pA("matfixtmp = %d;", type);

        beginF();

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                /* strL, strR から値を読み込む
                 * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                 * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                 */
                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpL;");
                read_heap_inline_direct("fixL");

                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpR;");
                read_heap_inline_direct("fixR");

                /* 演算種類応じて分岐
                 * } else if { を使わないのは意図的。（アセンブラーのバグ対策）
                 */

                /* 加算の場合 */
                pA("if (matfixtmp == %d) {", OPE_MATRIX_MERGE_COMMON_TYPE_ADD);
                        pA("heap_socket = fixL + fixR;");

                        /* 演算結果をstrAへ書き込む */
                        pA("heap_offset = matcountrow << 16;");
                        pA("heap_base = matbpA;");
                        write_heap_inline_direct("heap_socket");
                pA("}");

                /* 減算の場合 */
                pA("if (matfixtmp == %d) {", OPE_MATRIX_MERGE_COMMON_TYPE_SUB);
                        pA("heap_socket = fixL - fixR;");

                        /* 演算結果をstrAへ書き込む */
                        pA("heap_offset = matcountrow << 16;");
                        pA("heap_base = matbpA;");
                        write_heap_inline_direct("heap_socket");
                pA("}");

                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label);
        pA("}");

        endF();
}

/* 行列同士の加算を行う。
 * 行および列が同じ大きさの場合のみ、対応する各要素同士を加算する。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_add(const char* strA, const char* strL, const char* strR)
{
        ope_matrix_merge_common(strA, strL, strR, OPE_MATRIX_MERGE_COMMON_TYPE_ADD);
}

/* 行列同士の減算を行う。
 * 行および列が同じ大きさの場合のみ、対応する各要素同士を減算する。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_sub(const char* strA, const char* strL, const char* strR)
{
        ope_matrix_merge_common(strA, strL, strR, OPE_MATRIX_MERGE_COMMON_TYPE_SUB);
}

/* ベクトル同士の乗算を行う。
 * strL, strR が同じ長さで、かつ、strAがスカラーの場合のみ乗算する。
 *
 * strA, strL, strR のメモリー領域が重複していても問題無く動作する。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_mul_vv(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* strL と strR の要素数が異なる場合はエラーとする（コンパイル時） */
        if ((varL->col_len != varR->col_len) || (varL->row_len != varR->row_len))
                yyerror("syntax err: a = b * c において、 b, c の要素数が異なります");

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varL->array_len - 1);

        beginF();

        /* 演算結果の tmp 用レジスターを初期化 */
        pA("matfixA = 0;");

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                /* strL, strR から値を読み込む
                 * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                 * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                 */
                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpL;");
                read_heap_inline_direct("fixL");

                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpR;");
                read_heap_inline_direct("fixR");

                __func_mul();

                /* 乗算結果をmatfixAへ累積させる */
                pA("matfixA += fixA;");

                /* ループの先頭へジャンプ
                 */
                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label);
        pA("}");

        /* 演算結果を strA へ書き込む */
        pA("heap_offset = 0;");
        pA("heap_base = matbpA;");
        write_heap_inline_direct("matfixA");

        endF();
}

/* 3次ベクトル同士のクロス積を行う。
 * strA, strL, strR が全て3次ベクトルの場合のみ。
 *
 * strA, strL, strR のメモリー領域が重複してる場合は値が壊れる。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_cross_product_vv(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* strA, strL, strR が全て3次ベクトルの場合のみ動作する。それ以外はエラーとする（コンパイル時） */
        if (!
                ((varA->row_len <= 1) && (varL->row_len <= 1) && (varR->row_len <= 1) &&
                 (varA->col_len == 3) && (varL->col_len == 3) && (varR->col_len == 3))
        ) {
                yyerror("syntax err: クロス積を計算可能なのは3次ベクトルのみです");
        }

        beginF();

        /* 短いベクトル同士の演算なので、値を一度に全てレジスターへ読んで計算できる
         */
        pA("heap_base = matbpL;");
        pA("heap_offset = %d;", 0 << 16);
        read_heap_inline_direct("matfixE0");
        pA("heap_base = matbpL;");
        pA("heap_offset = %d;", 1 << 16);
        read_heap_inline_direct("matfixE1");
        pA("heap_base = matbpL;");
        pA("heap_offset = %d;", 2 << 16);
        read_heap_inline_direct("matfixE2");

        pA("heap_base = matbpR;");
        pA("heap_offset = %d;", 0 << 16);
        read_heap_inline_direct("matfixE3");
        pA("heap_base = matbpR;");
        pA("heap_offset = %d;", 1 << 16);
        read_heap_inline_direct("matfixE4");
        pA("heap_base = matbpR;");
        pA("heap_offset = %d;", 2 << 16);
        read_heap_inline_direct("matfixE5");

        /* E1*E5 - E2*E4 -> E6
         */
        pA("fixL = matfixE1;");
        pA("fixR = matfixE5;");
        __func_mul();
        pA("matfixE6 = fixA;");

        pA("fixL = matfixE2;");
        pA("fixR = matfixE4;");
        __func_mul();
        pA("matfixE6 -= fixA;");

        /* E2*E3 - E0*E5 -> E7
         */
        pA("fixL = matfixE2;");
        pA("fixR = matfixE3;");
        __func_mul();
        pA("matfixE7 = fixA;");

        pA("fixL = matfixE0;");
        pA("fixR = matfixE5;");
        __func_mul();
        pA("matfixE7 -= fixA;");

        /* E0*E4 - E1*E3 -> E8
         */
        pA("fixL = matfixE0;");
        pA("fixR = matfixE4;");
        __func_mul();
        pA("matfixE8 = fixA;");

        pA("fixL = matfixE1;");
        pA("fixR = matfixE3;");
        __func_mul();
        pA("matfixE8 -= fixA;");

        /* 演算結果を strA へ書き込む
         */
        pA("heap_base = matbpA;");
        pA("heap_offset = %d;", 0 << 16);
        write_heap_inline_direct("matfixE6");
        pA("heap_base = matbpA;");
        pA("heap_offset = %d;", 1 << 16);
        write_heap_inline_direct("matfixE7");
        pA("heap_base = matbpA;");
        pA("heap_offset = %d;", 2 << 16);
        write_heap_inline_direct("matfixE8");

        endF();
}

/* ベクトル（または行列）のスカラー乗算を行う。
 * strA, strR が同じ長さのベクトル（または行列）の場合のみ乗算する。
 *
 * strAの記憶領域が、strR と重複していても問題無く動作する。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_mul_sv(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varA = varlist_search(strA);
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* strA と strR の要素数が異なる場合はエラーとする（コンパイル時） */
        if ((varA->col_len != varR->col_len) || (varA->row_len != varR->row_len))
                yyerror("syntax err: a = s * b において、 a,b の要素数が異なります");

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varA->array_len - 1);

        beginF();

        /* strL から matfixL へ値を読み込む
         */
        pA("heap_offset = 0;");
        pA("heap_base = matbpL;");
        read_heap_inline_direct("matfixL");

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                /* strR から値を読み込む
                 * heap_socket を fixR へ代入してるのはタイポ間違いではない。意図的。
                 * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                 */
                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpR;");
                read_heap_inline_direct("fixR");

                 /* fixL = matfixL も同様の理由。
                 * また、matfixL はスカラーなのに、毎回 fixL へセットしてる理由は、
                 * __func_mul() の呼び出しの際に、（高速化の為に） eoe のスタック退避・復帰を省略してるので、
                 * fixL, fixR などの eoe メンバーは暗黙に破壊される可能性がありうるので。
                 */
                pA("fixL = matfixL;");

                __func_mul();

                /* 演算結果をstrAへ書き込む */
                pA("heap_offset = matcountrow << 16;");
                pA("heap_base = matbpA;");
                write_heap_inline_direct("fixA");

                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label);
        pA("}");

        endF();
}

/* 行列同士の乗算を行う。
 * strA, strL, strR が全て正方行列で、かつ、行および列が同じ大きさの場合のみ乗算する。
 *
 * strAの記憶領域が、strLまたはstrRと重複していた場合は、正常な計算結果は得られない。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_mul_mm(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);
        struct Var* varA = varlist_search(strA);

        /* strA, strL, strR が正方行列で、かつ、行および列が同じ大きさの場合以外はエラーとなる */
        if (!
                (varA->col_len == varL->col_len) && (varA->col_len == varL->row_len) &&
                (varA->col_len == varR->col_len) && (varA->col_len == varR->row_len) &&
                (varA->col_len == varA->row_len)
        )
                yyerror("syntax err: 行または列が異なる、または正方行列以外の積を得ようとしました");

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matrow = %d;", varA->row_len);
        pA("matcol = %d;", varA->col_len);

        beginF();

        /* 3重のforループ
         */
        pA("matcountrow = 0;");

        /* 局所ループ用に無名ラベルをセット （外側forの戻り位置）
         */
        const int32_t local_label_row = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label_row);

        pA("if (matcountrow < matrow) {");
                pA("matcountcol = 0;");

                /* 局所ループ用に無名ラベルをセット （中間forの戻り位置）
                 */
                const int32_t local_label_col = cur_label_index_head;
                cur_label_index_head++;
                pA("LB(1, %d);", local_label_col);

                pA("if (matcountcol < matcol) {");
                        pA("matfixtmp = 0;");
                        pA("matfixA = 0;");

                        /* 局所ループ用に無名ラベルをセット （内側forの戻り位置）
                         */
                        const int32_t local_label_fixtmp = cur_label_index_head;
                        cur_label_index_head++;
                        pA("LB(1, %d);", local_label_fixtmp);

                        pA("if (matfixtmp < matcol) {");
                                /* strL の読み込みオフセットを計算
                                 */
                                pA("matfixL = matcol * matcountrow;");
                                pA("matfixL += matfixtmp;");
                                pA("matfixL <<= 16;");

                                /* strR の読み込みオフセットを計算
                                 */
                                pA("matfixR = matcol * matfixtmp;");
                                pA("matfixR += matcountcol;");
                                pA("matfixR <<= 16;");

                                /* strLの要素 * strRの要素 の演算を行い、
                                 * 計算の途中経過をmatfixAへ加算
                                 *
                                 * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                                 * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                                 */
                                pA("heap_offset = matfixL;");
                                pA("heap_base = matbpL;");
                                read_heap_inline_direct("fixL");

                                pA("heap_offset = matfixR;");
                                pA("heap_base = matbpR;");
                                read_heap_inline_direct("fixR");

                                /* 固定小数点数なので乗算は __func_mul() を使う必要がある
                                 * 乗算結果は matfixA に加算して累積させる
                                 */
                                __func_mul();
                                pA("matfixA += fixA;");

#ifdef DEBUG_OPE_MATRIX_MUL_MM
                                pA("junkApi_putConstString('\\n fixL : ');");
                                pA("junkApi_putStringDec('\\1', fixL, 6, 0);");

                                pA("junkApi_putConstString(' fixR : ');");
                                pA("junkApi_putStringDec('\\1', fixR, 6, 0);");

                                pA("junkApi_putConstString(' nmatfixA : ');");
                                pA("junkApi_putStringDec('\\1', matfixA, 6, 0);");
#endif /* DEBUG_OPE_MATRIX_MUL_MM */

                                /* 内側forループの復帰
                                 */
                                pA("matfixtmp++;");
                                pA("PLIMM(P3F, %d);", local_label_fixtmp);
                        pA("}");

                        /* strA へ結果を書き込む
                         */
                        pA("heap_offset = matcol * matcountrow;");
                        pA("heap_offset += matcountcol;");
                        pA("heap_offset <<= 16;");

#ifdef DEBUG_OPE_MATRIX_MUL_MM
                        pA("junkApi_putConstString('\\nstrA : ');");
                        pA("junkApi_putStringDec('\\1', heap_socket, 6, 0);");
#endif /* DEBUG_OPE_MATRIX_MUL_MM */

                        pA("heap_base = matbpA;");
                        write_heap_inline_direct("matfixA");

                        /* 中間forループの復帰
                         */
                        pA("matcountcol++;");
                        pA("PLIMM(P3F, %d);", local_label_col);
                pA("}");

                /* 外側forループの復帰
                 */
                pA("matcountrow++;");
                pA("PLIMM(P3F, %d);", local_label_row);
        pA("}");

        endF();
}

/* ベクトル * 行列 の乗算を行う。
 * strA, strL は同じ長さのベクトルで、かつ、正方行列 strR のrow_len(行数)と同じ大きさの場合のみ乗算する。
 * 左からベクトルを乗算するケース（V * M）に相当。
 *
 * strAの記憶領域が、strLと重複していた場合は、正常な計算結果は得られない。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_mul_vm(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);
        struct Var* varA = varlist_search(strA);

        /* ベクトル strA, strL が異なる長さの場合はエラーとなる */
        if (varA->col_len != varL->col_len)
                yyerror("syntax err: A = V * M において、ベクトルA, Vの長さが異なります");

        /* ベクトル strA のサイズが、 正方行列 strR の行サイズと異なる場合はエラーとなる */
        if (varA->col_len != varR->row_len)
                yyerror("syntax err: A = V * M において、ベクトルA,Vのサイズが、正方行列Mの列サイズと異なります");

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matrow = %d;", varR->row_len);
        pA("matcol = %d;", varR->col_len);

        beginF();

        /* 2重のforループ
         */
        pA("matcountrow = 0;");

        /* 局所ループ用に無名ラベルをセット （外側forの戻り位置）
         */
        const int32_t local_label_row = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label_row);

        pA("if (matcountrow < matrow) {");
                pA("matcountcol = 0;");
                pA("matfixA = 0;");

                /* 局所ループ用に無名ラベルをセット （内側forの戻り位置）
                 */
                const int32_t local_label_col = cur_label_index_head;
                cur_label_index_head++;
                pA("LB(1, %d);", local_label_col);

                pA("if (matcountcol < matcol) {");
                        /* strL の読み込みオフセットを計算
                         */
                        pA("matfixL = matcountcol;");
                        pA("matfixL <<= 16;");

                        /* strR の読み込みオフセットを計算
                         */
                        pA("matfixR = matrow * matcountcol;");
                        pA("matfixR += matcountcol;");
                        pA("matfixR <<= 16;");

                        /* strLの要素 * strRの要素 の演算を行い、
                         * 計算の途中経過をmatfixAへ加算
                         *
                         * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                         * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                         */
                        pA("heap_offset = matfixL;");
                        pA("heap_base = matbpL;");
                        read_heap_inline_direct("fixL");

                        pA("heap_offset = matfixR;");
                        pA("heap_base = matbpR;");
                        read_heap_inline_direct("fixR");

                        /* 固定小数点数なので乗算は __func_mul() を使う必要がある
                         * 乗算結果は matfixA に加算して累積させる
                         */
                        __func_mul();
                        pA("matfixA += fixA;");

                        /* 内側forループの復帰
                         */
                        pA("matcountcol++;");
                        pA("PLIMM(P3F, %d);", local_label_col);
                pA("}");

                /* strA へ結果を書き込む
                 */
                pA("heap_offset = matcountrow;");
                pA("heap_offset <<= 16;");

                pA("heap_base = matbpA;");
                write_heap_inline_direct("matfixA");

                /* 外側forループの復帰
                 */
                pA("matcountrow++;");
                pA("PLIMM(P3F, %d);", local_label_row);
        pA("}");

        endF();
}

/* 行列 * ベクトルの乗算を行う。
 * strA, strR は同じ長さのベクトルで、かつ、正方行列 strL のcol_len(行数)と同じ大きさの場合のみ乗算する。
 * 右からベクトルを乗算するケース（M * V）に相当。
 *
 * strAの記憶領域が、strRと重複していた場合は、正常な計算結果は得られない。
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_mul_mv(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);
        struct Var* varA = varlist_search(strA);

        /* ベクトル strA, strR が異なる長さの場合はエラーとなる */
        if (varA->col_len != varR->col_len)
                yyerror("syntax err: A = M * V において、ベクトルA, Vの長さが異なります");

        /* ベクトル strA のサイズが、 正方行列 strL の列サイズと異なる場合はエラーとなる */
        if (varA->col_len != varL->col_len)
                yyerror("syntax err: A = M * V において、ベクトルA,Vのサイズが、正方行列Mの行サイズと異なります");

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matrow = %d;", varL->row_len);
        pA("matcol = %d;", varL->col_len);

        beginF();

        /* 2重のforループ
         */
        pA("matcountrow = 0;");

        /* 局所ループ用に無名ラベルをセット （外側forの戻り位置）
         */
        const int32_t local_label_row = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label_row);

        pA("if (matcountrow < matrow) {");
                pA("matcountcol = 0;");
                pA("matfixA = 0;");

                /* 局所ループ用に無名ラベルをセット （内側forの戻り位置）
                 */
                const int32_t local_label_col = cur_label_index_head;
                cur_label_index_head++;
                pA("LB(1, %d);", local_label_col);

                pA("if (matcountcol < matcol) {");
                        /* strL の読み込みオフセットを計算
                         */
                        pA("matfixL = matcol * matcountrow;");
                        pA("matfixL += matcountcol;");
                        pA("matfixL <<= 16;");

                        /* strR の読み込みオフセットを計算
                         */
                        pA("matfixR = matcountcol;");
                        pA("matfixR <<= 16;");

                        /* strLの要素 * strRの要素 の演算を行い、
                         * 計算の途中経過をmatfixAへ加算
                         *
                         * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                         * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                         */
                        pA("heap_offset = matfixL;");
                        pA("heap_base = matbpL;");
                        read_heap_inline_direct("fixL");

                        pA("heap_offset = matfixR;");
                        pA("heap_base = matbpR;");
                        read_heap_inline_direct("fixR");

                        /* 固定小数点数なので乗算は __func_mul() を使う必要がある
                         * 乗算結果は matfixA に加算して累積させる
                         */
                        __func_mul();
                        pA("matfixA += fixA;");

                        /* 内側forループの復帰
                         */
                        pA("matcountcol++;");
                        pA("PLIMM(P3F, %d);", local_label_col);
                pA("}");

                /* strA へ結果を書き込む
                 */
                pA("heap_offset = matcountrow;");
                pA("heap_offset <<= 16;");

                pA("heap_base = matbpA;");
                write_heap_inline_direct("matfixA");

                /* 外側forループの復帰
                 */
                pA("matcountrow++;");
                pA("PLIMM(P3F, %d);", local_label_row);
        pA("}");

        endF();
}

/* 行列の乗算を行う
 * 以下の組み合わせに対応（Mは正方行列、VはMの行もしくは列と同じ長さのベクトル、Sはスカラーである前提。それ以外はエラー）
 * M = M * M
 * V = M * V
 * V = V * M
 * V = V * V
 * S = V * V
 * M = S * M
 * V = S * V
 *
 * A = B * C において、Aの記憶領域が、BまたはCと重複していた場合は、正常な計算結果は得られないケースがありうる。
 *
 * S = V * V の場合は内積だが、
 * V = V * V の場合はクロス積となる。（ただしクロス積はVが3次ベクトルの場合のみ）
 *
 * あらかじめ各 str? に対応するアタッチを matbp? にセットしておくこと
 */
static void ope_matrix_mul(const char* strA, const char* strL, const char* strR)
{
        /* 変数のスペックを得る。（コンパイル時） */
        struct Var* varL = varlist_search(strL);
        struct Var* varR = varlist_search(strR);
        struct Var* varA = varlist_search(strA);

        /* 実行時に matbp? < 0 （空の場合）ならば、
         * デフォルトの base_ptr を設定する命令の定数設定（コンパイル時） */
        pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);
        pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);
        pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* strAが正方行列な場合 */
        if ((varA->row_len >= 2) && (varA->row_len == varA->col_len)) {
                /* strL がスカラーの場合 */
                if ((varL->row_len <= 1) && (varL->col_len <= 1)) {
                        ope_matrix_mul_sv(strA, strL, strR);
                        return;

                /* strL がスカラー以外の場合 */
                } else {
                        ope_matrix_mul_mm(strA, strL, strR);
                        return;
                }

        /* strAがベクトルな場合 */
        } else if ((varA->row_len <= 1) && (varA->col_len >= 2)) {
                /* strA, strL, strR が全て3次ベクトルの場合はクロス積を計算する */
                if ((varA->row_len <= 1) && (varL->row_len <= 1) && (varR->row_len <= 1) &&
                    (varA->col_len == 3) && (varL->col_len == 3) && (varR->col_len == 3))
                {
                        ope_matrix_cross_product_vv(strA, strL, strR);
                        return;

                /* strL がスカラーの場合 */
                } else if ((varL->row_len <= 1) && (varL->col_len <= 1)) {
                        ope_matrix_mul_sv(strA, strL, strR);
                        return;

                /* strL が正方行列の場合 */
                } else if ((varL->row_len >= 2) && (varL->row_len == varL->col_len)) {
                        ope_matrix_mul_mv(strA, strL, strR);
                        return;

                /* strR が正方行列の場合 */
                } else if ((varR->row_len >= 2) && (varR->row_len == varR->col_len)) {
                        ope_matrix_mul_vm(strA, strL, strR);
                        return;
                }

        /* strAがスカラーな場合 */
        } else if ((varA->row_len <= 1) && (varA->col_len <= 1)) {
                /* strL, strR が同じ長さのベクトルの場合 */
                if ((varL->row_len <= 1) && (varL->col_len >= 2) &&
                    (varL->row_len == varR->row_len) && (varL->col_len == varR->col_len))
                {
                        ope_matrix_mul_vv(strA, strL, strR);
                        return;
                }
        }

        /* どれにも該当しない場合はエラーとする */
        yyerror("syntax err: 行列の積において型にエラーがあります。行列が正方行列では無いか、サイズが異なる等が考えられます");
}

%}

%union {
        int32_t ival;
        float fval;
        char sval[0x1000];
        struct Var* varptr;
}

%token __STATE_IF __STATE_ELSE
%token __STATE_FOR __STATE_TO __STATE_STEP __STATE_NEXT __STATE_END
%token __STATE_READ __STATE_DATA __OPE_ON __OPE_GOTO __OPE_GOSUB __OPE_RETURN
%token __STATE_MAT __STATE_MAT_ZER __STATE_MAT_CON __STATE_MAT_IDN __STATE_MAT_TRN
%token __OPE_SUBST
%token __STATE_LET __STATE_DIM
%token __STATE_FUNCTION
%token __FUNC_PRINT __FUNC_INPUT __FUNC_PEEK __FUNC_POKE __FUNC_CHR_S __FUNC_VAL __FUNC_MID_S __FUNC_RND __FUNC_INPUT_S

%token __FUNC_SIN __FUNC_COS __FUNC_TAN __FUNC_SQRT

%token __FUNC_OPENWIN __FUNC_TORGB __FUNC_DRAWPOINT __FUNC_DRAWLINE __FUNC_SLEEP
%token __FUNC_FILLTRI __FUNC_FILLRECT

%left  __OPE_COMPARISON __OPE_NOT_COMPARISON __OPE_ISSMALL __OPE_ISSMALL_COMP __OPE_ISLARGE __OPE_ISLARGE_COMP
%left  __OPE_ADD __OPE_SUB
%left  __OPE_MUL __OPE_DIV __OPE_MOD __OPE_POWER
%left  __OPE_OR __OPE_AND __OPE_XOR __OPE_NOT
%left  __OPE_LSHIFT __OPE_RSHIFT
%left  __OPE_COMMA
%token __OPE_PLUS __OPE_MINUS
%token __OPE_ATTACH __OPE_ADDRESS
%token __LB __RB __DECL_END __IDENTIFIER __LABEL __DEFINE_LABEL __EOF
%token __ARRAY_LB __ARRAY_RB
%token __BLOCK_LB __BLOCK_RB
%token __CONST_STRING __CONST_FLOAT __CONST_INTEGER

%type <ival> __CONST_INTEGER
%type <fval> __CONST_FLOAT
%type <sval> __CONST_STRING __IDENTIFIER __LABEL __DEFINE_LABEL

%type <sval> func_print func_peek func_poke

%type <sval> func_sin func_cos func_tan

%type <sval> func_openwin func_torgb func_drawpoint func_drawline func_sleep
%type <sval> func_filltri func_fillrect

%type <sval> operation const_variable read_variable
%type <sval> selection_if selection_if_v selection_if_e
%type <sval> iterator_for initializer expression assignment jump define_label function
%type <sval> ope_matrix
%type <sval> syntax_tree declaration_list declaration declaration_block
%type <sval> define_function
%type <sval> var_identifier
%type <ival> expression_list identifier_list attach_base

%start syntax_tree

%%

syntax_tree
        : declaration_list __EOF {
                YYACCEPT;
                start_tune_process();
        }
        ;

declaration_list
        : declaration
        | declaration declaration_list
        ;

declaration_block
        : __BLOCK_LB __BLOCK_RB {
                /* 空の場合は何もしない */
        }
        | __BLOCK_LB {
                varlist_scope_push();   /* コンパイル時 */
        } declaration_list __BLOCK_RB {
                varlist_scope_pop();    /* コンパイル時 */
        }
        ;

declaration
        : declaration_block
        | initializer __DECL_END
        | assignment __DECL_END
        | ope_matrix __DECL_END
        | expression __DECL_END
        | selection_if
        | iterator_for
        | jump __DECL_END
        | define_label __DECL_END
        | define_function
        | __DECL_END
        ;

expression
        : operation
        | const_variable
        | read_variable
        | comparison
        | function
        ;

expression_list
        : {
                $$ = 0;
        }
        | expression {
                $$ = 1;
        }
        | expression __OPE_COMMA expression_list {
                $$ = 1 + $3;
        }
        ;

function
        : func_print
        | __FUNC_INPUT {}
        | func_peek
        | func_poke
        | __FUNC_CHR_S expression {}
        | __FUNC_VAL expression {}
        | __FUNC_MID_S expression {}
        | __FUNC_RND {}
        | __FUNC_INPUT_S {}
        | func_sin
        | func_cos
        | func_tan
        | func_sqrt
        | func_openwin
        | func_torgb
        | func_drawpoint
        | func_drawline
        | func_filltri
        | func_fillrect
        | func_sleep
        ;

func_print
        : __FUNC_PRINT expression {
                pop_stack_direct("fixL");
                __func_print();
        }
        ;

func_peek
        : __FUNC_PEEK expression {
                pop_stack_direct("fixL");
                __func_peek();
                push_stack_direct("fixA");
        }
        ;

func_poke
        : __FUNC_POKE expression expression {
                pop_stack_direct("fixR");
                pop_stack_direct("fixL");
                __func_poke();
        }
        ;

func_sin
        : __FUNC_SIN expression {
                pop_stack_direct("fixL");
                __func_sin();
                push_stack_direct("fixA");
        }
        ;

func_cos
        : __FUNC_COS expression {
                pop_stack_direct("fixL");
                __func_cos();
                push_stack_direct("fixA");
        }
        ;

func_tan
        : __FUNC_TAN expression {
                pop_stack_direct("fixL");
                __func_tan();
                push_stack_direct("fixA");
        }
        ;

func_sqrt
        : __FUNC_SQRT expression {
                pop_stack_direct("fixL");
                __func_sqrt();
                push_stack_direct("fixA");
        }
        ;

func_openwin
        : __FUNC_OPENWIN expression expression {
                pop_stack_direct("fixR");       /* y */
                pop_stack_direct("fixL");       /* x */
                __func_openwin();
        }
        ;

func_torgb
        : __FUNC_TORGB expression expression expression
        {
                pop_stack_direct("fixS");       /* B */
                pop_stack_direct("fixR");       /* G */
                pop_stack_direct("fixL");       /* R */
                __func_torgb();
                push_stack_direct("fixA");
        }
        ;

func_drawpoint
        : __FUNC_DRAWPOINT expression expression expression expression
        {
                pop_stack_direct("fixS");       /* RGB */
                pop_stack_direct("fixR");       /* y0 */
                pop_stack_direct("fixL");       /* x0 */
                pop_stack_direct("fixT");       /* mode */
                __func_drawpoint();
        }
        ;

func_drawline
        : __FUNC_DRAWLINE expression expression expression expression expression expression
        {
                pop_stack_direct("fixS");       /* RGB */
                pop_stack_direct("fixRx");      /* y1 */
                pop_stack_direct("fixLx");      /* x1 */
                pop_stack_direct("fixR");       /* y0 */
                pop_stack_direct("fixL");       /* x0 */
                pop_stack_direct("fixT");       /* mode */
                __func_drawline();
        }
        ;

func_filltri
        : __FUNC_FILLTRI expression
                         expression expression expression expression expression expression
                         expression
        {
                pop_stack_direct("fixS");       /* RGB */
                pop_stack_direct("fixT2");      /* y2 */
                pop_stack_direct("fixT1");      /* x2 */
                pop_stack_direct("fixRx");      /* y1 */
                pop_stack_direct("fixLx");      /* x1 */
                pop_stack_direct("fixR");       /* y0 */
                pop_stack_direct("fixL");       /* x0 */
                pop_stack_direct("fixT");       /* mode */
                __func_filltri();
        }
        ;

func_fillrect
        : __FUNC_FILLRECT expression expression expression expression expression expression
        {
                pop_stack_direct("fixS");       /* RGB */
                pop_stack_direct("fixRx");      /* y1 */
                pop_stack_direct("fixLx");      /* x1 */
                pop_stack_direct("fixR");       /* y0 */
                pop_stack_direct("fixL");       /* x0 */
                pop_stack_direct("fixT");       /* mode */
                __func_fillrect();
        }
        ;

func_sleep
        : __FUNC_SLEEP expression expression {
                pop_stack_direct("fixR");       /* msec */
                pop_stack_direct("fixL");       /* mode */
                __func_sleep();
        }
        ;

initializer
        : __STATE_DIM __IDENTIFIER {
                varlist_add_local($2, 1, 1);
        }
        | __STATE_DIM __IDENTIFIER __ARRAY_LB __CONST_INTEGER __ARRAY_RB {
                varlist_add_local($2, 1, $4);
        }
        | __STATE_DIM __IDENTIFIER __ARRAY_LB __CONST_INTEGER __OPE_COMMA __CONST_INTEGER __ARRAY_RB {
                varlist_add_local($2, $4, $6);
        }
        ;

attach_base
        : {
                pA("attachstack_socket = -1;");
                push_attachstack_direct("attachstack_socket");
        }
        | expression __OPE_ATTACH {
                pop_stack_direct("stack_socket");
                push_attachstack_direct("stack_socket");
        }
        ;

var_identifier
        : attach_base __IDENTIFIER {
                strcpy($$, $2);
        }
        ;

assignment
        : var_identifier __OPE_SUBST expression {
                __assignment_scaler($1);
        }
        | var_identifier __ARRAY_LB expression_list __ARRAY_RB __OPE_SUBST expression {
                __assignment_array($1, $3);
        }
        ;

ope_matrix
        : __STATE_MAT var_identifier __OPE_SUBST var_identifier {
                pop_attachstack_direct("matbpL");
                pop_attachstack_direct("matbpA");

                ope_matrix_copy($2, $4);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_ZER {
                pop_attachstack_direct("matbpA");

                pA("matfixL = 0;");
                ope_matrix_scalar($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_CON {
                pop_attachstack_direct("matbpA");

                pA("matfixL = %d;", 1 << 16);
                ope_matrix_scalar($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST expression __OPE_MUL __STATE_MAT_CON {
                pop_stack_direct("matfixL");

                pop_attachstack_direct("matbpA");

                ope_matrix_scalar($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_IDN {
                pop_attachstack_direct("matbpA");

                ope_matrix_idn($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_TRN __LB var_identifier __RB {
                pop_attachstack_direct("matbpL");
                pop_attachstack_direct("matbpA");

                ope_matrix_trn($2, $6);
        }
        | __STATE_MAT var_identifier __OPE_SUBST var_identifier __OPE_ADD var_identifier {
                pop_attachstack_direct("matbpR");
                pop_attachstack_direct("matbpL");
                pop_attachstack_direct("matbpA");

                ope_matrix_add($2, $4, $6);
        }
        | __STATE_MAT var_identifier __OPE_SUBST var_identifier __OPE_SUB var_identifier {
                pop_attachstack_direct("matbpR");
                pop_attachstack_direct("matbpL");
                pop_attachstack_direct("matbpA");

                ope_matrix_sub($2, $4, $6);
        }
        | __STATE_MAT var_identifier __OPE_SUBST var_identifier __OPE_MUL var_identifier {
                pop_attachstack_direct("matbpR");
                pop_attachstack_direct("matbpL");
                pop_attachstack_direct("matbpA");

                ope_matrix_mul($2, $4, $6);
        }
        ;

const_variable
        : __CONST_STRING
        | __CONST_FLOAT {
                double a;
                double b = modf($1, &a);
                int32_t ia = ((int32_t)a) << 16;
                int32_t ib = ((int32_t)(0x0000ffff * b)) & 0x0000ffff;

                pA("stack_socket = %d;", ia | ib);
                push_stack_direct("stack_socket");
        }
        | __CONST_INTEGER {
                pA("stack_socket = %d;", $1 << 16);
                push_stack_direct("stack_socket");
        }
        ;

operation
        : expression __OPE_ADD expression {
                read_eoe_arg();
                __func_add();
                push_stack_direct("fixA");
        }
        | expression __OPE_SUB expression {
                read_eoe_arg();
                __func_sub();
                push_stack_direct("fixA");
        }
        | expression __OPE_MUL expression {
                read_eoe_arg();
                __func_mul();
                push_stack_direct("fixA");
        }
        | expression __OPE_DIV expression {
                read_eoe_arg();
                __func_div();
                push_stack_direct("fixA");
        }
        | expression __OPE_POWER expression {
                read_eoe_arg();
                __func_pow();
                push_stack_direct("fixA");
        }
        | expression __OPE_MOD expression {
                read_eoe_arg();
                __func_mod();
                push_stack_direct("fixA");
        }
        | expression __OPE_OR expression {
                read_eoe_arg();
                __func_or();
                push_stack_direct("fixA");
        }
        | expression __OPE_AND expression {
                read_eoe_arg();
                __func_and();
                push_stack_direct("fixA");
        }
        | expression __OPE_XOR expression {
                read_eoe_arg();
                __func_xor();
                push_stack_direct("fixA");
        }
        | __OPE_NOT expression {
                pop_stack_direct("fixL");
                __func_not();
                push_stack_direct("fixA");
        }
        | expression __OPE_LSHIFT expression {
                read_eoe_arg();
                __func_lshift();
                push_stack_direct("fixA");
        }
        | expression __OPE_RSHIFT expression {
                read_eoe_arg();
                __func_rshift();
                push_stack_direct("fixA");
        }
        | __OPE_ADD expression %prec __OPE_PLUS {
                /* 何もしない */
        }
        | __OPE_SUB expression %prec __OPE_MINUS {
                pop_stack_direct("fixL");
                __func_minus();
                push_stack_direct("fixA");
        }
        | __LB expression __RB {
                /* 何もしない */
        }
        ;

comparison
        : expression __OPE_COMPARISON expression {
                read_eoe_arg();

                pA("if (fixL == fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack_direct("stack_socket");
        }
        | expression __OPE_NOT_COMPARISON expression {
                read_eoe_arg();

                pA("if (fixL != fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack_direct("stack_socket");
        }
        | expression __OPE_ISSMALL expression {
                read_eoe_arg();

                pA("if (fixL < fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack_direct("stack_socket");
        }
        | expression __OPE_ISSMALL_COMP expression {
                read_eoe_arg();

                pA("if (fixL <= fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack_direct("stack_socket");
        }
        | expression __OPE_ISLARGE expression {
                read_eoe_arg();

                pA("if (fixL > fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack_direct("stack_socket");
        }
        | expression __OPE_ISLARGE_COMP expression {
                read_eoe_arg();

                pA("if (fixL >= fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack_direct("stack_socket");
        }
        ;

read_variable
        : __OPE_ADDRESS var_identifier {
                __read_variable_ptr_scaler($2);
        }
        | __OPE_ADDRESS var_identifier __ARRAY_LB expression_list __ARRAY_RB {
                __read_variable_ptr_array($2, $4);
        }
        | var_identifier {
                __read_variable_scaler($1);
        }
        | var_identifier __ARRAY_LB expression_list __ARRAY_RB {
                __read_variable_array($1, $3);
        }
        | var_identifier __LB expression_list __RB {
                __call_user_function($1);
        }
        ;

selection_if
        : selection_if_v selection_if_e
        | selection_if_v {
                pA(" ");
        }
        ;

selection_if_v
        : __STATE_IF __LB expression __RB {
                pop_stack_direct("stack_socket");
                pA("if (stack_socket != 0) {");
        } declaration {
                pA_nl("}");
        }

selection_if_e
        : __STATE_ELSE {
                pA(" else {");
        } declaration {
                pA("}");
        }
        ;

iterator_for
        : __STATE_FOR var_identifier {
                /* 変数のスペックを得る。（コンパイル時） */
                struct Var* var = varlist_search($2);
                if (var == NULL)
                        yyerror("syntax err: 未定義のスカラー変数を参照しようとしました");

                /* 変数が配列な場合はエラー */
                if (var->col_len != 1 || var->row_len != 1)
                        yyerror("syntax err: 配列変数へスカラーによる書き込みを行おうとしました");

                /* var（変数のスペック）は他の場所でも使うので、コンパイル時に参照できるように $$ で出力する。
                 * （以降は$<varptr>3で参照できる）
                 */
                $<varptr>$ = var;

        } __OPE_SUBST expression {
                /* このセクションはスカラー変数への代入
                 */

                /* スカラーなので書き込みオフセットは 0 */
                pA("heap_offset = 0;");

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 * このアタッチは以降も使うので、ポップ直後にプッシュしておく
                 */
                pop_attachstack_direct("attachstack_socket");
                push_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", $<varptr>3->base_ptr);

                /* 書き込む値を読んで書き込む */
                pop_stack_direct("stack_socket");
                write_heap_inline_direct("stack_socket");

                /* そして、代入後であるここに無名ラベルを作る（このforループは、以降はこの位置へと戻ってくる）
                 * また、このラベルは next で戻ってくる際に使うので、コンパイル時に参照できるように $$ で出力する。
                 * （以降は$<ival>6で参照できる）
                 * これはラベル番号で int32 型の値である。
                 * そして、ラベルを作成したので cur_label_index_head を一つ進める。
                 */
                pA("LB(1, %d);\n", cur_label_index_head);
                $<ival>$ = cur_label_index_head;
                cur_label_index_head++;

        } __STATE_TO expression {
                /* 条件を比較するために
                 * まずスタックに詰まれてる __STATE_TO expression (の戻り値)を得て、 forfixR（右辺用） へと退避しておく。
                 * （また、このポップは、変数を読む際に余分なスタックが残っていないように、スタックを掃除しておく意味も兼ねる）
                 */
                pop_stack_direct("forfixR");

                /* 次にスカラー変数から値を読み、 forfixL （左辺用） へと退避しておく。
                 */
                pA("heap_offset = 0;");

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 * このアタッチは以降も使うので、ポップ直後にプッシュしておく
                 */
                pop_attachstack_direct("attachstack_socket");
                push_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", $<varptr>3->base_ptr);

                read_heap_inline_direct("forfixL");

        } __STATE_STEP expression {
                /* 条件比較の方向を判断するために、stepの値を読む必要がある
                 * そして、最後の next の時点でインクリメントに使用するのに備えて、再びプッシュしておく
                 */
                pop_stack_direct("forfixtmp");
                push_stack_direct("forfixtmp");

                /* step が正の場合は　<= による比較となり、 負の場合は >= による比較となる。
                 * これは実際には forfixL, forfixR の値を入れ替えることで対応する。（比較の条件式をどちらのケースでも共用できるように）
                 * したがって、”step が負の場合に forfixL, forfixR を入れ替える命令”をここに書く。
                 */
                pA("if (forfixtmp < 0) {forfixtmp = forfixL; forfixL = forfixR; forfixR = forfixtmp;}");

                /* これら forfixL, forfixR を比較し分岐する命令を書く。
                 * （真の場合の分岐は、そのまま以降の declaration_list となる）
                 */
                pA("if (forfixL <= forfixR) {");

        } declaration_list __STATE_NEXT {
                /* ここは真の場合の命令の続きで、declaration_list の本体が終了した時点 */

                /* ここでスカラー変数の値を step によってインクリメントする。
                 * まずは step の値をポップして取得し forfixR へと退避し、
                 * 次に、スカラー変数の値を取得して forfixL へと退避し、
                 * これら forfixL, forfixR を加算し、結果をスカラー変数へ再び代入する。
                 */
                pop_stack_direct("forfixR");

                /* このセクションはスカラー変数の読み込みなので、read_variable とスカラー版とほぼ同様
                 */

                /* スカラーなので読み込みオフセットは 0 */
                pA("heap_offset = 0;");

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 * このアタッチは以降も使うので、ポップ直後にプッシュしておく
                 */
                pop_attachstack_direct("attachstack_socket");
                push_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", $<varptr>3->base_ptr);

                /* 結果をforfixLにセットする */
                read_heap_inline_direct("forfixL");

                /* インクリメントして、その結果をスカラー変数へ代入する
                 */
                pA("heap_socket = forfixL + forfixR;");

                pA("heap_offset = 0;");

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 * このアタッチは以降も使うので、ポップ直後にプッシュしておく
                 */
                pop_attachstack_direct("attachstack_socket");
                push_attachstack_direct("attachstack_socket");
                pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} "
                   "else {heap_base = %d;}", $<varptr>3->base_ptr);

                write_heap_inline_direct("heap_socket");

                /* その後、先頭で作成したラベル位置へと再び戻るために、 goto させる命令を書く。
                 * これには $<ival>6 により示されるラベル位置を用いる。
                 * そして、真の場合の命令はここまでとなり、以降は偽の場合の命令となる
                 */
                pA("PLIMM(P3F, %d);\n", $<ival>6);
                pA("} else {");

                /* 偽の場合は、アタッチスタックとスタックをポップして（step等を捨てるため）して、そのまま終わる */
                pop_stack_direct("stack_socket");
                pop_attachstack_direct("attachstack_socket");
                pA("}");
        }
        ;

define_label
        : __DEFINE_LABEL {
                pA("LB(1, %d);\n", labellist_search($1));
        }
        ;

jump
        : __OPE_GOTO __LABEL {
                pA("PLIMM(P3F, %d);\n", labellist_search($2));
        }
        | __OPE_GOSUB __LABEL {
                /* まず最初に、リターン先ラベルを CUR_RETURN_LABEL にセットする命令を作成し、
                 * その CUR_RETURN_LABEL の内容をラベルスタックへプッシュし、
                 * 次に、普通に __LABEL へと goto する命令を作成する
                 */
                pA("PLIMM(%s, %d);\n", CUR_RETURN_LABEL, cur_label_index_head);
                pA(push_labelstack);
                pA("PLIMM(P3F, %d);\n", labellist_search($2));

                /* そして、実際に戻り位置としてのラベル（無名ラベル）をここに作成し、
                 * そして、ラベルを作成したので cur_label_index_head を一つ進める
                 */
                pA("LB(1, %d);\n", cur_label_index_head);
                cur_label_index_head++;
        }
        | __OPE_RETURN {
                /* 戻り先ラベルがラベルスタックに保存されてる前提で、 そこからポップし（その値は CUR_RETURN_LABEL 入る）
                 * その CUR_RETURN_LABEL が指すラベル位置へと goto する。
                 * すなわち、gosub 先で、さらに gosub しても、戻りアドレスはラベルスタックへ詰まれるので、
                 * gosub 先で、さらに再帰的に gosub することが可能。
                 */
                pA(pop_labelstack);
                pA("PCP(P3F, %s);\n", CUR_RETURN_LABEL);
        }
        | __OPE_ON expression __OPE_GOTO __LABEL {
                pop_stack_direct("stack_socket");
                pA("if (stack_socket == 0x00010000) {");

                /* goto と同様（$4が違うだけ）*/
                pA("PLIMM(P3F, %d);\n", labellist_search($4));

                pA("}");
        }
        | __OPE_ON expression __OPE_GOSUB __LABEL {
                pop_stack_direct("stack_socket");
                pA("if (stack_socket == 0x00010000) {");

                /* gosub と同様（$4が違うだけ）*/
                pA("PLIMM(%s, %d);\n", CUR_RETURN_LABEL, cur_label_index_head);
                pA(push_labelstack);
                pA("PLIMM(P3F, %d);\n", labellist_search($4));
                pA("LB(1, %d);\n", cur_label_index_head);
                cur_label_index_head++;

                pA("}");
        }
        ;

identifier_list
        : {
                $$ = 0;
        }
        | __IDENTIFIER {
                idenlist_push($1);
                $$ = 1;
        }
        | __IDENTIFIER __OPE_COMMA identifier_list {
                idenlist_push($1);
                $$ = 1 + $3;
        }
        ;

define_function
        : __STATE_FUNCTION __IDENTIFIER __LB identifier_list __RB __BLOCK_LB {
                const int32_t skip_label = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = skip_label;

                __define_user_function_begin($2, $4, skip_label);

        } declaration_list __BLOCK_RB {
                __define_user_function_end($2, $<ival>7);
        }
        ;

%%
