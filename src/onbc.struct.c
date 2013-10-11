/* onbc.struct.c
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "onbc.var.h"
#include "onbc.struct.h"

/* 構造体メンバースペックのメモリー領域を確保し、値をセットし、アドレスを返す
 */
struct Var*
structmemberspec_new(const char* iden,
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
void structmemberspec_print(struct Var* member, const char* tab)
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
void structspec_print(struct StructSpec* spec, const char* tab)
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
struct Var* structspec_search(struct StructSpec* spec, const char* iden)
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
void structspec_add_member(struct StructSpec* spec, struct Var* member)
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
struct StructSpec* structspec_new(void)
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
void structspec_set_iden(struct StructSpec* spec, const char* iden)
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
struct StructSpec* structspec_ptrlist[STRUCTSPEC_PTRLIST_LEN];

/* 現在の構造体スペックのポインターリストの先頭位置 */
static int32_t cur_structspec_ptrlist_head = 0;

/* 構造体スペックのポインターリストから、任意の名前の構造体スペックが登録されてるかを調べてアドレスを返す。
 * 無ければ NULL を返す。
 */
struct StructSpec* structspec_ptrlist_search(const char* iden)
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
void structspec_ptrlist_print(void)
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
void structspec_ptrlist_add(struct StructSpec* spec)
{
        if (structspec_ptrlist_search(spec->iden) != NULL)
                yyerror("syntax err: 構造体のメンバー名が重複しています");

        structspec_ptrlist[cur_structspec_ptrlist_head] = spec;
        cur_structspec_ptrlist_head++;

#ifdef DEBUG_STRUCTSPEC_PTRLIST
        structspec_ptrlist_print();
#endif /* DEBUG_STRUCTSPEC_PTRLIST */
}
