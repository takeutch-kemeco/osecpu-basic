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

extern char filepath[0x1000];
extern int32_t linenumber;

/* 現在の filepath のファイル中から、line行目を文字列として dst へ読み出す。
 * dst には十分な長さのバッファーを渡すこと。
 *
 * line が 1 未満、または EOF 以降の場合は -1 を返す。
 *
 * これは主にエラー表示時に、補助的な情報として表示する文字列用。
 * メインの字句解析や構文解析に用いるような用途には使ってない。
 */
static int32_t read_line_file(char* dst, const int32_t line)
{
        if (line < 1)
                return -1;

        FILE* fp = fopen(filepath, "rt");

        /* 目的行までシーク
         */
        int i = line - 1;
        while (i-->0) {
                while (1) {
                        int c = fgetc(fp);
                        if (c == '\n')
                                break;

                        if (c == EOF)
                                return -1;
                }
        }

        /* 改行、または EOF までを dst へ読み出す
         */
        while (1) {
                int c = fgetc(fp);
                if (c == '\n' || c == EOF)
                        break;

                *dst++ = c;
        }

        *dst = '\0';

        fclose(fp);
        return 0;
}

/* 警告表示 */
void yywarning(const char *error_message)
{
        printf("filepath: %s\n", filepath);

        /* エラー行と、その前後 3 行を表示する
         */
        char tmp[0x1000];
        int i;
        for (i = -3; i <= +3; i++) {
                if (read_line_file(tmp, linenumber + i) != -1)
                        printf("%6d: %s\n", linenumber + i, tmp);
        }

        printf("line: %d\n", linenumber);
        printf("%s\n\n", error_message);
}

/* エラー表示 */
void yyerror(const char *error_message)
{
        yywarning(error_message);
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
        int32_t is_direct;      /* この変数が直接参照ならば非0、間接参照ならば0となる */
        int32_t specifier;      /* この変数の型、および型クラスを示すフラグ */
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
        cur->is_direct = 1;     /* デフォルトでは直接参照 */

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

#define MEM_SIZE (0x400000)

static void init_mem(void)
{
        pA("VPtr mem_ptr:P01;");
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

#define STACK_BEGIN_ADDRESS (MEM_SIZE - 0x200000)

/* 任意のレジスターの値をスタックにプッシュする。
 * 事前に stack_socket に値をセットせずに、ダイレクトで指定できるので、ソースが小さくなる
 */
static void push_stack(const char* regname_data)
{
        write_mem(regname_data, "stack_head");
        pA("stack_head++;");

#ifdef DEBUG_STACK
        pA("junkApi_putConstString('push_stack(),stack_head=');");
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
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
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
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
        pA("SInt32 stack_head:R01;");
        pA("SInt32 stack_frame:R02;");
        pA("SInt32 stack_socket:R03;");

        pA("stack_head = %d;", STACK_BEGIN_ADDRESS);
        pA("stack_frame = 0;");
}

/* スタック関連の各種レジスターの値を、実行時に画面に印字する
 * 主にデバッグ用
 */
static void debug_stack(void)
{
        pA("junkApi_putConstString('stack_socket[');");
        pA("junkApi_putStringDec('\\1', stack_socket, 11, 1);");
        pA("junkApi_putConstString('], stack_head[');");
        pA("junkApi_putStringDec('\\1', stack_head, 11, 1);");
        pA("junkApi_putConstString('], stack_frame[');");
        pA("junkApi_putStringDec('\\1', stack_frame, 11, 1);");
        pA("junkApi_putConstString(']\\n');");
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
void init_heap(void)
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

/* 変数インスタンス関連
 */

/* ローカル変数のインスタンス生成
 */
static void __initializer_local(const char* iden,
                                const int32_t row_len,
                                const int32_t col_len)
{
        /* これはコンパイル時の変数状態を設定するにすぎない。
         * 実際の動作時のメモリー確保（シーク位置レジスターの移動等）の命令は出力しない。
         */
        varlist_add_local(iden, row_len, col_len);
        struct Var* var = varlist_search_local(iden);

        /* 実際の動作時にメモリー確保するルーチンはこちら側
         */
        if (var->is_local)
                pA("stack_head = %d + stack_frame;", var->base_ptr + var->array_len);
}

/* 変数インスタンスの具象アドレス取得関連
 * これは struct Var が指す変数の、実際のメモリー上のアドレスを heap_base へ取得する。
 * この heap_base へ読み書きすることで、変数への読み書きとなる。
 */

/* スカラー変数の具象アドレスを heap_base に得る
 */
static void __get_variable_scaler_concrete_address(struct Var* var)
{
        /* 直接参照か、間接参照かに応じて、スタックからポップし
         * heap_baseへアドレスをセットする（コンパイル時）
         */
        if (var->is_direct) {
                if (var->is_local) {
                        pA("heap_base = %d + stack_frame;", var->base_ptr);
                } else {
                        pA("heap_base = %d;", var->base_ptr);
                }
        } else {
                pop_stack("heap_base");
        }

#ifdef DEBUG_VARIABLE
        pA("junkApi_putConstString('\\n__get_variable_scaler_concrete_address(), ');");

        if (var->is_local)
                pA("junkApi_putConstString('is_local ');");
        else
                pA("junkApi_putConstString('is_global ');");

        if (var->is_direct)
                pA("junkApi_putConstString('is_direct ');");
        else
                pA("junkApi_putConstString('is_indirect ');");

        debug_stack();
        debug_heap();
#endif /* DEBUG_VARIABLE */
}

/* 配列変数インスタンスの任意インデックスの具象アドレスを heap_base に得る
 */
static void __get_variable_array_concrete_address(struct Var* var, const int32_t dim)
{
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
                /* 先に添字をポップしておく */
                pop_stack("heap_offset");

                /* 直接参照か、間接参照かに応じて、スタックからポップし
                 * heap_baseへアドレスをセットする（コンパイル時）
                 */
                if (var->is_direct) {
                        if (var->is_local) {
                                pA("heap_base = %d + stack_frame;", var->base_ptr);
                        } else {
                                pA("heap_base = %d;", var->base_ptr);
                        }
                } else {
                        pop_stack("heap_base");
                }

                /* heap_base へオフセットを足す */
                pA("heap_base += heap_offset >> 16;");

        /* 2次元配列の場合 */
        } else if (var->row_len >= 2) {
                /* 先に添字をポップしておく
                 */

                /* これは[行, 列]の列 */
                pop_stack("heap_offset");

                /* これは[行, 列]の行。
                 * これと変数の列サイズと乗算した値を更に足すことで、変数の先頭からのオフセット位置
                 */
                pop_stack("stack_socket");
                pA("heap_offset += stack_socket * %d;", var->col_len);

                /* 直接参照か、間接参照かに応じて、スタックからポップし
                 * heap_baseへアドレスをセットする（コンパイル時）
                 */
                if (var->is_direct) {
                        if (var->is_local) {
                                pA("heap_base = %d + stack_frame;", var->base_ptr);
                        } else {
                                pA("heap_base = %d;", var->base_ptr);
                        }
                } else {
                        pop_stack("heap_base");
                }

                /* heap_base へオフセットを足す */
                pA("heap_base += heap_offset >> 16;");

        /* 1,2次元以外の場合はシステムエラー */
        } else {
                yyerror("system err: __OPE_ADDRESS read_variable, col_len の値が不正です");
        }

#ifdef DEBUG_VARIABLE
        pA("junkApi_putConstString('\\n__get_variable_array_concrete_address(), ');");

        if (var->is_local)
                pA("junkApi_putConstString('is_local ');");
        else
                pA("junkApi_putConstString('is_global ');");

        if (var->is_direct)
                pA("junkApi_putConstString('is_direct ');");
        else
                pA("junkApi_putConstString('is_indirect ');");

        debug_stack();
        debug_heap();
#endif /* DEBUG_VARIABLE */
}

/* スカラー変数、または配列変数インスタンスの任意インデックスの具象アドレスを heap_base に得る
 *
 * dim へは配列インデックスの個数を渡す。（スカラーの場合は0を渡す）
 */
static void __get_variable_concrete_address(struct Var* var, const int32_t dim)
{
        switch (dim) {
        case 0:
                __get_variable_scaler_concrete_address(var);
                break;

        case 1 ... 2:
                __get_variable_array_concrete_address(var, dim);
                break;

        default:
                yyerror("system err: __get_variable_concrete_address(), dim");
        }
}

/* 変数への代入関連
 */

/* 配列変数中の、任意インデックス番目の要素へ、値を代入する。
 *
 * dim へは添字の次元を渡す。（スカラー変数の場合は0を渡す）
 *
 * 値はあらかじめスタックにプッシュされてる前提。
 *     スカラーならば "値" の順、
 *     １次元配列ならば "添字, 値" の順
 *     2次元配列ならば "行添字, 列添字, 値" の順
 * また、間接参照の場合はスタックに "間接参照アドレス, 添字群, 値" の順でプッシュされてる前提。
 */
static void __assignment_variable(struct Var* var, const int32_t dim)
{
        /* 書き込む値を読んでおく */
        pop_stack("heap_socket");
        __get_variable_concrete_address(var, dim);
        write_mem("heap_socket", "heap_base");

        /* 変数へ書き込んだ値をスタックへもプッシュしておく
         * （assignment は expression なので、結果を戻り値としてスタックへプッシュする必要がある為）
         */
        push_stack("heap_socket");
}

/* 変数リード関連
 */

static void __read_variable_ptr(struct Var* var, const int32_t dim)
{
        __get_variable_concrete_address(var, dim);

        /* heap_base自体を（アドレス自体を）スタックにプッシュする */
        push_stack("heap_base");
}

static void __read_variable(struct Var* var, const int32_t dim)
{
        __get_variable_concrete_address(var, dim);

        /* アドレスから読んで結果をスタックへプッシュ
         */
        read_mem("stack_socket", "heap_base");
        push_stack("stack_socket");
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

/* ExpressionContainer 関連
 */

/* EC の演算種類を示すフラグ
 */
#define EC_ASSIGNMENT           1       /* 代入 */
#define EC_COMPARISON           2       /* 比較 */
#define EC_CONDITIONAL          3       /* (a == b) ? x : y; 構文による分岐 */
#define EC_CALC                 5       /* 二項演算。論理演算(a || b など)も含む */
#define EC_CAST                 6       /* 型変換 */
#define EC_UNARY                7       /* 前置演算子による演算 */
#define EC_POSTFIX              8       /* 後置演算子による演算 */
#define EC_CONSTANT             9       /* 定数 */

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
#define EC_OPT_NE               13      /* != */
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

/* EC (ExpressionContainer)
 * 構文解析の expression_statement 以下から終端記号までの情報を保持するためのコンテナ
 *
 * type_specifier: 型
 * type_qualifier: コンパイル時の補助情報, const | volatile
 * strage_class: 記憶領域のタイプ, auto | register | static | extern | typedef
 * type_operator: 演算子
 * type_expression: 演算種類
 * child_ptr[]: この EC をルートとして広がる枝ECへのポインター
 * child_len: child_ptr[] に登録されている枝の数
 */
#define EC_CHILD_MAX 32
struct EC {
        char iden[IDENLIST_STR_LEN];
        uint32_t const_int;
        double const_float;
        uint32_t type_specifier;
        uint32_t type_qualifier;
        uint32_t storage_class;
        uint32_t type_operator;
        uint32_t type_expression;
        struct EC* child_ptr[EC_CHILD_MAX];
        int32_t child_len;
};

/* 白紙のECインスタンスをメモリー領域を確保して生成
 */
struct EC* new_ec(void)
{
        struct EC* ec = malloc(sizeof(*ec));
        ec->type_specifier = 0;
        ec->type_qualifier = 0;
        ec->storage_class = 0;
        ec->type_operator = 0;
        ec->type_expression = 0;
        ec->child_len = 0;
        return ec;
}

/* メモリー領域を開放してECインスタンスを消去
 * (枝(child_ptr[])も含めての開放ではない)
 */
void delete_ec(struct EC* ec)
{
        free((void*)ec);
}

/* EC木をアセンブラへ翻訳
 */
void translate_ec(struct EC* ec)
{
        if (ec->type_expression == 0)
                return;

        if (ec->type_expression == EC_CONSTANT) {
                if (ec->type_specifier == (TYPE_SIGNED | TYPE_INT)) {
                        pA("stack_socket = %d;", ec->const_int);
                        push_stack("stack_socket");
                } else if (ec->type_specifier == TYPE_FLOAT) {
                        pA("stack_socket = %d;", ec->const_int); /* 実際は固定小数なのでint */
                        push_stack("stack_socket");
                } else {
                        yyerror("system err: translate_ec(), EC_CONSTANT");
                }
        } else if (ec->type_expression == EC_CALC) {
                if (ec->type_operator == EC_OPE_ADD) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_add();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_SUB) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_sub();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_MUL) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_mul();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_DIV) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_div();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_MOD) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_mod();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_OR) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_or();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_AND) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_and();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_XOR) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_xor();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_LSHIFT) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_lshift();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_RSHIFT) {
                        translate_ec(ec->child_ptr[0]);
                        translate_ec(ec->child_ptr[1]);

                        read_eoe_arg();
                        __func_logical_rshift();
                        push_stack("fixA");
                } else {
                        yyerror("system err: translate_ec(), EC_CALC");
                }
        } else if (ec->type_expression == EC_UNARY) {
               if (ec->type_operator == EC_OPE_INV) {
                        translate_ec(ec->child_ptr[0]);

                        pop_stack("fixL");
                        __func_invert();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_NOT) {
                        translate_ec(ec->child_ptr[0]);

                        pop_stack("fixL");
                        __func_not();
                        push_stack("fixA");
                } else if (ec->type_operator == EC_OPE_SUB) {
                        translate_ec(ec->child_ptr[0]);

                        pop_stack("fixL");
                        __func_minus();
                        push_stack("fixA");
                } else {
                        yyerror("system err: translate_ec(), EC_UNARY");
                }
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

%token __TYPE_STRUCT __TYPE_UNION __TYPE_ENUM

%token __STATE_ASM
%token __STATE_FUNCTION

%left  __OPE_COMPARISON __OPE_NOT_COMPARISON __OPE_ISSMALL __OPE_ISSMALL_COMP __OPE_ISLARGE __OPE_ISLARGE_COMP
%left  __OPE_ADD __OPE_SUB
%left  __OPE_MUL __OPE_DIV __OPE_MOD
%left  __OPE_OR __OPE_AND __OPE_XOR __OPE_INVERT __OPE_NOT
%left  __OPE_LSHIFT __OPE_RSHIFT
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

%type <sval> read_variable

%type <ec> expression const_variable operation

%type <ival_list> selection_if selection_if_v

%type <sval> iteration_while iteration_for
%type <sval> initializer
%type <ival_list> initializer_param
%type <sval> assignment
%type <sval> declaration_list declaration
%type <sval> define_function

%type <sval> define_struct
%type <structspecptr> initializer_struct_member_list
%type <structmemberspecptr> initializer_struct_member

%type <varptr> var_identifier
%type <ival> expression_list identifier_list

%type <ival> __declaration_specifiers
%type <ival> __storage_class_specifier __type_specifier __type_qualifier

%start translation_unit

%%

translation_unit
        : __EOF {
                YYACCEPT;
        }
        | external_declaration __EOF {
                YYACCEPT;
        }
        | translation_unit external_declaration __EOF {
                YYACCEPT;
        }
        ;

external_declaration
        : declaration_list
        ;

declaration_list
        : /* empty */
        | declaration
        | declaration declaration_list
        ;

compound_statement
        : __BLOCK_LB __BLOCK_RB {
                /* 空の場合は何もしない */
        }
        | __BLOCK_LB {
                inc_cur_scope_depth();  /* コンパイル時 */
                varlist_scope_push();   /* コンパイル時 */
        } declaration_list statement_list __BLOCK_RB {
                dec_cur_scope_depth();  /* コンパイル時 */
                varlist_scope_pop();    /* コンパイル時 */
        }
        ;

declaration
        : initializer __DECL_END
        | define_function
        | define_struct
        | statement
        ;

statement
        : labeled_statement
        | expression_statement
        | compound_statement
        | selection_statement
        | iteration_statement
        | jump_statement
        | inline_assembler_statement
        ;

statement_list
        : /* empty */
        | statement
        | statement_list statement
        ;

expression_statement
        : __DECL_END
        | expression __DECL_END {
                /* expression に属するステートメントは、
                 * 終了時点で”必ず”スタックへのプッシュが1個だけ余計に残ってる為、それを掃除する。
                 */
                pop_stack_dummy();
        }
        ;

expression
        : operation {
                translate_ec($1);
                $$ = new_ec();
        }
        | const_variable {
                translate_ec($1);
                $$ = new_ec();
        }
        | read_variable {
                $$ = new_ec();
        }
        | assignment {
                $$ = new_ec();
        }
        | comparison {
                $$ = new_ec();
        }
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
                __initializer_local($2, $3[1], $3[0]);
                strcpy($$, $2);
        }
        | initializer __OPE_COMMA __IDENTIFIER initializer_param {
                __initializer_local($3, $4[1], $4[0]);
                strcpy($$, $3);
        }
        | initializer __OPE_SUBST expression {
                struct Var* var = varlist_search($1);
                if (var == NULL)
                        yyerror("system err: 変数のインスタンス生成に失敗しました");

                __assignment_variable(var, 0);

                /* initializer は終了時点でスタックが +-0 である必要があるので、
                 * __assignment_variable() によるプッシュを捨てる。
                 */
                pop_stack_dummy();
        }
        ;

var_identifier
        : expression __OPE_ATTACH __IDENTIFIER {
                struct Var* var = varlist_search($3);
                if (var == NULL)
                        yyerror("syntax err: 未定義の変数を参照しようとしました");

                var->is_direct = 0;     /* 間接参照に設定 */
                $$ = var;
        }
        | __IDENTIFIER {
                struct Var* var = varlist_search($1);
                if (var == NULL)
                        yyerror("syntax err: 未定義の変数を参照しようとしました");

                var->is_direct = 1;     /* 直接参照に設定 */
                $$ = var;
        }
        ;

assignment
        : var_identifier __OPE_SUBST expression {
                __assignment_variable($1, 0);
        }
        | var_identifier __ARRAY_LB expression_list __ARRAY_RB __OPE_SUBST expression {
                __assignment_variable($1, $3);
        }
        ;

const_variable
        : __CONST_INTEGER {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CONSTANT;
                ec->type_specifier = TYPE_SIGNED | TYPE_INT;
                ec->type_qualifier = TYPE_CONST;
                ec->const_int = $1 << 16;
                $$ = ec;
        }
        | __CONST_FLOAT {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CONSTANT;
                ec->type_specifier = TYPE_FLOAT;
                ec->type_qualifier = TYPE_CONST;

                double a;
                double b = modf($1, &a);
                int32_t ia = ((int32_t)a) << 16;
                int32_t ib = ((int32_t)(0x0000ffff * b)) & 0x0000ffff;
                ec->const_int = ia | ib; /* 実際は固定小数なのでint */

                $$ = ec;
        }
        ;

operation
        : expression __OPE_ADD expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_ADD;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_SUB expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_SUB;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_MUL expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_MUL;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_DIV expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_DIV;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_MOD expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_MOD;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_OR expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_OR;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_AND expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_AND;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_XOR expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_XOR;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | __OPE_INVERT expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_INV;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __OPE_NOT expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_NOT;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | expression __OPE_LSHIFT expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_LSHIFT;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | expression __OPE_RSHIFT expression {
                struct EC* ec = new_ec();
                ec->type_expression = EC_CALC;
                ec->type_operator = EC_OPE_RSHIFT;
                ec->child_ptr[0] = $1;
                ec->child_ptr[1] = $3;
                ec->child_len = 2;
                $$ = ec;
        }
        | __OPE_ADD expression %prec __OPE_PLUS {
                $$ = $2;
        }
        | __OPE_SUB expression %prec __OPE_MINUS {
                struct EC* ec = new_ec();
                ec->type_expression = EC_UNARY;
                ec->type_operator = EC_OPE_SUB;
                ec->child_ptr[0] = $2;
                ec->child_len = 1;
                $$ = ec;
        }
        | __LB expression __RB {
                $$ = $2;
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
                __read_variable_ptr($2, 0);
        }
        | __OPE_ADDRESS var_identifier __ARRAY_LB expression_list __ARRAY_RB {
                __read_variable_ptr($2, $4);
        }
        | var_identifier {
                __read_variable($1, 0);
        }
        | var_identifier __ARRAY_LB expression_list __ARRAY_RB {
                __read_variable($1, $3);
        }
        | __IDENTIFIER __LB {
                /* 現在の stack_frame をプッシュする。
                 * そして、ここには関数終了後にはリターン値が入った状態となる。
                 */
                push_stack("stack_frame");
        } expression_list __RB {
                __call_user_function($1);
        }
        ;

selection_statement
        : selection_if
        ;

selection_if
        : selection_if_v __STATE_ELSE {
                pA("LB(0, %d);", $1[0]);
        } statement {
                pA("LB(0, %d);", $1[1]);
        }
        | selection_if_v {
                pA("LB(0, %d);", $1[0]);
                pA("LB(0, %d);", $1[1]);
        }
        ;

selection_if_v
        : __STATE_IF __LB expression __RB {
                const int32_t else_label = cur_label_index_head++;
                $<ival>$ = else_label;

                pop_stack("stack_socket");
                pA("if (stack_socket == 0) {");
                pA("PLIMM(P3F, %d);", else_label);
                pA("}");

        } statement {
                const int32_t end_label = cur_label_index_head++;
                $$[0] = $<ival>5;
                $$[1] = end_label;

                pA("PLIMM(P3F, %d);", end_label);
        }
        ;

iteration_statement
        : iteration_while
        | iteration_for
        ;

iteration_while
        : __STATE_WHILE __LB {
                const int32_t loop_head = cur_label_index_head++;
                $<ival>$ = loop_head;

                /* ループの復帰位置をここに設定 */
                pA("LB(0, %d);", loop_head);

        } expression __RB {
                const int32_t loop_end = cur_label_index_head++;
                $<ival>$ = loop_end;

                pop_stack("stack_socket");
                pA("if (stack_socket == 0) {");
                pA("PLIMM(P3F, %d);", loop_end);
                pA("}");

        } statement {
                /* ループの復帰 */
                pA("PLIMM(P3F, %d);", $<ival>3);

                /* 偽の場合はここへジャンプしてきて終了 */
                pA("LB(0, %d);", $<ival>6);
        }
        ;

iteration_for
        : __STATE_FOR __LB expression {
                /* スタックを掃除 */
                pop_stack("stack_socket");

                /* head ラベルID */
                int32_t loop_head = cur_label_index_head;
                cur_label_index_head++;
                $<ival>$ = loop_head;

                /* head ラベル */
                pA("LB(0, %d);", loop_head);

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
                pA("LB(0, %d);", loop_pre_head);

        } expression __RB {
                /* スタックを掃除 */
                pop_stack("stack_socket");

                /* head ラベルへジャンプ */
                pA("PLIMM(P3F, %d);", $<ival>4);

                /* main ラベル */
                pA("LB(0, %d);", $<ival>8);

        } statement {
                /* pre_head ラベルへジャンプ */
                pA("PLIMM(P3F, %d);", $<ival>10);

                /* end ラベル */
                pA("LB(0, %d);", $<ival>6);
        }

labeled_statement
        : __DEFINE_LABEL __DECL_END {
                pA("LB(1, %d);", labellist_search($1));
        }
        ;

jump_statement
        : __STATE_GOTO __LABEL __DECL_END {
                pA("PLIMM(P3F, %d);", labellist_search($2));
        }
        | __STATE_RETURN expression __DECL_END {
                pop_stack("fixA");
                __define_user_function_return();
        }
        | __STATE_RETURN __DECL_END {
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
        : __TYPE_STRUCT __IDENTIFIER __BLOCK_LB
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

inline_assembler_statement
        : __STATE_ASM __LB const_strings __RB  __DECL_END {
                pA($3);
        }
        | __STATE_ASM __LB const_strings __OPE_SUBST expression __RB __DECL_END {
                pop_stack($3);
        }
        | __STATE_ASM __LB var_identifier __OPE_SUBST const_strings __RB __DECL_END {
                push_stack($5);
                __assignment_variable($3, 0);
        }
        | __STATE_ASM __LB
          var_identifier __ARRAY_LB expression_list __ARRAY_RB
          __OPE_SUBST const_strings __RB __DECL_END {
                push_stack($8);
                __assignment_variable($3, $5);
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
        | __struct_or_union_specifier
        | __enum_specifier
        | __typedef_name
        ;

__type_qualifier
        : __TYPE_CONST          {return(TYPE_CONST);}
        | __TYPE_VOLATILE       {return(TYPE_VOLATILE);}
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
        | __CONST_STRING
        | __LB __expression __RB
        ;

__argument_expression_list
        : /* empty */
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

__identifier
        : /* empty */
        | __IDENTIFIER
        ;

%%
