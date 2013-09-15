/* osecpubasic.flex.l
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
#include "osecpubasic.bison.h"

/* 現在のプロセスを示すフラグ
 */
#define PRE_PROCESS 0x01
#define MAIN_PROCESS 0x02
static int32_t cur_process;

char filepath[0x1000];
int32_t linenumber;

FILE* yyaskA;
FILE* yyaskB;

/* 前後をダブルクオートで囲まれた文字列から、それを取り除く。
 * dst には十分な長さのバッファーを渡すこと。
 */
static void trim_const_string(char* dst, char* src)
{
        const int32_t trimlen = strlen(src) - 2;
        src += 1;
        strncpy(dst, src, trimlen);
        dst[trimlen] = '\0';
}

/* #include 関連
 */

#define INCLUDE_DEPTH_MAX 0x10
static YY_BUFFER_STATE include_stack[INCLUDE_DEPTH_MAX];
static int32_t linenumber_stack[INCLUDE_DEPTH_MAX];
static char filepath_stack[INCLUDE_DEPTH_MAX][0x1000];
static int32_t cur_include_stack = 0;

/* 現在の字句解析をスタックし、字句解析を yytext が示すファイルへと切り替える。
 * include は INCLUDE_DEPTH_MAX 回まで入れ子にできる。
 */
static void push_include(void)
{
        if (cur_include_stack >= INCLUDE_DEPTH_MAX)
                yyerror("syntax err: #include が可能なネストは 16 段までです");

        strcpy(filepath_stack[cur_include_stack], filepath);
        trim_const_string(filepath, yytext);

        linenumber_stack[cur_include_stack] = linenumber;
        linenumber = 1;

        include_stack[cur_include_stack] = YY_CURRENT_BUFFER;
        cur_include_stack++;

        yyin = fopen(filepath, "rt");
        if (yyin == NULL)
                yyerror("syntax err: #include で指定されたファイルのオープンに失敗しました");

        yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));
}

/* 現在の字句解析をポップし、字句解析を filepath_stack[cur_include_stack] が示すファイルへと切り替える。
 * 字句解析ファイルがルートファイルの状態でこの関数を実行した場合は -1 が返る。
 */
static int32_t pop_include(void)
{
        cur_include_stack--;
        if (cur_include_stack < 0) {
                cur_include_stack = 0;
                return -1;
        }

        yy_delete_buffer(YY_CURRENT_BUFFER);
        yy_switch_to_buffer(include_stack[cur_include_stack]);
        strcpy(filepath, filepath_stack[cur_include_stack]);
        linenumber = linenumber_stack[cur_include_stack];

        return 0;
}

/* #define 関連
 */

/* #define 識別子と、その置換コードのペア
 */
struct DefineMacro {
        char* iden;
        char* replace;
};

/* 識別子と、その置換コードのペアのテーブル
 */
static struct DefineMacro define_table[0x10000];
static int32_t cur_define_iden = 0;

/* "define の字句解析時に、最新の識別子を保持しておくバッファー。
 * これは、#define の解析を構文解析側へ持っていかずに、字句解析段階で済ましてしまう為のハック。
 *
 * 今得た最新の #define 識別子を保持しておくためのバッファー
 */
static char define_iden_tmp[0x10000];

/* define_table に対象識別子が存在しているかを調べて、もし存在すれば、対応する置換コードのアドレスを返す。
 * 存在しなければ NULL を返す。
 *
 * 識別子検索は新しく登録された側から検索してくる。
 * その為、同名の識別子が複数あった場合は、もっとも新しく登録された識別子が該当となる。
 */
static char* search_iden_define_table(char* iden)
{
        int i = cur_define_iden;
        while (i-->0) {
                if (strcmp(iden, define_table[i].iden) == 0)
                        return define_table[i].replace;
        }

        return NULL;
}

/* define_table にマクロ（識別子と、その置換コードのペア）を追加する
 * replace が NULL の場合は '\0' がセットされる
 */
static void add_macro_define_table(char* iden, char* replace)
{
        struct DefineMacro* p = define_table + cur_define_iden;

        p->iden = malloc(strlen(iden) + 1);
        strcpy(p->iden, iden);

        if (replace != NULL) {
                p->replace = malloc(strlen(replace) + 1);
                strcpy(p->replace, replace);
        } else {
                p->replace = malloc(sizeof(char));
                p->replace[0] = '\0';
        }

        cur_define_iden++;
}

/* define_table から対象識別子の要素を全て削除する
 * 実際には該当要素の iden に '\0' をセットするだけ。（メモリーの free() などは行わない）
 *
 * 引数の iden が [0] == \0 または NULL の場合は何もしない
 */
static void remove_macro_define_table(char* iden)
{
        if (iden[0] == '\0' || iden == NULL)
                return;

        int i = cur_define_iden;
        while (i-->0) {
                if (strcmp(iden, define_table[i].iden) == 0)
                        define_table[i].iden[0] = '\0';
        }
}

/* define_table から全ての識別子を削除する
 */
static void init_define_table(void)
{
        int i = cur_define_iden;
        while (i-->0) {
                if (define_table[i].iden != NULL) {
                        free(define_table[i].iden);
                        define_table[i].iden = NULL;
                }

                if (define_table[i].replace != NULL) {
                        free(define_table[i].replace);
                        define_table[i].replace = NULL;
                }
        }

        cur_define_iden = 0;
}

/* #ifdef 関連
 */

/* #ifdef（または #ifdef）のスキッププロセスを開始する際に 0 をセットする。
 *
 * #ifdef（または #ifndef）によるスキップ中に、再び #ifdef（または #ifndef）が登場する度に +=1 する。
 * そして、スキップ中に #endif が登場する度に -=1 する。
 *
 * これによって、 0 の時点で登場した #endif が、スキップの本当の終了ポイントであることを判断できる。
 */
static int32_t cur_ifdef_skip_depth;

%}

%x pre_process
%x pre_process_function
%x pre_process_include

%x pre_process_define_iden
%x pre_process_define_replace
%x pre_process_undef_iden
%x pre_process_ifndef_iden
%x pre_process_ifdef_iden
%x pre_process_ifdef_skip

%x pre_process_comment_c
%x pre_process_comment_b

%x main_process
%x main_process_include

%x tune_process

%%

<main_process>"//"              BEGIN(pre_process_comment_b);
<pre_process>"//"               BEGIN(pre_process_comment_b);
<pre_process_comment_b>.*[\n] {
        linenumber++;

        if (cur_process == PRE_PROCESS)
                BEGIN(pre_process);
        else if (cur_process == MAIN_PROCESS)
                BEGIN(main_process);
        else
                yyerror("system err: pre_process_comment_b");
}

<main_process>"/*"              BEGIN(pre_process_comment_c);
<pre_process>"/*"               BEGIN(pre_process_comment_c);
<pre_process_comment_c>[\n]       {linenumber++;}
<pre_process_comment_c>.          {}
<pre_process_comment_c>"*/" {
        if (cur_process == PRE_PROCESS)
                BEGIN(pre_process);
        else if (cur_process == MAIN_PROCESS)
                BEGIN(main_process);
        else
                yyerror("system err: pre_process_comment_c");
}

<main_process>"#define" BEGIN(pre_process_define_iden);
<pre_process>"#define" BEGIN(pre_process_define_iden);
<pre_process_define_iden>[_a-zA-Z][_0-9a-zA-Z]* {
#ifdef DEBUG_DEFINE
        printf("process[%d], pre_process_define_iden[%s]\n", cur_process, yytext);
#endif /* DEBUG_DEFINE */

        strcpy(define_iden_tmp, yytext);
        BEGIN(pre_process_define_replace);
}
<pre_process_define_replace>[\n] {
#ifdef DEBUG_DEFINE
        printf("process[%d], pre_process_define_replace, \\n [%s]\n", cur_process, "");
#endif /* DEBUG_DEFINE */

        linenumber++;

        char tmp[2] = "";
        add_macro_define_table(define_iden_tmp, tmp);

        if (cur_process == PRE_PROCESS)
                BEGIN(pre_process);
        else if (cur_process == MAIN_PROCESS)
                BEGIN(main_process);
        else
                yyerror("system err: pre_process_define_replace");
}
<pre_process_define_replace>[^ \n].*[^\n] {
#ifdef DEBUG_DEFINE
        printf("process[%d], pre_process_define_replace, etc [%s]\n", cur_process, yytext);
#endif /* DEBUG_DEFINE */

        add_macro_define_table(define_iden_tmp, yytext);

        if (cur_process == PRE_PROCESS)
                BEGIN(pre_process);
        else if (cur_process == MAIN_PROCESS)
                BEGIN(main_process);
        else
                yyerror("system err: pre_process_define_replace");
}

<main_process>"#undef" BEGIN(pre_process_undef_iden);
<pre_process>"#undef" BEGIN(pre_process_undef_iden);
<pre_process_undef_iden>[_a-zA-Z][_0-9a-zA-Z]* {
#ifdef DEBUG_DEFINE
        printf("process[%d], pre_process_undef_iden[%s]\n", cur_process, yytext);
#endif /* DEBUG_DEFINE */

        remove_macro_define_table(yytext);

        if (cur_process == PRE_PROCESS)
                BEGIN(pre_process);
        else if (cur_process == MAIN_PROCESS)
                BEGIN(main_process);
        else
                yyerror("system err: pre_process_undef_iden");
}

<main_process>"#ifdef" BEGIN(pre_process_ifdef_iden);
<pre_process>"#ifdef" BEGIN(pre_process_ifdef_iden);
<pre_process_ifdef_iden>[_a-zA-Z][_0-9a-zA-Z]* {
#ifdef DEBUG_DEFINE
        printf("process[%d], pre_process_ifdef_iden[%s], ", cur_process, yytext);
#endif /* DEBUG_DEFINE */

        if (search_iden_define_table(yytext) == NULL) {
#ifdef DEBUG_DEFINE
                printf("[skip]\n");
#endif /* DEBUG_DEFINE */

                cur_ifdef_skip_depth = 0;
                BEGIN(pre_process_ifdef_skip);
        } else {
#ifdef DEBUG_DEFINE
                printf("[no skip]\n");
#endif /* DEBUG_DEFINE */

                if (cur_process == PRE_PROCESS)
                        BEGIN(pre_process);
                else if (cur_process == MAIN_PROCESS)
                        BEGIN(main_process);
                else
                        yyerror("system err: pre_process_ifdef_iden");
        }
}

<main_process>"#ifndef" BEGIN(pre_process_ifndef_iden);
<pre_process>"#ifndef" BEGIN(pre_process_ifndef_iden);
<pre_process_ifndef_iden>[_a-zA-Z][_0-9a-zA-Z]* {
#ifdef DEBUG_DEFINE
        printf("process[%d], pre_process_ifndef_iden[%s], ", cur_process, yytext);
#endif /* DEBUG_DEFINE */

        if (search_iden_define_table(yytext) != NULL) {
#ifdef DEBUG_DEFINE
                printf("[skip]\n");
#endif /* DEBUG_DEFINE */

                cur_ifdef_skip_depth = 0;
                BEGIN(pre_process_ifdef_skip);
        } else {
#ifdef DEBUG_DEFINE
                printf("[no skip]\n");
#endif /* DEBUG_DEFINE */

                if (cur_process == PRE_PROCESS)
                        BEGIN(pre_process);
                else if (cur_process == MAIN_PROCESS)
                        BEGIN(main_process);
                else
                        yyerror("system err: pre_process_ifndef_iden");
        }
}

<main_process>"#endif" {}
<pre_process>"#endif" {}
<pre_process_ifdef_skip>"#endif" {
        if (cur_ifdef_skip_depth == 0) {
                if (cur_process == PRE_PROCESS)
                        BEGIN(pre_process);
                else if (cur_process == MAIN_PROCESS)
                        BEGIN(main_process);
                else
                        yyerror("system err: pre_process_ifndef_skip");
        } else {
                cur_ifdef_skip_depth--;
        }
}
<pre_process_ifdef_skip>"#ifdef" {printf("\nQQQQQQ\n\n"); cur_ifdef_skip_depth++;}
<pre_process_ifdef_skip>"#ifndef" {printf("\nQQQQQQ\n\n");cur_ifdef_skip_depth++;}
<pre_process_ifdef_skip>[\n] {linenumber++;}
<pre_process_ifdef_skip>. {}

<pre_process>"function" BEGIN(pre_process_function);
<pre_process_function>[_a-zA-Z][_0-9a-zA-Z]* {labellist_add(yytext); BEGIN(pre_process);}

<pre_process>^[*][_a-zA-Z][_0-9a-zA-Z]* {labellist_add(yytext);}
<pre_process>. {}

<pre_process>"#include" BEGIN(pre_process_include);
<pre_process_include>["][^"]+["] {
        push_include();
        BEGIN(pre_process);
}

<pre_process><<EOF>> {
        if (pop_include() == -1)
                yyterminate();
}

<main_process>["][^"]*["] {
        /* const string */
        trim_const_string(yylval.sval, yytext);
        return(__CONST_STRING);
}

<main_process>['][^']['] {
        /* const char */
        yylval.sval[0] = yytext[0];
        yylval.sval[1] = '\0';
        return(__CONST_CHAR);
}

<main_process>[0][0-7]+ {
        /* 8進数の場合 */
        yylval.ival = strtol(yytext, NULL, 8);
        return(__CONST_INTEGER);
}

<main_process>[0][xX][0-9a-fA-F]+ {
        /* 16進数の場合 */
        yylval.ival = strtol(yytext, NULL, 16);
        return(__CONST_INTEGER);
}

<main_process>([0]|[1-9][0-9]*) {
        /* 10進数の場合 */
        yylval.ival = strtol(yytext, NULL, 10);
        return(__CONST_INTEGER);
}

<main_process>[0-9]+[.][0-9]+ {
        /* 実数の場合 */
        yylval.fval = atof(yytext);
        return(__CONST_FLOAT);
}

<main_process>"+"       return(__OPE_ADD);
<main_process>"-"       return(__OPE_SUB);
<main_process>"*"       return(__OPE_MUL);
<main_process>"/"       return(__OPE_DIV);
<main_process>"%"       return(__OPE_MOD);

<main_process>"|"       return(__OPE_OR);
<main_process>"and"     return(__OPE_AND);
<main_process>"^"       return(__OPE_XOR);
<main_process>"~"       return(__OPE_INVERT);
<main_process>"!"       return(__OPE_NOT);

<main_process>"||"      return(__OPE_LOGICAL_OR);
<main_process>"&&"      return(__OPE_LOGICAL_AND);

<main_process>"<<"      return(__OPE_LSHIFT);
<main_process>">>"      return(__OPE_RSHIFT);
<main_process>">>>"     return(__OPE_ARITHMETIC_RSHIFT);

<main_process>"@"       return(__OPE_ATTACH);
<main_process>"&"       return(__OPE_ADDRESS);

<main_process>"="       return(__OPE_SUBST);
<main_process>"&="      return(__OPE_AND_SUBST);
<main_process>"|="      return(__OPE_OR_SUBST);
<main_process>"^="      return(__OPE_XOR_SUBST);
<main_process>"<<="     return(__OPE_LSHIFT_SUBST);
<main_process>">>="     return(__OPE_RSHIFT_SUBST);
<main_process>"+="      return(__OPE_ADD_SUBST);
<main_process>"-="      return(__OPE_SUB_SUBST);
<main_process>"*="      return(__OPE_MUL_SUBST);
<main_process>"/="      return(__OPE_DIV_SUBST);
<main_process>"%="      return(__OPE_MOD_SUBST);

<main_process>"++"      return(__OPE_INC);
<main_process>"--"      return(__OPE_DEC);

<main_process>"=="      return(__OPE_COMPARISON);
<main_process>"!="      return(__OPE_NOT_COMPARISON);

<main_process>"<"       return(__OPE_ISSMALL);
<main_process>"<="      return(__OPE_ISSMALL_COMP);

<main_process>">"       return(__OPE_ISLARGE);
<main_process>">="      return(__OPE_ISLARGE_COMP);

<main_process>"("       return(__LB);
<main_process>")"       return(__RB);

<main_process>"{"       return(__BLOCK_LB);
<main_process>"}"       return(__BLOCK_RB);

<main_process>"["       return(__ARRAY_LB);
<main_process>"]"       return(__ARRAY_RB);

<main_process>[\n]      {linenumber++;}
<main_process>";"       return(__DECL_END);

<main_process>"if"      return(__STATE_IF);
<main_process>"else"    return(__STATE_ELSE);

<main_process>"switch"  return(__STATE_SWITCH);
<main_process>"case"    return(__STATE_CASE);
<main_process>"default" return(__STATE_DEFAULT);

<main_process>"?"       return(__OPE_SELECTION);

<main_process>"while"   return(__STATE_WHILE);
<main_process>"do"      return(__STATE_DO);

<main_process>"for"     return(__STATE_FOR);

<main_process>"read"    return(__STATE_READ);
<main_process>"data"    return(__STATE_DATA);

<main_process>"dim"     return(__STATE_DIM);

<main_process>"void"    return(__TYPE_VOID);
<main_process>"char"    return(__TYPE_CHAR);
<main_process>"short"   return(__TYPE_SHORT);
<main_process>"int"     return(__TYPE_INT);
<main_process>"long"    return(__TYPE_LONG);
<main_process>"float"   return(__TYPE_FLOAT);
<main_process>"double"  return(__TYPE_DOUBLE);
<main_process>"signed"  return(__TYPE_SIGNED);
<main_process>"unsigned" return(__TYPE_UNSIGNED);

<main_process>"const"   return(__TYPE_CONST);
<main_process>"volatile" return(__TYPE_VOLATILE);

<main_process>"auto"    return(__TYPE_AUTO);
<main_process>"register" return(__TYPE_REGISTER);
<main_process>"static"  return(__TYPE_STATIC);
<main_process>"extern"  return(__TYPE_EXTERN);
<main_process>"typedef" return(__TYPE_TYPEDEF);

<main_process>"sizeof"  return(__OPE_SIZEOF);

<main_process>"struct"  return(__STATE_STRUCT);
<main_process>"enum"  return(__STATE_ENUM);

<main_process>"function" {return(__STATE_FUNCTION);}

<main_process>","       return(__OPE_COMMA);
<main_process>":"       return(__OPE_COLON);
<main_process>"..."     return(__OPE_VALEN);
<main_process>"->"      return(__OPE_ARROW);
<main_process>"."       return(__OPE_DOT);

<main_process>"goto"    return(__STATE_GOTO);
<main_process>"return"  return(__STATE_RETURN);
<main_process>"continue" return(__STATE_CONTINUE);
<main_process>"break"   return(__STATE_BREAK);

<main_process>"asm"     return(__STATE_ASM);

<main_process>"filltri" return(__FUNC_FILLTRI);

<main_process>[_a-zA-Z][_0-9a-zA-Z]* {
        char* replace = search_iden_define_table(yytext);

        if (replace == NULL) {
                strcpy(yylval.sval, yytext);
                return(__IDENTIFIER);
        } else {
                int32_t i = strlen(replace);
                while (i-->0)
                        yyunput(replace[i], yytext);

        }
}

<main_process>^[*][_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__DEFINE_LABEL);}
<main_process>[*][_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__LABEL);}

<main_process>. {}

<main_process>"#include" BEGIN(main_process_include);
<main_process_include>["][^"]+["] {
        push_include();
        BEGIN(main_process);
}

<main_process><<EOF>> {
        if (pop_include() == -1)
                return(__EOF);
}

<tune_process>"stack_socket++;"[ \n]*"stack_socket--;" {}
<tune_process>"attachstack_socket++;"[ \n]*"attachstack_socket--;" {}
<tune_process>"labelstack_socket++;"[ \n]*"labelstack_socket--;" {}
<tune_process>"heap_socket++;"[ \n]*"heap_socket--;" {}

<tune_process>"stack_head++;"[ \n]*"stack_head--;" {}
<tune_process>"attachstack_head++;"[ \n]*"attachstack_head--;" {}
<tune_process>"labelstack_head++;"[ \n]*"labelstack_head--;" {}
<tune_process>"heap_head++;"[ \n]*"heap_head--;" {}

<tune_process>^[\n]     {}
<tune_process>.*        {fprintf(yyaskB, "%s\n", yytext);}

%%

void start_pre_process(const char* __filepath)
{
        strcpy(filepath, __filepath);
        linenumber = 1;
        init_define_table();
        cur_process = PRE_PROCESS;
        BEGIN(pre_process);
}

void start_main_process(const char* __filepath)
{
        strcpy(filepath, __filepath);
        linenumber = 1;
        init_define_table();
        cur_process = MAIN_PROCESS;
        BEGIN(main_process);
}

void start_tune_process(void)
{
        YY_NEW_FILE;
        BEGIN(tune_process);
}
