#include <stdint.h>
#include "onbc.var.h"

#ifndef __ONBC_STRUCT_H__
#define __ONBC_STRUCT_H__

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

#define STRUCTSPEC_PTRLIST_LEN 0x1000
extern struct StructSpec* structspec_ptrlist[STRUCTSPEC_PTRLIST_LEN];

struct Var*
structmemberspec_new(const char* iden,
                     int32_t* unit_len,
                     const int32_t dim_len,
                     const int32_t indirect_len,
                     const int32_t type);
void structmemberspec_print(struct Var* member, const char* tab);
void structspec_print(struct StructSpec* spec, const char* tab);
struct Var* structspec_search(struct StructSpec* spec, const char* iden);
void structspec_add_member(struct StructSpec* spec, struct Var* member);
struct StructSpec* structspec_new(void);
void structspec_set_iden(struct StructSpec* spec, const char* iden);
struct StructSpec* structspec_ptrlist_search(const char* iden);
void structspec_ptrlist_print(void);
void structspec_ptrlist_add(struct StructSpec* spec);

#endif /* __ONBC_STRUCT_H__ */
