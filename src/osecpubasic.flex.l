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

int32_t linenumber;
char* linelist[0x10000];

FILE* yyaskA;
FILE* yyaskB;

#define INCLUDE_DEPTH_MAX 0x10
static YY_BUFFER_STATE include_stack[INCLUDE_DEPTH_MAX];
static int32_t cur_include_stack = 0;

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

%}

%x linelist_process
%x pre_process
%x pre_process_function
%x pre_process_include
%x main_process
%x main_process_comment
%x main_process_include
%x tune_process

%%

<linelist_process>^.*[\n] {
        linelist[linenumber] = malloc(yyleng + 1);
        strcpy(linelist[linenumber], yytext);
        linenumber++;
}

<pre_process>"function" BEGIN(pre_process_function);
<pre_process_function>[_a-zA-Z][_0-9a-zA-Z]* {labellist_add(yytext); BEGIN(pre_process);}

<pre_process>^[*][_a-zA-Z][_0-9a-zA-Z]* {labellist_add(yytext);}
<pre_process>. {}

<pre_process>"#include" BEGIN(pre_process_include);
<pre_process_include>["][^"]+["] {
        char filepath[0x1000];
        trim_const_string(filepath, yytext);

        if (cur_include_stack >= INCLUDE_DEPTH_MAX) {
                printf("syntax err: #include が可能なネストは %d 段までです\n", INCLUDE_DEPTH_MAX);
                exit(EXIT_FAILURE);
        }

        include_stack[cur_include_stack] = YY_CURRENT_BUFFER;
        cur_include_stack++;

        yyin = fopen(filepath, "rt");
        if (yyin == NULL) {
                printf("syntax err: #include で指定されたファイル %s のオープンに失敗しました\n", filepath);
                exit(EXIT_FAILURE);
        }

        yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));

        BEGIN(pre_process);
}

<pre_process><<EOF>> {
        cur_include_stack--;
        if (cur_include_stack < 0) {
                cur_include_stack = 0;
                yyterminate();
        } else {
                yy_delete_buffer(YY_CURRENT_BUFFER);
                yy_switch_to_buffer(include_stack[cur_include_stack]);
        }
}

<main_process>"//".*[\n]        {linenumber++;}

<main_process>"/*"              BEGIN(main_process_comment);
<main_process_comment>[\n]      {linenumber++;}
<main_process_comment>.         {}
<main_process_comment>"*/"      BEGIN(main_process);

<main_process>["][^"]*["]       {trim_const_string(yylval.sval, yytext); return(__CONST_STRING);}

<main_process>[0][0-9]+[.]?[0-9]* {printf("%s\n構文エラー : 数値の先頭に不適切な 0 があります\n", yytext); exit(EXIT_FAILURE);}
<main_process>[0-9]* {yylval.ival = atoi(yytext); return(__CONST_INTEGER);}
<main_process>[0-9]+[.][0-9]+ {yylval.fval = atof(yytext); return(__CONST_FLOAT);}

<main_process>"+"       return(__OPE_ADD);
<main_process>"-"       return(__OPE_SUB);
<main_process>"*"       return(__OPE_MUL);
<main_process>"/"       return(__OPE_DIV);
<main_process>"%"       return(__OPE_MOD);

<main_process>"pow"     return(__OPE_POWER);

<main_process>"|"       return(__OPE_OR);
<main_process>"and"     return(__OPE_AND);
<main_process>"^"       return(__OPE_XOR);
<main_process>"~"       return(__OPE_NOT);

<main_process>"<<"      return(__OPE_LSHIFT);
<main_process>">>"      return(__OPE_LOGICAL_RSHIFT);
<main_process>">>>"     return(__OPE_ARITHMETIC_RSHIFT);

<main_process>"@"       return(__OPE_ATTACH);
<main_process>"&"       return(__OPE_ADDRESS);

<main_process>"="       return(__OPE_SUBST);

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

<main_process>"while"   return(__STATE_WHILE);

<main_process>"for"     return(__STATE_FOR);

<main_process>"read"    return(__STATE_READ);
<main_process>"data"    return(__STATE_DATA);

<main_process>"let"     return(__STATE_LET);
<main_process>"dim"     return(__STATE_DIM);

<main_process>"mat"     return(__STATE_MAT);
<main_process>"zer"     return(__STATE_MAT_ZER);
<main_process>"con"     return(__STATE_MAT_CON);
<main_process>"idn"     return(__STATE_MAT_IDN);
<main_process>"trn"     return(__STATE_MAT_TRN);

<main_process>"function" {return(__STATE_FUNCTION);}

<main_process>","       return(__OPE_COMMA);
<main_process>":"       return(__OPE_COLON);

<main_process>"goto"    return(__OPE_GOTO);
<main_process>"return"  return(__OPE_RETURN);

<main_process>"asm"     return(__STATE_ASM);

<main_process>"print"   return(__FUNC_PRINT);
<main_process>"input"   return(__FUNC_INPUT);
<main_process>"peek"    return(__FUNC_PEEK);
<main_process>"poke"    return(__FUNC_POKE);
<main_process>"chr$"    return(__FUNC_CHR_S);
<main_process>"val"     return(__FUNC_VAL);
<main_process>"mid$"    return(__FUNC_MID_S);
<main_process>"rnd"     return(__FUNC_RND);
<main_process>"input$"  return(__FUNC_INPUT_S);

<main_process>"sin"     return(__FUNC_SIN);
<main_process>"cos"     return(__FUNC_COS);
<main_process>"tan"     return(__FUNC_TAN);
<main_process>"sqrt"    return(__FUNC_SQRT);

<main_process>"openwin"         return(__FUNC_OPENWIN);
<main_process>"torgb"           return(__FUNC_TORGB);
<main_process>"drawpoint"       return(__FUNC_DRAWPOINT);
<main_process>"drawline"        return(__FUNC_DRAWLINE);
<main_process>"filltri"         return(__FUNC_FILLTRI);
<main_process>"fillrect"        return(__FUNC_FILLRECT);
<main_process>"sleep"           return(__FUNC_SLEEP);

<main_process>[_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__IDENTIFIER);}

<main_process>^[*][_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__DEFINE_LABEL);}
<main_process>[*][_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__LABEL);}

<main_process>. {}

<main_process>"#include" BEGIN(main_process_include);
<main_process_include>["][^"]+["] {
        char filepath[0x1000];
        trim_const_string(filepath, yytext);

        if (cur_include_stack >= INCLUDE_DEPTH_MAX) {
                printf("syntax err: #include が可能なネストは %d 段までです\n", INCLUDE_DEPTH_MAX);
                exit(EXIT_FAILURE);
        }

        include_stack[cur_include_stack] = YY_CURRENT_BUFFER;
        cur_include_stack++;

        yyin = fopen(filepath, "rt");
        if (yyin == NULL) {
                printf("syntax err: #include で指定されたファイル %s のオープンに失敗しました\n", filepath);
                exit(EXIT_FAILURE);
        }

        yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));

        BEGIN(main_process);
}

<main_process><<EOF>> {
        cur_include_stack--;
        if (cur_include_stack < 0) {
                return(__EOF);
        } else {
                yy_delete_buffer(YY_CURRENT_BUFFER);
                yy_switch_to_buffer(include_stack[cur_include_stack]);
        }
}

<tune_process>"stack_socket++;"[ \n]*"stack_socket--;" {}
<tune_process>"attachstack_socket++;"[ \n]*"attachstack_socket--;" {}
<tune_process>"labelstack_socket++;"[ \n]*"labelstack_socket--;" {}
<tune_process>"heap_socket++;"[ \n]*"heap_socket--;" {}

<tune_process>"stack_head++;"[ \n]*"stack_head--;" {}
<tune_process>"attachstack_head++;"[ \n]*"attachstack_head--;" {}
<tune_process>"labelstack_head++;"[ \n]*"labelstack_head--;" {}
<tune_process>"heap_head++;"[ \n]*"heap_head--;" {}

<tune_process>"PASMEM0(stack_socket, T_SINT32, stack_ptr, stack_head);"[ \n]*"PALMEM0(stack_socket, T_SINT32, stack_ptr, stack_head);" {
}

<tune_process>"PASMEM0(stack_socket, T_SINT32, stack_ptr, stack_head);"[ \n]*"PALMEM0(heap_offset, T_SINT32, stack_ptr, stack_head);" {
        fprintf(yyaskB,
                "PASMEM0(stack_socket, T_SINT32, stack_ptr, stack_head);\n"
                "heap_offset = stack_socket;\n");
}

<tune_process>"PASMEM0(stack_socket, T_SINT32, attachstack_ptr, attachstack_head);"[ \n]*"PALMEM0(matbpR, T_SINT32, attachstack_ptr, attachstack_head);" {
        fprintf(yyaskB,
                "PASMEM0(stack_socket, T_SINT32, attachstack_ptr, attachstack_head);\n"
                "matbpR = stack_socket;\n");
}

<tune_process>"heap_offset = matcountrow << 16;"[ \n]*"heap_base = matbpA;"[ \n]*"heap_offset >>= 16;"[ \n]*"heap_offset &= 0x0000ffff;" {
        fprintf(yyaskB,
                "heap_offset = matcountrow & 0x0000ffff;\n"
                "heap_base = matbpA;\n");
}

<tune_process>"heap_offset = matcountrow << 16;"[ \n]*"heap_base = matbpL;"[ \n]*"heap_offset >>= 16;"[ \n]*"heap_offset &= 0x0000ffff;" {
        fprintf(yyaskB,
                "heap_offset = matcountrow & 0x0000ffff;\n"
                "heap_base = matbpL;\n");
}

<tune_process>"heap_offset = matcountrow << 16;"[ \n]*"heap_base = matbpR;"[ \n]*"heap_offset >>= 16;"[ \n]*"heap_offset &= 0x0000ffff;" {
        fprintf(yyaskB,
                "heap_offset = matcountrow & 0x0000ffff;\n"
                "heap_base = matbpR;\n");
}

<tune_process>"heap_offset <<= 16;"[ \n]*"heap_base = matbpA;"[ \n]*"heap_offset >>= 16;"[ \n]*"heap_offset &= 0x0000ffff;" {
        fprintf(yyaskB,
                "heap_offset &= 0x0000ffff;\n"
                "heap_base = matbpA;\n");
}

<tune_process>"heap_offset >>= 16;"[ \n]*"heap_offset &= 0x0000ffff;" {
        fprintf(yyaskB,
                "heap_offset >>= 16;\n");
}

<tune_process>^[\n]     {}
<tune_process>.*        {fprintf(yyaskB, "%s\n", yytext);}

%%

void start_linelist_process(void) {linenumber = 1; BEGIN(linelist_process);}
void start_pre_process(void) {linenumber = 1; BEGIN(pre_process);}
void start_main_process(void) {linenumber = 1; BEGIN(main_process);}
void start_tune_process(void) {YY_NEW_FILE; BEGIN(tune_process);}
