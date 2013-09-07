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

/* 変数型の識別フラグのルール関連
 */

/* 型指定子
 */
#define TYPE_VOID       (1 << 0)
#define TYPE_CHAR       (1 << 1)
#define TYPE_INT        (1 << 2)
#define TYPE_SHORT      (1 << 3)
#define TYPE_LONG       (1 << 4)
#define TYPE_FLOAT      (1 << 5)
#define TYPE_DOUBLE     (1 << 6)
#define TYPE_SIGNED     (1 << 7)
#define TYPE_UNSIGNED   (1 << 8)
#define TYPE_STRUCT     (1 << 9)
#define TYPE_ENUM       (1 << 10)

/* 型ルール
 */
#define TYPE_CONST      (1 << 20)
#define TYPE_VOLATILE   (1 << 21)

/* 記憶領域クラス
 */
#define TYPE_AUTO       (1 << 24)
#define TYPE_REGISTER   (1 << 25)
#define TYPE_STATIC     (1 << 26)
#define TYPE_EXTERN     (1 << 27)
#define TYPE_TYPEDEF    (1 << 28)

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

/* プログラムフローにおける現時点でのスコープの深さ
 * ローカルが深まる毎に +1 されて、浅くなる毎に -1 される前提。
 * スコープが最も浅い場合はグローバルで、これは 0 となる。
 *
 * コンパイラーを書く上において、この値を各所で適切に設定する責任はプログラマーに委ねられる。（自動的には行われない）
 *
 * この値が 0 か 非0 かに伴い、スコープがグローバル時での変数定義の動作を変えるために用いる。
 * 0 ならば変数はヒープから確保し、 非0 ならば変数はスタック上に確保する際に、この値を参考に分岐させるのに用いる。
 */
static int32_t cur_scope_depth = 0;

/* プログラムフローにおける現時点でのスコープの深さを1段進める */
static void inc_cur_scope_depth(void)
{
        cur_scope_depth++;
}

/* プログラムフローにおける現時点でのスコープの深さを1段戻す */
static void dec_cur_scope_depth(void)
{
        cur_scope_depth--;
        if (cur_scope_depth < 0)
                yyerror("system err: dec_cur_scope_depth();");
}

/* 構造体スペックリスト関連
 */

/* 構造体メンバースペック
 */
struct StructMemberSpec {
        char* name;             /* メンバー変数の名前 */
        int32_t array_len;      /* メンバー変数全体の長さ */
        int32_t col_len;        /* 行の長さ */
        int32_t row_len;        /* 列の長さ */
};

/* 構造体メンバースペックの内容を一覧表示する。
 * 主にデバッグ用。
 * tab は字下げインデント用の文字列。
 */
static void structmemberspec_print(struct StructMemberSpec* member,
                                   const char* tab)
{
        printf("%sStructMemberSpec: name[%s], array_len[%d], col_len[%d], row_len[%d]\n",
               tab, member->name, member->array_len, member->col_len, member->row_len);
}

/* 構造体メンバースペックに値をセットする
 */
static void structmemberspec_set(struct StructMemberSpec* member,
                                 const char* iden,
                                 const int32_t col_len,
                                 const int32_t row_len)
{
        if (iden == NULL)
                yyerror("system err: structmemberspec_set(), iden == null");

        if (iden[0] == '\0')
                yyerror("system err: structmemberspec_set(), iden[0] == 0");

        if (row_len <= 0)
                yyerror("syntax err: 構造体メンバーの配列の行（たて方向、y方向）サイズに0を指定しました");

        if (col_len <= 0)
                yyerror("syntax err: 構造体メンバーの配列の列（よこ方向、x方向）サイズに0を指定しました");

        member->name = malloc(sizeof(*member->name));
        strcpy(member->name, iden);

        member->col_len = col_len;
        member->row_len = row_len;
        member->array_len = col_len * row_len;

#ifdef DEBUG_STRUCTMEMBERSPEC
        printf("structmemberspec: name[%s], array_len[%d], col_len[%d], row_len[%d]\n",
               member->name, member->array_len, member->col_len, member->row_len);
#endif /* DEBUG_STRUCTMEMBERSPEC */
}

/* 構造体メンバースペックのメモリー領域を確保し、値をセットし、アドレスを返す
 */
static struct StructMemberSpec* structmemberspec_new(const char* iden,
                                                     const int32_t col_len,
                                                     const int32_t row_len)
{
        struct StructMemberSpec* member = malloc(sizeof(*member));
        structmemberspec_set(member, iden, col_len, row_len);
        return member;
}

/* 構造体のスペック
 */

/* 構造体が持てるメンバー数の上限 */
#define STRUCTLIST_MEMBER_MAX 0x100

struct StructSpec {
        char* name;             /* 構造体の名前 */
        int32_t struct_len;     /* 構造体全体の長さ */

        /* 各メンバー変数スペックへのポインターのリスト */
        struct StructMemberSpec* member_ptr[STRUCTLIST_MEMBER_MAX];

        /* 各メンバー変数のオフセット */
        int32_t member_offset[STRUCTLIST_MEMBER_MAX];

        int32_t member_len;     /* メンバー変数の個数 */
};

/* 構造体スペックの内容を一覧表示する。
 * 主にデバッグ用。
 * tab は字下げインデント用の文字列。
 */
static void structspec_print(struct StructSpec* spec, const char* tab)
{
        printf("%sStructSpec: name[%s], struct_len[%d], member_len[%d]\n",
               tab, spec->name, spec->struct_len, spec->member_len);

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

/* 構造体スペックに任意の名前のメンバーが登録されてるかを検索し、アドレスを返す。
 * 存在しなければ NULL を返す。
 */
static struct StructMemberSpec* structspec_search(struct StructSpec* spec,
                                                  const char* iden)
{
        int i = spec->member_len;
        while (i-->0) {
                struct StructMemberSpec* p = spec->member_ptr[i];
                if (strcmp(p->name, iden) == 0)
                        return p;
        }

        return NULL;
}

/* 構造体スペックに構造体メンバースペックを追加する
 */
static void structspec_add_member(struct StructSpec* spec,
                                  struct StructMemberSpec* member)
{
        /* 既に重複したメンバー名が登録されていた場合はエラー */
        if (structspec_search(spec, member->name) != NULL)
                yyerror("syntax err: 構造体のメンバー名が重複しています");

        spec->member_ptr[spec->member_len] = member;

        /* 構造体中での、メンバーのオフセット位置をセット。
         * 新規追加する構造体メンバーのオフセット位置は、その時点での構造体サイズとなる。
         */
        spec->member_offset[spec->member_len] = spec->struct_len;

        /* メンバーを追加したので、その分だけ増えた構造体サイズを更新する */
        spec->struct_len += member->array_len;

        /* メンバーを追加したので、構造体に含まれるメンバー個数を更新する */
        spec->member_len++;

#ifdef DEBUG_STRUCTSPEC
        printf("structspec: name[%s], struct_len[%d], member_len[%d]\n",
               spec->name, spec->struct_len, spec->member_len);
#endif /* DEBUG_STRUCTSPEC */
}

/* 無名の構造体スペックのメモリー領域を確保し、初期状態をセットして、アドレスを返す
 */
static struct StructSpec* structspec_new(void)
{
        struct StructSpec* spec = malloc(sizeof(*spec));
        spec->name = NULL;
        spec->struct_len = 0;
        spec->member_len = 0;

        return spec;
}

/* 無名の構造体スペックに名前をつける
 */
static void structspec_set_name(struct StructSpec* spec,
                                const char* iden)
{
        if (spec->name != NULL)
                yyerror("system err: structspec_set_name(), spec->name != NULL");

        spec->name = malloc(sizeof(iden) + 1);
        strcpy(spec->name, iden);

#ifdef DEBUG_STRUCTSPEC
        printf("structspec_set_name(): name[%s], struct_len[%d], member_len[%d]\n",
               spec->name, spec->struct_len, spec->member_len);
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
                if (strcmp(spec->name, iden) == 0)
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
        if (structspec_ptrlist_search(spec->name) != NULL)
                yyerror("syntax err: 構造体のメンバー名が重複しています");

        structspec_ptrlist[cur_structspec_ptrlist_head] = spec;
        cur_structspec_ptrlist_head++;

#ifdef DEBUG_STRUCTSPEC_PTRLIST
        structspec_ptrlist_print();
#endif /* DEBUG_STRUCTSPEC_PTRLIST */
}

/* 変数スペックリスト関連
 */

#define VAR_STR_LEN IDENLIST_STR_LEN
struct Var {
        char str[VAR_STR_LEN];
        int32_t base_ptr;       /* ベースアドレス */
        int32_t array_len;      /* 配列全体の長さ */
        int32_t col_len;        /* 行の長さ */
        int32_t row_len;        /* 列の長さ */
        int32_t is_local;       /* この変数がローカルならば非0、グローバルならば0となる */
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
        cur->is_local = (cur_scope_depth >= 1) ? 1 : 0;

        varlist_head++;

#ifdef DEBUG_VARLIST
        printf("col_len[%d], row_len[%d], array_len[%d], base_ptr[%d], is_local[%d]\n",
               cur->col_len, cur->row_len, cur->array_len, cur->base_ptr, cur->is_local);
#endif /* DEBUG_VARLIST */
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

/* 変数リストの現在の最後の変数を、新しいスコープの先頭とみなして、それの base_ptr に0をセットする
 *
 * 新しいスコープ内にて、新たにローカル変数 a, b, c を宣言する場合の例:
 * varlist_add_local("a", 1, 1); // とりあえず a を宣言する
 * varlist_set_scope_head(); // これでヒープの最後の変数である a の base_ptr へ 0 がセットされる
 * varlist_add_local("b", 1, 1); // その後 b, c は普通に宣言していけばいい
 * varlist_add_local("c", 1, 1);
 */
static void varlist_set_scope_head(void)
{
        if (varlist_head > 0) {
                struct Var* prev = varlist + varlist_head - 1;
                prev->base_ptr = 0;
        }
}

/* 低レベルなメモリー領域
 * これは単純なリード・ライトしか備えていない、システム中での最も低レベルなメモリー領域と、そのIOを提供する。
 * それらリード・ライトがどのような意味を持つかは、呼出側（高レベル側）が各自でルールを決めて運用する。
 *
 * 最終的には、システムで用いるメモリーは、全て、このメモリー領域を利用するように置き換えたい。
 */

#define MEM_SIZE (0x100000)

static void init_mem(void)
{
        pA("VPtr mem_ptr:P04;");
        pA("junkApi_malloc(mem_ptr, T_SINT32, %d);", MEM_SIZE);
}

static void write_mem(const char* regname_data,
                      const char* regname_address)
{
        pA("PASMEM0(%s, T_SINT32, mem_ptr, %s);", regname_data, regname_address);
}

static void read_mem(const char* regname_data,
                     const char* regname_address)
{
        pA("PALMEM0(%s, T_SINT32, mem_ptr, %s);", regname_data, regname_address);
}

/* スタック構造関連
 * これはプッシュ・ポップだけの単純なスタック構造を提供する。
 * 実際には mem の STACK_BEGIN_ADDRESS 以降のメモリー領域を用いる。
 */

#define STACK_BEGIN_ADDRESS (MEM_SIZE - 0x10000)

/* 任意のレジスターの値をスタックにプッシュする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
static void push_stack(const char* regname_data)
{
        write_mem(regname_data, "stack_head");
        pA("stack_head++;");

#ifdef DEBUG_STACK
        pA("junkApi_putConstString('push_stack(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 10, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_STACK */
}

/* スタックから任意のレジスターへ値をポップする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
static void pop_stack(const char* regname_data)
{
        pA("stack_head--;");
        read_mem(regname_data, "stack_head");

#ifdef DEBUG_STACK
        pA("junkApi_putConstString('pop_stack(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 10, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_STACK */
}

/* スタックへのダミープッシュ
 * 実際には値をメモリーへプッシュすることはしないが、ヘッド位置だけを動かす。
 * 実際にダミーデータを用いて push_stack() するよりも軽い。
 */
static void push_stack_dummy(void)
{
        pA("stack_head++;");
}

/* スタックからのダミーポップ
 * 実際には値をメモリーからポップすることはしないが、ヘッド位置だけを動かす。
 * 実際にダミーデータを用いて pop_stack() するよりも軽い。
 */
static void pop_stack_dummy(void)
{
        pA("stack_head--;");
}

/* スタックの初期化
 */
static void init_stack(void)
{
        pA("SInt32 stack_socket:R02;");
        pA("SInt32 stack_head:R03;");
        pA("SInt32 stack_frame:R12;");

        pA("stack_head = %d;", STACK_BEGIN_ADDRESS);
        pA("stack_frame = 0;");
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
#define CUR_RETURN_LABEL "P02"

/* ラベルスタックにラベル型（VPtr型）をプッシュする
 * 事前に以下のレジスタをセットしておくこと:
 * labelstack_socket : プッシュしたい値。（VPtr型）
 */
static void push_labelstack(void)
{
        pA("PAPSMEM0(labelstack_socket, T_VPTR, labelstack_ptr, labelstack_head);");
        pA("labelstack_head++;");
}

/* ラベルスタックからラベル型（VPtr型）をポップする
 * ポップした値は labelstack_socket に格納される。
 */
static void pop_labelstack(void)
{
        pA("labelstack_head--;");
        pA("PAPLMEM0(labelstack_socket, T_VPTR, labelstack_ptr, labelstack_head);");
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
static void push_attachstack(const char* register_name)
{
        pA("PASMEM0(%s, T_SINT32, attachstack_ptr, attachstack_head);", register_name);
        pA("attachstack_head++;");
}

/* アタッチスタックからアドレス(SInt32型)を、任意のレジスターへプッシュする
 * 事前に attachstack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 * また、代入プロセスが省略できるので高速化する
 */
static void pop_attachstack(const char* register_name)
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
        push_labelstack();
        pA("PLIMM(P3F, %d);\n", label);

        pA("LB(1, %d);\n", cur_label_index_head);
        cur_label_index_head++;
}

/* pop_labelstack を伴ったリターンの定型命令を出力する
 * すなわち、関数リターンのラッパ。
 */
static void retF(void)
{
        pop_labelstack();
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

/* ヒープメモリー関連
 */

/* ヒープメモリーの初期化
 */
void init_heap(void)
{
        pA("VPtr heap_ptr:P04;");
        pA("SInt32 heap_socket:R04;");
        pA("SInt32 heap_base:R06;");
        pA("SInt32 heap_offset:R05;");
        pA("heap_base = 0;");
};

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
        "SInt32 fixT4:R25;\n"
        "SInt32 fixA1:R22;\n"
        "SInt32 fixA2:R23;\n"
        "SInt32 fixA3:R24;\n"
};

/* ope_matrix 用変数の初期化
 *
 * 3 * 3 行列以下の小さな行列演算の高速化を書きやすいように、一部の変数はunionの関係となっている。
 */
static char init_matrix[] = {
        /* 主にループ処理の必要な大きな行列処理時に用いる想定
         */
        "SInt32 matfixL: R14;\n"
        "SInt32 matfixR: R15;\n"
        "SInt32 matfixA: R16;\n"
        "SInt32 matfixtmp: R17;\n"
        "SInt32 matcountcol: R18;\n"
        "SInt32 matcountrow: R19;\n"
        "SInt32 matcol: R1A;\n"
        "SInt32 matrow: R1B;\n"

        /* 主に3*3以下の小さな行列処理時に用いる想定
         * （ループ目的の場合の名前とは、一部のレジスターがunion関係となっている）
         */
        "SInt32 matfixE0: R14;\n"
        "SInt32 matfixE1: R15;\n"
        "SInt32 matfixE2: R16;\n"
        "SInt32 matfixE3: R17;\n"
        "SInt32 matfixE4: R18;\n"
        "SInt32 matfixE5: R19;\n"
        "SInt32 matfixE6: R1A;\n"
        "SInt32 matfixE7: R1B;\n"
        "SInt32 matfixE8: R1C;\n"

        /* 3項それぞれのベースアドレス保存用。（アタッチへの対応用）
         */
        "SInt32 matbpL: R26;\n"
        "SInt32 matbpR: R27;\n"
        "SInt32 matbpA: R28;\n"
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
        pA(init_attachstack);
        pA(init_eoe_arg);
        pA(init_matrix);
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

/* intのNOT命令を出力する
 * not fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_not_int(void)
{
        pA("if (fixL != 0) {fixA = 0;} else {fixA = 1;}");
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

/* レガシーアキュムレーター
 */

static void __func_add(void)
{
        __func_add_float();
}

static void __func_sub(void)
{
        __func_sub_float();
}

static void __func_mul_inline(void)
{
        __func_mul_inline_float();
}

static void __func_mul(void)
{
        __func_mul_float();
}

static void __func_div(void)
{
        __func_div_float();
}

static void __func_mod(void)
{
        __func_mod_float();
}

static void __func_minus(void)
{
        __func_minus_float();
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

/* ビット反転命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 */
static void __func_invert(void)
{
        pA("fixA = fixL ^ (-1);");
}

/* not命令を出力する
 * fixL -> fixA
 * 予め fixL に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 真（非0）ならば 0 を返し、偽(0)ならば 1 を返す。
 */
static void __func_not(void)
{
        pA("if (fixL == 0) {fixA = 1 << 16;} else {fixA = 0;}");
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
 * 算術シフトとして動作する。
 */
static void __func_arithmetic_rshift(void)
{
        beginF();

        pA("fixR >>= 16;");
        __func_arithmetic_rshift_int();

        endF();
}

/* 右シフト命令を出力する（論理シフト）
 * fixL >> fixR -> fixA
 * 予め fixL, fixR に値をセットしておくこと。 演算結果は fixA へ出力される。
 *
 * 論理シフトとして動作する。
 */
static void __func_logical_rshift(void)
{
        beginF();

        pA("fixR >>= 16;");
        __func_logical_rshift_int();

        endF();
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
        if (var->is_local)
                pA("heap_base = %d + stack_frame;", var->base_ptr);
        else
                pA("heap_base = %d;", var->base_ptr);

        /* 書き込む値を読んでおく */
        pop_stack("stack_socket");

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする
         * （アタッチではない場合は、すでにセットされているデフォルトのheap_baseの値のまま）
         */
        pop_attachstack("attachstack_socket");
        pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;}");

        write_mem("stack_socket", "heap_base");

        /* 変数へ書き込んだ値をスタックへもプッシュしておく
         * （assignment は expression なので、結果を戻り値としてスタックへプッシュする必要がある為）
         */
        push_stack("stack_socket");
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
        if (var->is_local)
                pA("heap_base = %d + stack_frame;", var->base_ptr);
        else
                pA("heap_base = %d;", var->base_ptr);

        /* 書き込む値をスタックから読み込む命令を出力（コンパイル時） */
        pop_stack("heap_socket");

        /* ヒープ書き込みオフセット位置をセットする命令を出力する（コンパイル時）
         * これは配列の次元によって分岐する
         */
        /* １次元配列の場合 */
        if (var->row_len == 1) {
                pop_stack("heap_offset");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* これは[行, 列]の列 */
                pop_stack("heap_offset");

                /* これは[行, 列]の行 */
                pop_stack("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: assignment, var->row_len の値が不正です");
        }

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする
         * （アタッチではない場合は、すでにセットされているデフォルトのheap_baseの値のまま）
         */
        pop_attachstack("attachstack_socket");
        pA("if (attachstack_socket >= 0) {heap_base = attachstack_socket;}");

        pA("heap_base += heap_offset >> 16;");
        write_mem("heap_socket", "heap_base");

        /* 変数へ書き込んだ値をスタックへもプッシュしておく
         * （assignment は expression なので、結果を戻り値としてスタックへプッシュする必要がある為）
         */
        push_stack("heap_socket");
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
        pop_attachstack("attachstack_socket");
        pA_nl("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} ");
        if (var->is_local)
                pA("else {heap_base = %d + stack_frame;}", var->base_ptr);
        else
                pA("else {heap_base = %d;}", var->base_ptr);

        /* heap_base自体を（アドレス自体を）スタックにプッシュする */
        push_stack("heap_base");
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
                pop_attachstack("attachstack_socket");
                pA_nl("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} ");
                if (var->is_local)
                        pA("else {heap_base = %d + stack_frame;}", var->base_ptr);
                else
                        pA("else {heap_base = %d;}", var->base_ptr);

                /* heap_base へオフセットを足す
                 */
                pop_stack("heap_offset");
                pA("heap_base += heap_offset >> 16;");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時）
                 */
                pop_attachstack("attachstack_socket");
                pA_nl("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} ");
                if (var->is_local)
                        pA("else {heap_base = %d + stack_frame;}", var->base_ptr);
                else
                        pA("else {heap_base = %d;}", var->base_ptr);

                /* heap_base へオフセットを足す
                 */
                /* これは[行, 列]の列 */
                pop_stack("heap_offset");

                /* これは[行, 列]の行。
                 * これと変数の列サイズと乗算した値を更に足すことで、変数の先頭からのオフセット位置
                 */
                pop_stack("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

                pA("heap_offset >>= 16;");
                pA("heap_base += heap_offset;");

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: __OPE_ADDRESS read_variable, col_len の値が不正です");
        }

        /* heap_base自体を（アドレス自体を）スタックにプッシュする */
        push_stack("heap_base");
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

        /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時） */
        pop_attachstack("attachstack_socket");
        pA_nl("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} ");
        if (var->is_local)
                pA("else {heap_base = %d + stack_frame;}", var->base_ptr);
        else
                pA("else {heap_base = %d;}", var->base_ptr);

        read_mem("stack_socket", "heap_base");

        /* 結果をスタックにプッシュする */
        push_stack("stack_socket");
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
                pop_stack("heap_offset");

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時） */
                pop_attachstack("attachstack_socket");
                pA_nl("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} ");
                if (var->is_local)
                        pA("else {heap_base = %d + stack_frame;}", var->base_ptr);
                else
                        pA("else {heap_base = %d;}", var->base_ptr);

                pA("heap_base += heap_offset >> 16;");
                read_mem("stack_socket", "heap_base");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* これは[行, 列]の列 */
                pop_stack("heap_offset");

                /* これは[行, 列]の行。
                 * これと変数の列サイズと乗算した値を更に足すことで、変数の先頭からのオフセット位置
                 */
                pop_stack("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

                /* アタッチスタックからポップして、場合に応じてheap_baseへセットする（コンパイル時） */
                pop_attachstack("attachstack_socket");
                pA_nl("if (attachstack_socket >= 0) {heap_base = attachstack_socket;} ");
                if (var->is_local)
                        pA("else {heap_base = %d + stack_frame;}", var->base_ptr);
                else
                        pA("else {heap_base = %d;}", var->base_ptr);

                pA("heap_base += heap_offset >> 16;");
                read_mem("stack_socket", "heap_base");

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: read_variable, col_len の値が不正です");
        }

        /* 結果をスタックにプッシュする */
        push_stack("stack_socket");
}

/* 以下、ユーザー定義関数関連 */

/* 関数呼び出し
 */
static void __call_user_function(const char* iden)
{
        /* ラベルリストに名前が存在しなければエラー */
        if (labellist_search_unsafe(iden) == -1)
                yyerror("syntax err: 未定義の関数を実行しようとしました");

        /* gosub とほぼ同じ */
        pA("PLIMM(%s, %d);\n", CUR_RETURN_LABEL, cur_label_index_head);
        push_labelstack();
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

        /* スコープ復帰位置をプッシュし、一段深いローカルスコープの開始（コンパイル時）
         */
        inc_cur_scope_depth();
        varlist_scope_push();

        /* ローカル変数として @stack_prev_frame を作成し、
         * その後、それのオフセットに 0 をセットする（コンパイル時）
         */
        const char stack_prev_frame_iden[] = "@stack_prev_frame";
        varlist_add_local(stack_prev_frame_iden, 1, 1);
        varlist_set_scope_head();

        /* スタック上に格納された引数順序と対応した順序となるように、ローカル変数を作成していく。
         * （作成したローカル変数へ値を代入する手間が省ける）
         */
        int32_t i;
        for (i = 0; i < arglen; i++) {
                char iden[0x1000];
                idenlist_pop(iden);

                varlist_add_local(iden, 1, 1);

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
        pA("junkApi_putStringDec('\\1', stack_head, 10, 1);");
        pA("junkApi_putConstString(', stack_frame=');");
        pA("junkApi_putStringDec('\\1', stack_frame, 10, 1);");
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
        pA("junkApi_putStringDec('\\1', stack_head, 10, 1);");
        pA("junkApi_putConstString(', stack_frame=');");
        pA("junkApi_putStringDec('\\1', stack_frame, 10, 1);");
        pA("junkApi_putConstString('\\n');");
#endif /* DEBUG_SCOPE */

        push_stack("fixA");

        /* 関数呼び出し元の位置まで戻る */
        pop_labelstack();
        pA("PCP(P3F, %s);\n", CUR_RETURN_LABEL);
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
        pA("PALMEM0(fixA, T_SINT32, heap_ptr, fixL);");
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
        pA("PASMEM0(fixR, T_SINT32, heap_ptr, fixL);");
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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varL->array_len - 1);

        beginF();

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                pA("heap_base = matbpL + matcountrow;");
                read_mem("heap_socket", "heap_base");

                pA("heap_base = matbpA + matcountrow;");
                write_mem("heap_socket", "heap_base");

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
        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        beginF();

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                pA("heap_base = matbpA + matcountrow;");
                write_mem("matfixL", "heap_base");

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
        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
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
                        pA("heap_base = matbpA + matcountrow;");
                        write_mem("heap_socket", "heap_base");

                /* 対角成分では無い場合 */
                pA("} else {");
                        pA("heap_socket = 0;");
                        pA("heap_base = matbpA + matcountrow;");
                        write_mem("heap_socket", "heap_base");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
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

                        /* strA の書き込みオフセットを計算（strLの行と列を入れ替えたオフセット）
                         */
                        pA("matfixA = matcol * matcountrow;");
                        pA("matfixA += matcountcol;");

                        /* 要素のスワップ
                         * strA, strL の記憶領域が同一の場合でも動作するように一時変数を噛ませてスワップ
                         */
                        pA("heap_base = matbpA + matfixA;");
                        read_mem("matfixA", "heap_base");

                        pA("heap_base = matbpL + matfixL;");
                        read_mem("heap_socket", "heap_base");
                        pA("heap_base = matbpA + matfixA;");
                        write_mem("heap_socket", "heap_base");

                        pA("heap_base = matbpL + matfixL;");
                        write_mem("matfixtmp", "heap_base");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
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
                pA("heap_base = matbpL + matcountrow;");
                read_mem("fixL", "heap_base");

                pA("heap_base = matbpR + matcountrow;");
                read_mem("fixR", "heap_base");

                /* 演算種類応じて分岐
                 * } else if { を使わないのは意図的。（アセンブラーのバグ対策）
                 */

                /* 加算の場合 */
                pA("if (matfixtmp == %d) {", OPE_MATRIX_MERGE_COMMON_TYPE_ADD);
                        pA("heap_socket = fixL + fixR;");

                        /* 演算結果をstrAへ書き込む */
                        pA("heap_base = matbpA + matcountrow;");
                        write_mem("heap_socket", "heap_base");
                pA("}");

                /* 減算の場合 */
                pA("if (matfixtmp == %d) {", OPE_MATRIX_MERGE_COMMON_TYPE_SUB);
                        pA("heap_socket = fixL - fixR;");

                        /* 演算結果をstrAへ書き込む */
                        pA("heap_base = matbpA + matcountrow;");
                        write_mem("heap_socket", "heap_base");
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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
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
                pA("heap_base = matbpL + matcountrow;");
                read_mem("fixL", "heap_base");

                pA("heap_base = matbpR + matcountrow;");
                read_mem("fixR", "heap_base");

                __func_mul();

                /* 乗算結果をmatfixAへ累積させる */
                pA("matfixA += fixA;");

                /* ループの先頭へジャンプ
                 */
                pA("matcountrow--;");
                pA("PLIMM(P3F, %d);", local_label);
        pA("}");

        /* 演算結果を strA へ書き込む */
        write_mem("matfixA", "matbpA");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
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
        pA("heap_base = matbpL + 0;");
        read_mem("matfixE0", "heap_base");
        pA("heap_base = matbpL + 1;");
        read_mem("matfixE1", "heap_base");
        pA("heap_base = matbpL + 2;");
        read_mem("matfixE2", "heap_base");

        pA("heap_base = matbpR + 0;");
        read_mem("matfixE3", "heap_base");
        pA("heap_base = matbpR + 1;");
        read_mem("matfixE4", "heap_base");
        pA("heap_base = matbpR + 2;");
        read_mem("matfixE5", "heap_base");

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
        pA("heap_base = matbpA + 0;");
        write_mem("matfixE6", "heap_base");
        pA("heap_base = matbpA + 1;");
        write_mem("matfixE7", "heap_base");
        pA("heap_base = matbpA + 2;");
        write_mem("matfixE8", "heap_base");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
                pA("if (matbpR < 0) {matbpR = %d;}", varR->base_ptr);

        /* strA と strR の要素数が異なる場合はエラーとする（コンパイル時） */
        if ((varA->col_len != varR->col_len) || (varA->row_len != varR->row_len))
                yyerror("syntax err: a = s * b において、 a,b の要素数が異なります");

        /* 要素数をセット（コンパイル時） */
        pA("matcountrow = %d;", varA->array_len - 1);

        beginF();

        /* strL から matfixL へ値を読み込む
         */
        read_mem("matfixL", "matbpL");

        /* 局所ループ用に無名ラベルをセット */
        const int32_t local_label = cur_label_index_head;
        cur_label_index_head++;
        pA("LB(1, %d);", local_label);

        pA("if (matcountrow >= 0) {");
                /* strR から値を読み込む
                 * heap_socket を fixR へ代入してるのはタイポ間違いではない。意図的。
                 * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                 */
                pA("heap_base = matbpR + matcountrow;");
                read_mem("fixR", "heap_base");

                 /* fixL = matfixL も同様の理由。
                 * また、matfixL はスカラーなのに、毎回 fixL へセットしてる理由は、
                 * __func_mul() の呼び出しの際に、（高速化の為に） eoe のスタック退避・復帰を省略してるので、
                 * fixL, fixR などの eoe メンバーは暗黙に破壊される可能性がありうるので。
                 */
                pA("fixL = matfixL;");

                __func_mul();

                /* 演算結果をstrAへ書き込む */
                pA("heap_base = matbpA + matcountrow;");
                write_mem("fixA", "heap_base");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
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

                                /* strR の読み込みオフセットを計算
                                 */
                                pA("matfixR = matcol * matfixtmp;");
                                pA("matfixR += matcountcol;");

                                /* strLの要素 * strRの要素 の演算を行い、
                                 * 計算の途中経過をmatfixAへ加算
                                 *
                                 * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                                 * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                                 */
                                pA("heap_base = matbpL + matfixL;");
                                read_mem("fixL", "heap_base");

                                pA("heap_base = matbpR + matfixR;");
                                read_mem("fixR", "heap_base");

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

#ifdef DEBUG_OPE_MATRIX_MUL_MM
                        pA("junkApi_putConstString('\\nstrA : ');");
                        pA("junkApi_putStringDec('\\1', heap_socket, 6, 0);");
#endif /* DEBUG_OPE_MATRIX_MUL_MM */

                        pA("heap_base = matbpA + heap_offset;");
                        write_mem("matfixA", "heap_base");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
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

                        /* strR の読み込みオフセットを計算
                         */
                        pA("matfixR = matrow * matcountcol;");
                        pA("matfixR += matcountcol;");

                        /* strLの要素 * strRの要素 の演算を行い、
                         * 計算の途中経過をmatfixAへ加算
                         *
                         * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                         * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                         */
                        pA("heap_base = matbpL + matfixL;");
                        read_mem("fixL", "heap_base");

                        pA("heap_base = matbpR + matfixR;");
                        read_mem("fixR", "heap_base");

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
                pA("heap_base = matbpA + matcountrow;");
                write_mem("matfixA", "heap_base");

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

        if (varA->is_local)
                pA("if (matbpA < 0) {matbpA = %d + stack_frame;}", varA->base_ptr);
        else
                pA("if (matbpA < 0) {matbpA = %d;}", varA->base_ptr);

        if (varL->is_local)
                pA("if (matbpL < 0) {matbpL = %d + stack_frame;}", varL->base_ptr);
        else
                pA("if (matbpL < 0) {matbpL = %d;}", varL->base_ptr);

        if (varR->is_local)
                pA("if (matbpR < 0) {matbpR = %d + stack_frame;}", varR->base_ptr);
        else
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

                        /* strR の読み込みオフセットを計算
                         */
                        pA("matfixR = matcountcol;");

                        /* strLの要素 * strRの要素 の演算を行い、
                         * 計算の途中経過をmatfixAへ加算
                         *
                         * heap_socket を fixL, fixR へ代入してるのはタイポ間違いではない。意図的。
                         * 固定小数点数なので、乗算は __func_mul() を使わなければ行えない為。
                         */
                        pA("heap_base = matbpL + matfixL;");
                        read_mem("fixL", "heap_base");

                        pA("heap_base = matbpR + matfixR;");
                        read_mem("fixR", "heap_base");

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
                pA("heap_base = matbpA + matcountrow;");
                write_mem("matfixA", "heap_base");

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
        int32_t ival_list[0x400];
        struct Var* varptr;
        struct StructSpec* structspecptr;
        struct StructMemberSpec* structmemberspecptr;
}

%token __STATE_IF __STATE_ELSE
%token __STATE_SWITCH __STATE_CASE __STATE_DEFAULT
%token __OPE_SELECTION
%token __STATE_WHILE __STATE_DO
%token __STATE_FOR
%token __STATE_READ __STATE_DATA
%token __STATE_GOTO __STATE_RETURN __STATE_CONTINUE __STATE_BREAK
%token __STATE_MAT __STATE_MAT_ZER __STATE_MAT_CON __STATE_MAT_IDN __STATE_MAT_TRN

%token __OPE_SUBST
%token __OPE_AND_SUBST __OPE_OR_SUBST __OPE_XOR_SUBST
%token __OPE_LSHIFT_SUBST __OPE_RSHIFT_SUBST
%token __OPE_ADD_SUBST __OPE_SUB_SUBST
%token __OPE_MUL_SUBST __OPE_DIV_SUBST __OPE_MOD_SUBST
%token __OPE_INC __OPE_DEC

%token __OPE_SIZEOF

%token __OPE_LOGICAL_OR __OPE_LOGICAL_AND

%token __STATE_DIM
%token __TYPE_VOID
%token __TYPE_CHAR __TYPE_SHORT __TYPE_INT __TYPE_LONG
%token __TYPE_FLOAT __TYPE_DOUBLE
%token __TYPE_SIGNED __TYPE_UNSIGNED

%token __TYPE_AUTO __TYPE_REGISTER
%token __TYPE_STATIC __TYPE_EXTERN
%token __TYPE_TYPEDEF

%token __TYPE_CONST
%token __TYPE_VOLATILE

%token __STATE_STRUCT __STATE_ENUM
%token __STATE_ASM
%token __STATE_FUNCTION
%token __FUNC_PRINT __FUNC_INPUT __FUNC_PEEK __FUNC_POKE __FUNC_CHR_S __FUNC_VAL __FUNC_MID_S __FUNC_RND __FUNC_INPUT_S

%token __FUNC_SIN __FUNC_COS __FUNC_TAN __FUNC_SQRT

%token __FUNC_OPENWIN __FUNC_TORGB __FUNC_DRAWPOINT __FUNC_DRAWLINE __FUNC_SLEEP
%token __FUNC_FILLTRI __FUNC_FILLRECT

%left  __OPE_COMPARISON __OPE_NOT_COMPARISON __OPE_ISSMALL __OPE_ISSMALL_COMP __OPE_ISLARGE __OPE_ISLARGE_COMP
%left  __OPE_ADD __OPE_SUB
%left  __OPE_MUL __OPE_DIV __OPE_MOD __OPE_POWER
%left  __OPE_OR __OPE_AND __OPE_XOR __OPE_INVERT __OPE_NOT
%left  __OPE_LSHIFT __OPE_RSHIFT __OPE_ARITHMETIC_RSHIFT
%left  __OPE_COMMA __OPE_COLON __OPE_DOT __OPE_ARROW __OPE_VALEN
%token __OPE_PLUS __OPE_MINUS
%token __OPE_ATTACH __OPE_ADDRESS __OPE_POINTER
%token __LB __RB __DECL_END __IDENTIFIER __LABEL __DEFINE_LABEL __EOF
%token __ARRAY_LB __ARRAY_RB
%token __BLOCK_LB __BLOCK_RB
%token __CONST_STRING __CONST_FLOAT __CONST_INTEGER __CONST_CHAR

%type <ival> __CONST_INTEGER
%type <fval> __CONST_FLOAT
%type <sval> __CONST_CHAR
%type <sval> __CONST_STRING const_strings
%type <sval> __IDENTIFIER __LABEL __DEFINE_LABEL

%type <sval> func_print func_peek func_poke

%type <sval> func_sin func_cos func_tan

%type <sval> func_openwin func_torgb func_drawpoint func_drawline func_sleep
%type <sval> func_filltri func_fillrect

%type <sval> operation const_variable read_variable
%type <sval> selection_if selection_if_v selection_if_e
%type <sval> iterator iterator_while iterator_for
%type <sval> initializer
%type <ival_list> initializer_param
%type <sval> expression assignment jump define_label function
%type <sval> ope_matrix
%type <sval> syntax_tree declaration_list declaration declaration_block
%type <sval> define_function

%type <sval> define_struct
%type <structspecptr> initializer_struct_member_list
%type <structmemberspecptr> initializer_struct_member

%type <sval> var_identifier
%type <ival> expression_list identifier_list attach_base

%type <ival> __declaration_specifiers
%type <ival> __storage_class_specifier __type_specifier __type_qualifier

%start syntax_tree

%%

syntax_tree
        : declaration_list __EOF {
                YYACCEPT;
                /* start_tune_process(); */
        }
        ;

declaration_list
        : declaration
        | declaration declaration_list
        | __translation_unit
        ;

declaration_block
        : __BLOCK_LB __BLOCK_RB {
                /* 空の場合は何もしない */
        }
        | __BLOCK_LB {
                inc_cur_scope_depth();  /* コンパイル時 */
                varlist_scope_push();   /* コンパイル時 */
        } declaration_list __BLOCK_RB {
                dec_cur_scope_depth();  /* コンパイル時 */
                varlist_scope_pop();    /* コンパイル時 */
        }
        ;

declaration
        : declaration_block
        | initializer __DECL_END
        | ope_matrix __DECL_END
        | expression __DECL_END  {
                /* expression に属するステートメントは、
                 * 終了時点で”必ず”スタックへのプッシュが1個だけ余計に残ってるという前提。
                 * それを掃除するため。
                 */
                pop_stack_dummy();
        }
        | selection_if
        | iterator
        | jump __DECL_END
        | define_label __DECL_END
        | define_function
        | define_struct
        | inline_assembler
        | __DECL_END
        ;

expression
        : operation
        | const_variable
        | read_variable
        | assignment
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
                pop_stack("fixL");
                __func_print();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_peek
        : __FUNC_PEEK expression {
                pop_stack("fixL");
                __func_peek();
                push_stack("fixA");
        }
        ;

func_poke
        : __FUNC_POKE expression expression {
                pop_stack("fixR");
                pop_stack("fixL");
                __func_poke();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_sin
        : __FUNC_SIN expression {
                pop_stack("fixL");
                __func_sin();
                push_stack("fixA");
        }
        ;

func_cos
        : __FUNC_COS expression {
                pop_stack("fixL");
                __func_cos();
                push_stack("fixA");
        }
        ;

func_tan
        : __FUNC_TAN expression {
                pop_stack("fixL");
                __func_tan();
                push_stack("fixA");
        }
        ;

func_sqrt
        : __FUNC_SQRT expression {
                pop_stack("fixL");
                __func_sqrt();
                push_stack("fixA");
        }
        ;

func_openwin
        : __FUNC_OPENWIN expression expression {
                pop_stack("fixR");       /* y */
                pop_stack("fixL");       /* x */
                __func_openwin();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_torgb
        : __FUNC_TORGB expression expression expression
        {
                pop_stack("fixS");       /* B */
                pop_stack("fixR");       /* G */
                pop_stack("fixL");       /* R */
                __func_torgb();
                push_stack("fixA");
        }
        ;

func_drawpoint
        : __FUNC_DRAWPOINT expression expression expression expression
        {
                pop_stack("fixS");       /* RGB */
                pop_stack("fixR");       /* y0 */
                pop_stack("fixL");       /* x0 */
                pop_stack("fixT");       /* mode */
                __func_drawpoint();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_drawline
        : __FUNC_DRAWLINE expression expression expression expression expression expression
        {
                pop_stack("fixS");       /* RGB */
                pop_stack("fixRx");      /* y1 */
                pop_stack("fixLx");      /* x1 */
                pop_stack("fixR");       /* y0 */
                pop_stack("fixL");       /* x0 */
                pop_stack("fixT");       /* mode */
                __func_drawline();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_filltri
        : __FUNC_FILLTRI expression
                         expression expression expression expression expression expression
                         expression
        {
                pop_stack("fixS");       /* RGB */
                pop_stack("fixT2");      /* y2 */
                pop_stack("fixT1");      /* x2 */
                pop_stack("fixRx");      /* y1 */
                pop_stack("fixLx");      /* x1 */
                pop_stack("fixR");       /* y0 */
                pop_stack("fixL");       /* x0 */
                pop_stack("fixT");       /* mode */
                __func_filltri();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_fillrect
        : __FUNC_FILLRECT expression expression expression expression expression expression
        {
                pop_stack("fixS");       /* RGB */
                pop_stack("fixRx");      /* y1 */
                pop_stack("fixLx");      /* x1 */
                pop_stack("fixR");       /* y0 */
                pop_stack("fixL");       /* x0 */
                pop_stack("fixT");       /* mode */
                __func_fillrect();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

func_sleep
        : __FUNC_SLEEP expression expression {
                pop_stack("fixR");       /* msec */
                pop_stack("fixL");       /* mode */
                __func_sleep();
                push_stack_dummy(); /* 終了時に push +1 な状態にするため */
        }
        ;

initializer_param
        : {
                $$[0] = 1;
                $$[1] = 1;
        }
        | __ARRAY_LB __CONST_INTEGER __ARRAY_RB {
                $$[0] = $2;
                $$[1] = 1;
        }
        | __ARRAY_LB __CONST_INTEGER __OPE_COMMA __CONST_INTEGER __ARRAY_RB {
                $$[0] = $4;
                $$[1] = $2;
        }
        ;

initializer
        : __STATE_DIM __IDENTIFIER initializer_param {
                varlist_add_local($2, $3[1], $3[0]);
                strcpy($$, $2);
        }
        | initializer __OPE_COMMA __IDENTIFIER initializer_param {
                varlist_add_local($3, $4[1], $4[0]);
                strcpy($$, $3);
        }
        | initializer __OPE_SUBST expression {
                pA("attachstack_socket = -1;");
                push_attachstack("attachstack_socket");
                __assignment_scaler($1);

                /* __assignment_scaler() でスタックが +1 状態なのを掃除 */
                pop_stack_dummy();
        }
        ;

attach_base
        : {
                pA("attachstack_socket = -1;");
                push_attachstack("attachstack_socket");
        }
        | expression __OPE_ATTACH {
                pop_stack("stack_socket");
                push_attachstack("stack_socket");
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
                pop_attachstack("matbpL");
                pop_attachstack("matbpA");

                ope_matrix_copy($2, $4);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_ZER {
                pop_attachstack("matbpA");

                pA("matfixL = 0;");
                ope_matrix_scalar($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_CON {
                pop_attachstack("matbpA");

                pA("matfixL = %d;", 1 << 16);
                ope_matrix_scalar($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST expression __OPE_MUL __STATE_MAT_CON {
                pop_stack("matfixL");

                pop_attachstack("matbpA");

                ope_matrix_scalar($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_IDN {
                pop_attachstack("matbpA");

                ope_matrix_idn($2);
        }
        | __STATE_MAT var_identifier __OPE_SUBST __STATE_MAT_TRN __LB var_identifier __RB {
                pop_attachstack("matbpL");
                pop_attachstack("matbpA");

                ope_matrix_trn($2, $6);
        }
        | __STATE_MAT var_identifier __OPE_SUBST var_identifier __OPE_ADD var_identifier {
                pop_attachstack("matbpR");
                pop_attachstack("matbpL");
                pop_attachstack("matbpA");

                ope_matrix_add($2, $4, $6);
        }
        | __STATE_MAT var_identifier __OPE_SUBST var_identifier __OPE_SUB var_identifier {
                pop_attachstack("matbpR");
                pop_attachstack("matbpL");
                pop_attachstack("matbpA");

                ope_matrix_sub($2, $4, $6);
        }
        | __STATE_MAT var_identifier __OPE_SUBST var_identifier __OPE_MUL var_identifier {
                pop_attachstack("matbpR");
                pop_attachstack("matbpL");
                pop_attachstack("matbpA");

                ope_matrix_mul($2, $4, $6);
        }
        ;

const_variable
        : __CONST_STRING {
                push_stack_dummy();
        }
        | __CONST_FLOAT {
                double a;
                double b = modf($1, &a);
                int32_t ia = ((int32_t)a) << 16;
                int32_t ib = ((int32_t)(0x0000ffff * b)) & 0x0000ffff;

                pA("stack_socket = %d;", ia | ib);
                push_stack("stack_socket");
        }
        | __CONST_INTEGER {
                pA("stack_socket = %d;", $1 << 16);
                push_stack("stack_socket");
        }
        ;

operation
        : expression __OPE_ADD expression {
                read_eoe_arg();
                __func_add();
                push_stack("fixA");
        }
        | expression __OPE_SUB expression {
                read_eoe_arg();
                __func_sub();
                push_stack("fixA");
        }
        | expression __OPE_MUL expression {
                read_eoe_arg();
                __func_mul();
                push_stack("fixA");
        }
        | expression __OPE_DIV expression {
                read_eoe_arg();
                __func_div();
                push_stack("fixA");
        }
        | expression __OPE_POWER expression {
                read_eoe_arg();
                __func_pow();
                push_stack("fixA");
        }
        | expression __OPE_MOD expression {
                read_eoe_arg();
                __func_mod();
                push_stack("fixA");
        }
        | expression __OPE_OR expression {
                read_eoe_arg();
                __func_or();
                push_stack("fixA");
        }
        | expression __OPE_AND expression {
                read_eoe_arg();
                __func_and();
                push_stack("fixA");
        }
        | expression __OPE_XOR expression {
                read_eoe_arg();
                __func_xor();
                push_stack("fixA");
        }
        | __OPE_INVERT expression {
                pop_stack("fixL");
                __func_invert();
                push_stack("fixA");
        }
        | __OPE_NOT expression {
                pop_stack("fixL");
                __func_not();
                push_stack("fixA");
        }
        | expression __OPE_LSHIFT expression {
                read_eoe_arg();
                __func_lshift();
                push_stack("fixA");
        }
        | expression __OPE_RSHIFT expression {
                read_eoe_arg();
                __func_logical_rshift();
                push_stack("fixA");
        }
        | expression __OPE_ARITHMETIC_RSHIFT expression {
                read_eoe_arg();
                __func_arithmetic_rshift();
                push_stack("fixA");
        }
        | __OPE_ADD expression %prec __OPE_PLUS {
                /* 何もしない */
        }
        | __OPE_SUB expression %prec __OPE_MINUS {
                pop_stack("fixL");
                __func_minus();
                push_stack("fixA");
        }
        | __LB expression __RB {
                /* 何もしない */
        }
        ;

comparison
        : expression __OPE_COMPARISON expression {
                read_eoe_arg();

                pA("if (fixL == fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack("stack_socket");
        }
        | expression __OPE_NOT_COMPARISON expression {
                read_eoe_arg();

                pA("if (fixL != fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack("stack_socket");
        }
        | expression __OPE_ISSMALL expression {
                read_eoe_arg();

                pA("if (fixL < fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack("stack_socket");
        }
        | expression __OPE_ISSMALL_COMP expression {
                read_eoe_arg();

                pA("if (fixL <= fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack("stack_socket");
        }
        | expression __OPE_ISLARGE expression {
                read_eoe_arg();

                pA("if (fixL > fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack("stack_socket");
        }
        | expression __OPE_ISLARGE_COMP expression {
                read_eoe_arg();

                pA("if (fixL >= fixR) {stack_socket = 0x00010000;} else {stack_socket = 0;}");
                push_stack("stack_socket");
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
        | var_identifier __LB {
                /* 現在の stack_frame をプッシュする。
                 * そして、ここには関数終了後にはリターン値が入った状態となる。
                 */
                push_stack("stack_frame");
        } expression_list __RB {
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
                pop_stack("stack_socket");
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

iterator
        : iterator_while
        | iterator_for
        ;

iterator_while
        : __STATE_WHILE {
                /* ループの復帰位置をここに設定 */
                const int32_t loop_head = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = loop_head;

                pA("LB(1, %d);", loop_head);

        } __LB expression __RB {
                pop_stack("stack_socket");
                pA("if (stack_socket != 0) {");

        } declaration {
                /* ループの復帰 */
                pA("PLIMM(P3F, %d);", $<ival>2);
                pA_nl("}");
        }
        ;

iterator_for
        : __STATE_FOR __LB expression {
                /* スタックを掃除 */
                pop_stack("stack_socket");

                /* head ラベルID */
                int32_t loop_head = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = loop_head;

                /* head ラベル */
                pA("LB(1, %d);", loop_head);

        } __DECL_END {
                /* end ラベルID */
                $<ival>$ = cur_label_index_head;
                cur_label_index_head++;

        } expression {
                /* main ラベルID */
                int32_t loop_main = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = loop_main;

                /* スタックから条件判定結果をポップ */
                pop_stack("stack_socket");

                /* 条件判定結果が真ならば main ラベルへジャンプ */
                pA("if (stack_socket != 0) {PLIMM(P3F, %d);}", loop_main);

                /* 条件判定結果が真でないならば（偽ならば） end ラベルへジャンプ */
                pA("PLIMM(P3F, %d);", $<ival>6);

        } __DECL_END {
                /* pre_head ラベルID */
                int32_t loop_pre_head = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = loop_pre_head;

                /* pre_head ラベル */
                pA("LB(1, %d);", loop_pre_head);

        } expression __RB {
                /* スタックを掃除 */
                pop_stack("stack_socket");

                /* head ラベルへジャンプ */
                pA("PLIMM(P3F, %d);", $<ival>4);

                /* main ラベル */
                pA("LB(1, %d);", $<ival>8);

        } declaration {
                /* pre_head ラベルへジャンプ */
                pA("PLIMM(P3F, %d);", $<ival>10);

                /* end ラベル */
                pA("LB(1, %d);", $<ival>6);
        }

define_label
        : __DEFINE_LABEL {
                pA("LB(1, %d);\n", labellist_search($1));
        }
        ;

jump
        : __STATE_GOTO __LABEL {
                pA("PLIMM(P3F, %d);\n", labellist_search($2));
        }
        | __STATE_RETURN expression {
                pop_stack("fixA");
                __define_user_function_return();
        }
        | __STATE_RETURN {
                /* 空の return の場合は return 0 として動作させる。
                 * これは、ユーザー定義関数は expression なので、
                 * 終了後に必ずスタックが +1 状態である必要があるため。
                 */
                pA("fixA = 0;");
                __define_user_function_return();
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
        : __STATE_FUNCTION __IDENTIFIER __LB identifier_list __RB {
                const int32_t skip_label = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = skip_label;

                __define_user_function_begin($2, $4, skip_label);

        } __BLOCK_LB declaration_list __BLOCK_RB {
                __define_user_function_end($<ival>6);
        }
        ;

initializer_struct_member
        : __STATE_DIM __IDENTIFIER initializer_param __DECL_END {
                $$ = structmemberspec_new($2, $3[1], $3[0]);
        }
        | initializer_struct_member __OPE_COMMA __IDENTIFIER initializer_param __DECL_END {
                $$ = structmemberspec_new($3, $4[1], $4[0]);
        }
        ;

initializer_struct_member_list
        : {
                $$ = structspec_new();
        }
        | initializer_struct_member {
                struct StructSpec* spec = structspec_new();
                structspec_add_member(spec, $1);
                $$ = spec;
        }
        | initializer_struct_member initializer_struct_member_list {
                structspec_add_member($2, $1);
                $$ = $2;
        }
        ;

define_struct
        : __STATE_STRUCT __IDENTIFIER __BLOCK_LB
          initializer_struct_member_list __BLOCK_RB __DECL_END
        {
                structspec_set_name($4, $2);
                structspec_ptrlist_add($4);
        }
        ;

const_strings
        : __CONST_STRING
        | const_strings __CONST_STRING {
                strcpy($$, $1);
                strcat($$, $2);
        }
        ;

inline_assembler
        : __STATE_ASM __LB const_strings __RB {
                pA($3);
        }
        | __STATE_ASM __LB const_strings __OPE_SUBST expression __RB {
                pop_stack($3);
        }
        | __STATE_ASM __LB var_identifier __OPE_SUBST const_strings __RB {
                push_stack($5);
                __assignment_scaler($3);
        }
        | __STATE_ASM __LB
          var_identifier __ARRAY_LB expression_list __ARRAY_RB
          __OPE_SUBST const_strings __RB {
                push_stack($8);
                __assignment_array($3, $5);
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
        :
        ;

__declaration
        : __declaration_specifiers __DECL_END
        | __declaration_specifiers __init_declarator_list __DECL_END

__declaration_list
        : __declaration
        | __declaration_list __declaration

__declaration_specifiers
        : __storage_class_specifier
        | __type_specifier
        | __type_qualifier
        | __storage_class_specifier __declaration_specifiers {
                return($1 | $2);
        }
        | __type_specifier __declaration_specifiers {
                return($1 | $2);
        }
        | __type_qualifier __declaration_specifiers {
                return($1 | $2);
        }
        ;

__storage_class_specifier
        : __TYPE_AUTO           {return(TYPE_AUTO);}
        | __TYPE_REGISTER       {return(TYPE_REGISTER);}
        | __TYPE_STATIC         {return(TYPE_STATIC);}
        | __TYPE_EXTERN         {return(TYPE_EXTERN);}
        | __TYPE_TYPEDEF        {return(TYPE_TYPEDEF);}
        ;

__type_specifier
        : __TYPE_VOID           {return(TYPE_VOID);}
        | __TYPE_CHAR           {return(TYPE_CHAR);}
        | __TYPE_SHORT          {return(TYPE_SHORT);}
        | __TYPE_INT            {return(TYPE_INT);}
        | __TYPE_LONG           {return(TYPE_LONG);}
        | __TYPE_FLOAT          {return(TYPE_FLOAT);}
        | __TYPE_DOUBLE         {return(TYPE_DOUBLE);}
        | __TYPE_SIGNED         {return(TYPE_SIGNED);}
        | __TYPE_UNSIGNED       {return(TYPE_UNSIGNED);}
        ;

__type_qualifier
        : __TYPE_CONST          {return(TYPE_CONST);}
        | __TYPE_VOLATILE       {return(TYPE_VOLATILE);}
        ;

__struct_or_union_specifier
        :
        ;

__struct_or_union
        :
        ;

__struct_declaration_list
        :
        ;

__init_declarator_list
        : __init_declarator
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
        : __struct_declarator
        | __struct_declarator_list __OPE_COMMA __struct_declarator
        ;

__struct_declarator_list
        : __struct_declarator
        | __struct_declarator_list __OPE_COMMA __struct_declarator
        ;

__struct_declarator
        : __declarator
        | __declarator __OPE_COLON __constant_expression
        | __OPE_COLON __constant_expression
        ;

__enum_specifier
        : __STATE_ENUM __IDENTIFIER __BLOCK_LB __enumerator_list __BLOCK_RB
        | __STATE_ENUM __BLOCK_LB __enumerator_list __BLOCK_RB
        | __STATE_ENUM __IDENTIFIER
        ;

__enumerator_list
        : __enumerator
        | __enumerator_list __OPE_COMMA __enumerator
        ;

__enumerator
        : __IDENTIFIER
        | __IDENTIFIER __OPE_SUBST __constant_expression
        ;

__declarator
        : __OPE_MUL __direct_declarator %prec __OPE_POINTER
        | __direct_declarator
        ;

__direct_declarator
        : __IDENTIFIER
        | __LB __declarator __RB
        | __direct_declarator __ARRAY_LB __constant_expression __ARRAY_RB
        | __direct_declarator __ARRAY_LB __ARRAY_RB
        | __direct_declarator __LB __parameter_type_list __RB
        | __direct_declarator __LB __identifier_list __RB
        | __direct_declarator __LB __RB
        ;

__pointer
        : __OPE_MUL %prec __OPE_POINTER
        | __OPE_MUL __type_qualifier_list %prec __OPE_POINTER
        | __OPE_MUL __pointer %prec __OPE_POINTER
        | __OPE_MUL __type_qualifier_list __pointer %prec __OPE_POINTER
        ;

__type_qualifier_list
        : __type_qualifier
        | __type_qualifier_list __type_qualifier
        ;

__parameter_type_list
        : __parameter_list
        | __parameter_list __OPE_COMMA __OPE_VALEN
        ;

__parameter_list
        : __parameter_declaration
        | __parameter_list __OPE_COMMA __parameter_declaration
        ;

__parameter_declaration
        : __declaration_specifiers __declaration
        | __declaration_specifiers __abstract_declarator
        | __declaration_specifiers
        ;

__identifier_list
        : __IDENTIFIER
        | __identifier_list __OPE_COMMA __IDENTIFIER
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
        | __specifier_qualifier_list
        ;

__abstract_declarator
        : __OPE_MUL %prec __OPE_POINTER
        | __OPE_MUL __direct_abstract_declarator %prec __OPE_POINTER
        | __direct_abstract_declarator
        ;

__direct_abstract_declarator
        : __LB __abstract_declarator __RB

        | __direct_abstract_declarator __ARRAY_LB __constant_expression __ARRAY_RB
        | __ARRAY_LB __constant_expression __ARRAY_RB
        | __direct_abstract_declarator __ARRAY_LB __ARRAY_RB
        | __ARRAY_LB __ARRAY_RB

        | __direct_abstract_declarator __LB __parameter_type_list __RB
        | __LB __parameter_type_list __RB
        | __direct_abstract_declarator __LB __RB
        | __LB __RB
        ;

__typedef_name
        : /* __IDENTIFIER */
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
        : __IDENTIFIER __OPE_COLON __statement
        | __STATE_CASE __constant_expression __OPE_COLON __statement
        | __STATE_DEFAULT __OPE_COLON __statement
        ;

__expression_statement
        : __expression __DECL_END
        | __DECL_END
        ;

__compound_statement
        : __BLOCK_LB __declaration_list __statement_list __BLOCK_RB
        | __BLOCK_LB __statement_list __BLOCK_RB
        | __BLOCK_LB __declaration_list __BLOCK_RB
        | __BLOCK_LB __BLOCK_RB
        ;

__statement_list
        : __statement
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
        : __STATE_GOTO __IDENTIFIER __DECL_END
        | __STATE_CONTINUE __DECL_END
        | __STATE_BREAK __DECL_END
        | __STATE_RETURN __expression __DECL_END
        ;

__expression
        : __assignment_expression
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
        : __conditional_expression
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
        | __equality_expression __OPE_COMPARISON __relational_expression
        | __equality_expression __OPE_NOT_COMPARISON __relational_expression
        ;

__relational_expression
        : __shift_expression
        | __relational_expression __OPE_ISSMALL __shift_expression
        | __relational_expression __OPE_ISLARGE __shift_expression
        | __relational_expression __OPE_ISSMALL_COMP __shift_expression
        | __relational_expression __OPE_ISLARGE_COMP __shift_expression
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
        | __LB __IDENTIFIER __RB __cast_expression
        ;

__unary_expression
        : __postfix_expression
        | __OPE_INC __unary_expression
        | __OPE_DEC __unary_expression
        | __unary_operator __cast_expression
        | __OPE_SIZEOF __unary_expression
        | __OPE_SIZEOF __LB __IDENTIFIER __RB
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
        | __postfix_expression __OPE_DOT __IDENTIFIER
        | __postfix_expression __OPE_ARROW __IDENTIFIER
        | __postfix_expression __OPE_INC
        | __postfix_expression __OPE_DEC
        ;

__primary_expression
        : __IDENTIFIER
        | __constant
        | __CONST_STRING
        | __LB __expression __RB
        ;

__argument_expression_list
        :
        | __assignment_expression
        | __argument_expression_list __OPE_COMMA __assignment_expression
        ;

__constant
        : __CONST_INTEGER
        | __CONST_CHAR
        | __CONST_FLOAT
        | __enumeration_constant
        ;

__enumeration_constant
        :
        ;

%%
