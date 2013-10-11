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
#include "onbc.label.h"
#include "onbc.eoe.h"
#include "onbc.func.h"
#include "onbc.int.h"
#include "onbc.float.h"
#include "onbc.acm.h"
#include "onbc.cast.h"
#include "onbc.ec.h"

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

/* 全ての初期化
 */
void init_all(void)
{
        pA("#include \"osecpu_ask.h\"\n");

        pA("LOCALLABELS(%d);\n", LABEL_INDEX_LEN);

        init_mem();
        init_heap();
        init_stack();
        init_labelstack();
        init_eoe_arg();
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
