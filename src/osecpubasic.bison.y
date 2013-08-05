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

void yyerror(const char *s) {printf("%s\n",s); exit(EXIT_FAILURE);}

extern FILE* yyin;
extern FILE* yyout;
FILE* yyaskA;

/* 出力ファイル yyaskA へ文字列を書き出す関数 */
static void pA(const char* fmt, ...)
{
        va_list ap;
        va_start(ap, fmt);

        vfprintf(yyaskA, fmt, ap);
        va_end(ap);

        fputs("\n", yyaskA);
}

#define VAR_STR_LEN 0x100
struct Var {
        char str[VAR_STR_LEN];
        int32_t head_ptr;
        int32_t array_len;
};

#define VARLIST_LEN 0x1000
static struct Var varlist[VARLIST_LEN];

/* 変数リストに既に同名が登録されているかを確認する。
 * もし登録されていればその構造体アドレスを返す。無ければNULLを返す。
 */
static struct Var* varlist_search(const char* str)
{
        int i;
        for (i = 0; i < VARLIST_LEN; i++) {
                if (strcmp(str, varlist[i].str) == 0)
                        return &(varlist[i]);
        }

        return NULL;
}

/* 変数リストに新たに変数を追加する。
 * 既に同名の変数が存在した場合は何もしない。
 * array_len : この変数の配列サイズを指定する。スカラーならば 1 とすべき。 この値はint32型。（fix32型では”ない”ので注意）
 */
static void varlist_add(const char* str, const int32_t array_len)
{
        if (varlist_search(str) != NULL)
                return;

        int32_t cur_head_ptr = 0;
        int i;
        for (i = 0; i < VARLIST_LEN; i++) {
                if (varlist[i].str[0] == '\0') {
                        strcpy(varlist[i].str, str);
                        varlist[i].head_ptr = cur_head_ptr;
                        varlist[i].array_len = array_len;

                        return;
                }

                cur_head_ptr = varlist[i].head_ptr + varlist[i].array_len;
        }
}

/* ヒープメモリー上の、identifier に割り当てられた領域内の任意オフセット位置へfix32型を書き込む。
 * 事前に以下のレジスタに値をセットしておくこと:
 * heap_socket : ヒープに書き込みたい値。fix32型単位なので注意。
 * heap_offset : identifier に割り当てられた領域中でのインデックス。fix32型単位なので注意。
 */
static void write_heap(char* dst, char* iden)
{
        struct Var* v = varlist_search(iden);
        if (v == NULL) {
                printf("syntax err: identifier が未定義の変数に書き込もうとしました\n");
                exit(EXIT_FAILURE);
        }

        sprintf(dst, "heap_seek = %d;\n"
                     "heap_offset >>= 16;\n"
                     "heap_offset &= 0x0000ffff;\n"
                     "heap_seek += heap_offset;\n"
                     "PASMEM0(heap_socket, T_SINT32, heap_ptr, heap_seek);\n",
                     v->head_ptr);
}

/* ヒープメモリー上の、identifier に割り当てられた領域内の任意オフセット位置からfix32型を読み込む。
 * 事前に以下のレジスタに値をセットしておくこと:
 * heap_offset : identifier に割り当てられた領域中でのインデックス。fix32型単位なので注意。
 *
 * 読み込んだ値は heap_socket へ格納される。これはfix32型なので注意。
 */
static void read_heap(char* dst, char* iden)
{
        struct Var* v = varlist_search(iden);
        if (v == NULL) {
                printf("syntax err: identifier が未定義の変数から読み込もうとしました\n");
                exit(EXIT_FAILURE);
        }

        sprintf(dst, "heap_seek = %d;\n"
                     "heap_offset >>= 16;\n"
                     "heap_offset &= 0x0000ffff;\n"
                     "heap_seek += heap_offset;\n"
                     "PALMEM0(heap_socket, T_SINT32, heap_ptr, heap_seek);\n",
                     v->head_ptr);
}

/* ヒープメモリーの初期化
 */
static char init_heap[] = {
        "VPtr heap_ptr:P12;\n"
        "junkApi_malloc(heap_ptr, T_SINT32, 0x100000);\n"
        "SInt32 heap_socket:R12;\n"
        "SInt32 heap_seek:R13;\n"
        "SInt32 heap_offset:R14;\n"
        "heap_seek = 0;\n"
};

/* スタックにint32型（またはfix32型）をプッシュする
 * 事前に以下のレジスタをセットしておくこと:
 * stack_socket : プッシュしたい値。（int32型）
 */
#define __PUSH_STACK                                                    \
        "PASMEM0(stack_socket, T_SINT32, stack_ptr, stack_head);\n"     \
        "stack_head++;\n"

static char push_stack[] = {
        __PUSH_STACK
};

/* スタックからint32型（またはfix32型）をポップする
 * ポップした値は stack_socket に格納される。
 */
#define __POP_STACK                                                     \
        "stack_head--;\n"                                               \
        "PALMEM0(stack_socket, T_SINT32, stack_ptr, stack_head);\n"

static char pop_stack[] = {
        __POP_STACK
};

/* スタックの初期化
 */
static char init_stack[] = {
        "VPtr stack_ptr:P10;\n"
        "junkApi_malloc(stack_ptr, T_SINT32, 0x100000);\n"
        "SInt32 stack_socket:R10;\n"
        "SInt32 stack_head:R11;\n"
        "stack_head = 0;\n"
};

/* <expression> <OPE_?> <expression> の状態から、左右の <expression> の値をそれぞれ fixL, fixR へ読み込む
 */
static char read_eoe_arg[] = {
        __POP_STACK
        "fixR = stack_socket;"
        __POP_STACK
        "fixL = stack_socket;"
};

/* eoe用レジスタをスタックへプッシュする
 */
static char push_eoe[] = {
        "stack_socket = fixL;\n"  __PUSH_STACK
        "stack_socket = fixR;\n"  __PUSH_STACK
        "stack_socket = fixLx;\n" __PUSH_STACK
        "stack_socket = fixRx;\n" __PUSH_STACK
        "stack_socket = fixT;\n"  __PUSH_STACK
        "stack_socket = fixS;\n"  __PUSH_STACK
};

/* eoe用レジスタをスタックからポップする
 */
static char pop_eoe[] = {
        __POP_STACK "fixS  = stack_socket;\n"
        __POP_STACK "fixT  = stack_socket;\n"
        __POP_STACK "fixRx = stack_socket;\n"
        __POP_STACK "fixLx = stack_socket;\n"
        __POP_STACK "fixR  = stack_socket;\n"
        __POP_STACK "fixL  = stack_socket;\n"
};

static char debug_eoe[] = {
        "junkApi_putConstString('\\nfixR:');"
        "junkApi_putStringDec('\\1', fixR, 10, 1);"
        "junkApi_putConstString(' fixL:');"
        "junkApi_putStringDec('\\1', fixL, 10, 1);"
        "junkApi_putConstString(' fixRx:');"
        "junkApi_putStringDec('\\1', fixRx, 10, 1);"
        "junkApi_putConstString(' fixLx:');"
        "junkApi_putStringDec('\\1', fixLx, 10, 1);"
        "junkApi_putConstString(' fixT:');"
        "junkApi_putStringDec('\\1', fixT, 10, 1);"
        "junkApi_putConstString(' fixS:');"
        "junkApi_putStringDec('\\1', fixS, 10, 1);"
        "junkApi_putConstString(' fixA:');"
        "junkApi_putStringDec('\\1', fixA, 10, 1);"
        "junkApi_putConstString('\\n');"
};

/* read_eoe_arg 用変数の初期化
 *
 * push_eoe, pop_eoe ともに、例外として fixA スタックへ退避しない。
 * この fixA は eoe 間で値を受け渡しする為に用いるので、push_eoe, pop_eoe に影響されないようにしてある。
 * （push後に行った演算の結果をfixAに入れておくことで、その後にpopした後でも演算結果を引き継げるように）
 */
static char init_eoe_arg[] = {
        "SInt32 fixL:R20;"
        "SInt32 fixR:R21;"
        "SInt32 fixLx:R22;"
        "SInt32 fixRx:R23;"
        "SInt32 fixT:R27;"
        "SInt32 fixS:R28;"
        "SInt32 fixA:R29;"
};

/* 現在の使用可能なラベルインデックスのヘッド
 * この値から LABEL_INDEX_LEN 未満までの間が、まだ未使用なユニークラベルのサフィックス番号。
 * ユニークラベルをどこかに設定する度に、この値をインクリメントすること。
 */
static int32_t cur_label_index_head = 0;

/* ラベルの仕様可能最大数 */
#define LABEL_INDEX_LEN 1024
#define LABEL_INDEX_LEN_STR "1024"

#define LABEL_STR_LEN 0x100
struct Label {
        char str[LABEL_STR_LEN];
        int32_t val;
};

static struct Label labellist[LABEL_INDEX_LEN];

/* ラベルリストに既に同名が登録されているかを確認し、そのラベルのLOCAL(x)のxに相当する値を得る。
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

/* ラベルリストに既に同名が登録されているかを確認し、そのラベルのLOCAL(x)のxに相当する値を得る。
 * 無ければエラー出力して終了
 */
static int32_t labellist_search(const char* str)
{
        const int32_t tmp = labellist_search_unsafe(str);
        if (tmp == -1) {
                printf("system err: ラベルが見つかりません\n");
                exit(EXIT_FAILURE);
        }

        return tmp;
}

/* ラベルリストに新たにラベルを追加し、LOCAL(x)のxに相当する値を結びつける。
 * これは名前と、LOCAL(x)のxに相当する値とを結びつけた連想配列。
 * 既に同名の変数が存在した場合はエラー終了する。
 */
void labellist_add(const char* str)
{
        if (labellist_search_unsafe(str) != -1) {
                printf("syntax err: 既に同名のラベルが存在します\n");
                exit(EXIT_FAILURE);
        }

        if (cur_label_index_head >= LABEL_INDEX_LEN) {
                printf("system err: コンパイラーが設定可能なラベルの数を越えました。\n");
                exit(EXIT_FAILURE);
        }

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
#define CUR_RETURN_LABEL "P11"

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
        "VPtr labelstack_ptr:P14;\n"
        "junkApi_malloc(labelstack_ptr, T_VPTR, " LABEL_INDEX_LEN_STR ");\n"
        "VPtr labelstack_socket:" CUR_RETURN_LABEL ";\n"
        "SInt32 labelstack_head:R15;\n"
        "labelstack_head = 0;\n"
};

/* 全ての初期化
 */
void init_all(void)
{
        pA("#include \"osecpu_ask.h\"\n");

        pA("LOCALLABELS(%d);\n", LABEL_INDEX_LEN);

        pA("SInt32 tmp0:R08;");
        pA("SInt32 tmp1:R09;\n");

        /* forループ処理の作業用 */
        pA("SInt32 forfixL: R24;");
        pA("SInt32 forfixR: R25;");
        pA("SInt32 forfixtmp: R26;\n");

        pA(init_heap);
        pA(init_stack);
        pA(init_labelstack);
        pA(init_eoe_arg);
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
static void __func_mul(void)
{
        /* 符号を保存しておき、+へ変換する*/
        pA("fixS = 0;");
        pA("if (fixL < 0) {fixL = -fixL; fixS |= 1;}");
        pA("if (fixR < 0) {fixR = -fixR; fixS |= 2;}");

        /* L * R -> T */

        pA("fixA = 0;");

#if 1
        /* R.Decimal * L -> L.Decimal */

        /* R.Decimal * L.Decimal -> T.Decimal */
        pA("fixRx = fixR & 0x0000ffff;");
        pA("fixLx = fixL & 0x0000ffff;");
        pA("fixT = fixLx * fixRx;");
        pA("fixT >>= 16;");
        pA("fixA += fixT;");

        /* R.Decimal * L.Integer -> T.Integer */
        pA("fixRx = fixR & 0x0000ffff;");
        pA("fixLx = fixL & 0xffff0000;");
        pA("fixLx >>= 16;");
        pA("fixT = fixLx * fixRx;");
        pA("fixA += fixT;");
#endif

#if 1
        /* R.Integer * L -> L.Integer */

        /* R.Integer * L.Decimal -> T.Decimal */
        pA("fixRx = fixR & 0xffff0000;");
        pA("fixLx = fixL & 0x0000ffff;");
        pA("fixRx >>= 16;");
        pA("fixT = fixLx * fixRx;");
        pA("fixA += fixT;");

        /* R.Integer * L.Integer -> T.Integer */
        pA("fixRx = fixR & 0xffff0000;");
        pA("fixLx = fixL & 0xffff0000;");
        pA("fixRx >>= 16;");
        pA("fixT = fixLx * fixRx;");
        pA("fixA += fixT;");
#endif

        /* 符号を元に戻す */
        pA("if ((fixS &= 0x00000003) == 0x00000001) {fixA = -fixA;}");
        pA("if ((fixS &= 0x00000003) == 0x00000002) {fixA = -fixA;}");
}

/* 除算命令を出力する
 * fixL / fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_div(void)
{
        /* R の逆数を得る
         *
         * （通常は 0x00010000 を 1 と考えるが、）
         * 0x40000000 を 1 と考えると、通常との差は << 14 なので、
         * 0x40000000 / R の結果も << 14 に対する演算結果として得られ、
         * （除算の場合は単位分 >> するので（すなわち >> 16））、
         * したがって結果を << 2 すれば（16 - 14 = 2だから） 0x00010000 を 1 とした場合での値となるはず。
         */
        pA("fixRx = 0x40000000 / fixR;");
        pA("fixR = fixRx << 2;");

        /* 他アキュムレーターを呼び出す前に eoe を退避しておく */
        pA(push_eoe);

        /* 逆数を乗算することで除算とする */
        __func_mul();

        /* eoe を復帰（スタックを掃除するため） */
        pA(pop_eoe);
}

/* 符号付き剰余命令を出力する
 * fixL mod fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_mod(void)
{
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
        pA("fixT = fixL / fixR;");
        /* floor */
        pA("if (fixT < 0) {fixT -= 1;}");
        pA("fixRx = fixT * fixR;");
        pA("fixA = fixL - fixRx;");
        pA("}");
}

/* powのバックエンドに用いる sqrt 命令を出力する
 * fixL, fixR -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * nr x (xn - (xn ^ p - x) / (p * xn ^ (p - 1))
 *    L  R     R * R    L     2    R     ---
 */

static void __func_sqrt(void)
{
        /* fixL, fixT -> fixT */
        void __func_sqrt_nr(void)
        {
                pA(push_eoe);
                pA("fixL = fixR;");
                __func_mul();
                pA(pop_eoe);
                pA("fixLx = fixA;");
                pA("fixLx -= fixL;");

                pA(push_eoe);
                pA("fixL = 0x00020000;");
                __func_mul();
                pA(pop_eoe);
                pA("fixRx = fixA;");

                pA(push_eoe);
                pA("fixL = fixLx;");
                pA("fixR = fixRx;");
                __func_div();
                pA(pop_eoe);

                pA("fixA = fixR - fixA;");
        }

        pA(push_eoe);
        pA("fixR = 0x00020000;");
        __func_div();
        pA(pop_eoe);

        pA("fixR = fixA;");
        __func_sqrt_nr();

        pA("fixR = fixA;");
        __func_sqrt_nr();

        pA("fixR = fixA;");
        __func_sqrt_nr();

        pA("fixR = fixA;");
        __func_sqrt_nr();

        pA("fixR = fixA;");
        __func_sqrt_nr();
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

/* 符号反転命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_minus(void)
{
        pA("fixA = -fixL;");
}

/* 以下、各種プリセット関数 */

/* 文字列出力命令を出力する
 * fixL -> null
 * 予め fixL に値をセットしておくこと。 演算結果は存在しない。
 */
static void __func_print(void)
{
        /* 整数側の表示 */

        pA("fixLx = fixL >> 16;");
        pA("if (fixLx < 0) {fixLx += 1;}");

        /* 整数部が0の負の数の場合は、junkApi_putStringDec()に0として処理させるので符号が付かない。
         * 従って、その場合は手動で符号を付ける必要がある
         */
        pA("if (fixL < 0) {if (fixLx == 0) {junkApi_putConstString('-');}}");

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

        pA("if (fixL < 0) {fixR = 10000 - fixR;}");
        pA("junkApi_putStringDec('\\1', fixR, 4, 6);\n");

        /* 自動改行はさせない （最後にスペースを表示するのみ） */
        pA("junkApi_putConstString(' ');");
}

%}

%union {
        int32_t ival;
        float fval;
        char sval[0x1000];
}

%token __STATE_IF __STATE_THEN __STATE_ELSE
%token __STATE_FOR __STATE_TO __STATE_STEP __STATE_NEXT __STATE_END
%token __STATE_READ __STATE_DATA __STATE_MAT __OPE_ON __OPE_GOTO __OPE_GOSUB __OPE_RETURN
%token __STATE_LET __OPE_SUBST
%token __FUNC_PRINT __FUNC_INPUT __FUNC_PEEK __FUNC_POKE __FUNC_CHR_S __FUNC_VAL __FUNC_MID_S __FUNC_RND __FUNC_INPUT_S
%left  __OPE_COMPARISON __OPE_NOT_COMPARISON __OPE_ISSMALL __OPE_ISSMALL_COMP __OPE_ISLARGE __OPE_ISLARGE_COMP
%left  __OPE_ADD __OPE_SUB
%left  __OPE_MUL __OPE_DIV __OPE_MOD __OPE_POWER
%left  __OPE_OR __OPE_AND __OPE_XOR __OPE_NOT
%token __OPE_PLUS __OPE_MINUS
%token __LB __RB __DECL_END __IDENTIFIER __LABEL __DEFINE_LABEL __EOF
%token __CONST_STRING __CONST_FLOAT __CONST_INTEGER

%type <ival> __CONST_INTEGER
%type <fval> __CONST_FLOAT
%type <sval> __CONST_STRING __IDENTIFIER __LABEL __DEFINE_LABEL

%type <sval> func_print
%type <sval> operation const_variable read_variable
%type <sval> selection_if selection_if_v selection_if_t selection_if_e
%type <sval> iterator_for initializer expression assignment jump define_label function
%type <sval> syntax_tree declaration_list declaration

%start syntax_tree

%%

syntax_tree
        : declaration_list __EOF {
                YYACCEPT;
        }
        ;

declaration_list
        : declaration
        | declaration declaration_list
        ;

declaration
        : initializer __DECL_END
        | assignment __DECL_END
        | expression __DECL_END
        | selection_if
        | iterator_for
        | jump __DECL_END
        | define_label __DECL_END
        | __DECL_END
        ;

expression
        : operation
        | const_variable
        | read_variable
        | comparison
        | function
        ;

function
        : func_print
        | __FUNC_INPUT {}
        | __FUNC_PEEK {}
        | __FUNC_POKE expression {}
        | __FUNC_CHR_S expression {}
        | __FUNC_VAL expression {}
        | __FUNC_MID_S expression {}
        | __FUNC_RND {}
        | __FUNC_INPUT_S {}
        | __FUNC_PEEK expression {}
        ;

func_print
        : __FUNC_PRINT expression {
                pA(pop_stack);
                pA("fixL = stack_socket;");
                __func_print();
        }
        ;

initializer
        : __STATE_LET __IDENTIFIER {
                varlist_add($2, 1);
        }
        | __STATE_LET __IDENTIFIER __LB __CONST_INTEGER __RB {
                varlist_add($2, $4);
        }
        ;

assignment
        : __IDENTIFIER __OPE_SUBST expression {
                pA(pop_stack);
                pA("heap_socket = stack_socket;");

                pA("heap_offset = 0;");

                char tmp[0x1000];
                write_heap(tmp, $1);
                pA(tmp);
        }
        | __IDENTIFIER __LB expression __RB __OPE_SUBST expression {
                pA(pop_stack);
                pA("heap_socket = stack_socket;");

                pA(pop_stack);
                pA("heap_offset = stack_socket;");

                char tmp[0x1000];
                write_heap(tmp, $1);
                pA(tmp);
        }
        ;

const_variable
        : __CONST_STRING
        | __CONST_FLOAT {
                double a;
                double b = modf($1, &a);
                int32_t ia = ((int32_t)a) << 16;
                int32_t ib = ((int32_t)(0x0000ffff * b)) & 0x0000ffff;

                pA("stack_socket = %d;\n", ia | ib);
                pA(push_stack);
        }
        | __CONST_INTEGER {
                pA("stack_socket = %d;\n", $1 << 16);
                pA(push_stack);
        }
        ;

operation
        : expression __OPE_ADD expression {
                pA(read_eoe_arg);
                __func_add();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_SUB expression {
                pA(read_eoe_arg);
                __func_sub();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_MUL expression {
                pA(read_eoe_arg);
                __func_mul();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_DIV expression {
                pA(read_eoe_arg);
                __func_div();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_POWER expression {}
        | expression __OPE_MOD expression {
                pA(read_eoe_arg);
                __func_mod();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_OR expression {
                pA(read_eoe_arg);
                __func_or();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_AND expression {
                pA(read_eoe_arg);
                __func_and();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | expression __OPE_XOR expression {
                pA(read_eoe_arg);
                __func_xor();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | __OPE_NOT expression {
                pA(pop_stack);
                pA("fixL = stack_socket;");
                __func_not();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | __OPE_ADD expression %prec __OPE_PLUS {
                /* 何もしない */
        }
        | __OPE_SUB expression %prec __OPE_MINUS {
                pA(pop_stack);
                pA("fixL = stack_socket;");
                __func_minus();
                pA("stack_socket = fixA;");
                pA(push_stack);
        }
        | __LB expression __RB {
                /* 何もしない */
        }
        ;

comparison
        : expression __OPE_COMPARISON expression {
                pA(read_eoe_arg);

                pA("if (fixL == fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                pA(push_stack);
        }
        | expression __OPE_NOT_COMPARISON expression {
                pA(read_eoe_arg);

                pA("if (fixL != fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                pA(push_stack);
        }
        | expression __OPE_ISSMALL expression {
                pA(read_eoe_arg);

                pA("if (fixL < fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                pA(push_stack);
        }
        | expression __OPE_ISSMALL_COMP expression {
                pA(read_eoe_arg);

                pA("if (fixL <= fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                pA(push_stack);
        }
        | expression __OPE_ISLARGE expression {
                pA(read_eoe_arg);

                pA("if (fixL > fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                pA(push_stack);
        }
        | expression __OPE_ISLARGE_COMP expression {
                pA(read_eoe_arg);

                pA("if (fixL >= fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                pA(push_stack);
        }
        ;

read_variable
        : __IDENTIFIER {
                pA("heap_offset = 0;");

                char tmp[0x1000];
                read_heap(tmp, $1);
                pA(tmp);

                pA("stack_socket = heap_socket;");
                pA(push_stack);
        }
        | __IDENTIFIER __LB expression __RB {
                pA(pop_stack);
                pA("heap_offset = stack_socket;");

                char tmp[0x1000];
                read_heap(tmp, $1);
                pA(tmp);

                pA("stack_socket = heap_socket;");
                pA(push_stack);
        }
        ;

selection_if
        : selection_if_v selection_if_t selection_if_e
        | selection_if_v selection_if_t {
                putchar('\n');
        }
        ;

selection_if_v
        : __STATE_IF expression {
                pA(pop_stack);
                pA("if (stack_socket == 0x00010000) {");
        }
        ;

selection_if_t
        : __STATE_THEN declaration {
                putchar('}');
        }

selection_if_e
        : __STATE_ELSE {
                pA(" else {");
        } declaration {
                pA("}");
        }
        ;

iterator_for
        : __STATE_FOR __IDENTIFIER __OPE_SUBST expression {
                /* このセクションはスカラー変数への代入なので、 assignment のスカラー版と同様
                 * （$2が違うだけ）
                 */
                pA(pop_stack);
                pA("heap_socket = stack_socket;");

                pA("heap_offset = 0;");

                char tmp[0x1000];
                write_heap(tmp, $2);
                pA(tmp);

                /* そして、代入後であるここに無名ラベルを作る（このforループは、以降はこの位置へと戻ってくる）
                 * また、このラベルは next で戻ってくる際に使うので、この構文解析器で参照できるように $$ で出力する。（以降$5で参照できる）
                 * この $5 ラベル番号で int32 型の値である。
                 * そして、ラベルを作成したので cur_label_index_head を一つ進める。
                 */
                pA("LB(0, %d);\n", cur_label_index_head);
                $<ival>$ = cur_label_index_head;
                cur_label_index_head++;
        } __STATE_TO expression {
                /* 条件を比較するために
                 * まずスタックに詰まれてる __STATE_TO expression (の戻り値)を得て、 forfixR（右辺用） へと退避しておく。
                 * （また、このポップは、変数を読む際に余分なスタックが残っていないように、スタックを掃除しておく意味も兼ねる）
                 */
                pA(pop_stack);
                pA("forfixR = stack_socket;");

                /* 次にスカラー変数から値を読み、 forfixL （左辺用） へと退避しておく。
                 */
                pA("heap_offset = 0;");

                char tmp[0x1000];
                read_heap(tmp, $2);
                pA(tmp);

                pA("forfixL = heap_socket;");
        } __STATE_STEP expression {
                /* 条件比較の方向を判断するために、stepの値を読む必要がある
                 * そして、最後の next の時点でインクリメントに使用するのに備えて、再びプッシュしておく
                 */
                pA(pop_stack);
                pA("forfixtmp = stack_socket;");
                pA(push_stack);

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
                pA(pop_stack);
                pA("forfixR = stack_socket;");

                /* このセクションはスカラー変数の読み込みなので、read_variable とスカラー版とほぼ同様
                 */
                pA("heap_offset = 0;");
                char tmp[0x1000];
                read_heap(tmp, $2);
                pA(tmp);
                pA("forfixL = heap_socket;");

                /* インクリメントして、その結果をスカラー変数へ代入する
                 */
                pA("heap_socket = forfixL + forfixR;");

                pA("heap_offset = 0;");
                write_heap(tmp, $2);
                pA(tmp);

                /* その後、先頭で作成したラベル位置へと再び戻るために、 goto させる命令を書く。
                 * これには $5 により示されるラベル位置を用いる。
                 * そして、真の場合の命令はここまでとなり、以降は偽の場合の命令となる
                 */
                pA("PLIMM(P3F, %d);\n", $<ival>5);
                pA("} else {");

                /* 偽の場合は、スタックをポップ（stepを捨てるため）して、そのまま終わる */
                pA(pop_stack);
                pA("}");
        }
        ;

define_label
        : __DEFINE_LABEL {
                pA("LB(0, %d);\n", labellist_search($1));
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
                pA("LB(0, %d);\n", cur_label_index_head);
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
                pA(pop_stack);
                pA("if (stack_socket == 0x00010000) {");

                /* goto と同様（$4が違うだけ）*/
                pA("PLIMM(P3F, %d);\n", labellist_search($4));

                pA("}");
        }
        | __OPE_ON expression __OPE_GOSUB __LABEL {
                pA(pop_stack);
                pA("if (stack_socket == 0x00010000) {");

                /* gosub と同様（$4が違うだけ）*/
                pA("PLIMM(%s, %d);\n", CUR_RETURN_LABEL, cur_label_index_head);
                pA(push_labelstack);
                pA("PLIMM(P3F, %d);\n", labellist_search($4));
                pA("LB(0, %d);\n", cur_label_index_head);
                cur_label_index_head++;

                pA("}");
        }
        ;

%%
