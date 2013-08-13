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

%}

%x linelist_process
%x pre_process
%x pre_process_def
%x main_process
%x main_process_comment

%%

<linelist_process>^.*[\n] {
        linelist[linenumber] = malloc(yyleng + 1);
        strcpy(linelist[linenumber], yytext);
        linenumber++;
}

<pre_process>"function"         BEGIN(pre_process_def);
<pre_process>"def"              BEGIN(pre_process_def);
<pre_process_def>[_a-zA-Z][_0-9a-zA-Z]* {labellist_add(yytext); BEGIN(pre_process);}

<pre_process>^[*][_a-zA-Z][_0-9a-zA-Z]* {labellist_add(yytext);}
<pre_process>"end"[ ]*"function" {}
<pre_process>.                  {}

<main_process>^"rem"            BEGIN(main_process_comment);
<main_process_comment>[\n]      {linenumber++; BEGIN(main_process);}
<main_process_comment>.         {}

<main_process>["].*["]          {strncpy(yylval.sval, yytext + 1, strlen(yytext + 1) - 1); return(__CONST_STRING);}

<main_process>[0][0-9]+[.]?[0-9]* {printf("%s\n構文エラー : 数値の先頭に不適切な 0 があります\n", yytext); exit(EXIT_FAILURE);}
<main_process>[0-9]* {yylval.ival = atoi(yytext); return(__CONST_INTEGER);}
<main_process>[0-9]+[.][0-9]+ {yylval.fval = atof(yytext); return(__CONST_FLOAT);}

<main_process>"+"       return(__OPE_ADD);
<main_process>"-"       return(__OPE_SUB);
<main_process>"*"       return(__OPE_MUL);
<main_process>"/"       return(__OPE_DIV);
<main_process>"mod"     return(__OPE_MOD);

<main_process>"^"       return(__OPE_POWER);

<main_process>"or"      return(__OPE_OR);
<main_process>"and"     return(__OPE_AND);
<main_process>"xor"     return(__OPE_XOR);
<main_process>"not"     return(__OPE_NOT);

<main_process>":="      return(__OPE_SUBST);

<main_process>"="       return(__OPE_COMPARISON);
<main_process>"<>"      return(__OPE_NOT_COMPARISON);

<main_process>"<"       return(__OPE_ISSMALL);
<main_process>"<="      return(__OPE_ISSMALL_COMP);
<main_process>"=<"      return(__OPE_ISSMALL_COMP);

<main_process>">"       return(__OPE_ISLARGE);
<main_process>">="      return(__OPE_ISLARGE_COMP);
<main_process>"=>"      return(__OPE_ISLARGE_COMP);

<main_process>"("       return(__LB);
<main_process>")"       return(__RB);

<main_process>[\n]      {linenumber++; return(__DECL_END);}
<main_process>";"       return(__DECL_END);

<main_process>"if"      return(__STATE_IF);
<main_process>"then"    return(__STATE_THEN);
<main_process>"else"    return(__STATE_ELSE);

<main_process>"for"     return(__STATE_FOR);
<main_process>"to"      return(__STATE_TO);
<main_process>"step"    return(__STATE_STEP);
<main_process>"next"    return(__STATE_NEXT);

<main_process>"end"     return(__STATE_END);

<main_process>"read"    return(__STATE_READ);
<main_process>"data"    return(__STATE_DATA);

<main_process>"let"     return(__STATE_LET);
<main_process>"dim"     return(__STATE_DIM);

<main_process>"mat"     return(__STATE_MAT);
<main_process>"zer"     return(__STATE_MAT_ZER);
<main_process>"con"     return(__STATE_MAT_CON);
<main_process>"idn"     return(__STATE_MAT_IDN);
<main_process>"trn"     return(__STATE_MAT_TRN);

<main_process>"function"                return(__STATE_FUNCTION);
<main_process>"end"[ ]*"function"       return(__STATE_END_FUNCTION);

<main_process>"def"     return(__STATE_DEF);
<main_process>","       return(__OPE_COMMA);

<main_process>"on"      return(__OPE_ON);
<main_process>"goto"    return(__OPE_GOTO);
<main_process>"gosub"   return(__OPE_GOSUB);
<main_process>"return"  return(__OPE_RETURN);

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

<main_process>"drawline" return(__FUNC_DRAWLINE);

<main_process>[_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__IDENTIFIER);}

<main_process>^[*][_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__DEFINE_LABEL);}
<main_process>[*][_a-zA-Z][_0-9a-zA-Z]* {strcpy(yylval.sval, yytext); return(__LABEL);}

<main_process>.         {}
<main_process><<EOF>>   return(__EOF);

%%

void start_linelist_process(void) {linenumber = 1; BEGIN(linelist_process);}
void start_pre_process(void) {linenumber = 1; BEGIN(pre_process);}
void start_main_process(void) {linenumber = 1; BEGIN(main_process);}
