#include <stdint.h>
#include "onbc.iden.h"

#ifndef __ONBC_VAR_H__
#define __ONBC_VAR_H__

/* 変数型の識別フラグ
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
#define TYPE_LITERAL    (1 << 29)
#define TYPE_FUNCTION   (1 << 30)

/* コンパイル時点に確定する変数スペック
 */
#define VAR_DIM_MAX 0x100
struct Var {
        char iden[IDENLIST_STR_LEN];
        int32_t base_ptr;       /* ベースアドレス */
        int32_t total_len;      /* 配列変数全体の長さ */
        int32_t unit_len[VAR_DIM_MAX];  /* 各配列次元の長さ */
        int32_t dim_len;        /* 配列の次元数 */
        int32_t indirect_len;   /* 間接参照の深さ。直接参照(非ポインター型)ならば0 */
        int32_t type;           /* specifier | qualifier | storage_class による変数属性 */
        int32_t is_lvalue;      /* この変数が値を間接参照で得る場合(左辺値)は1。
                                 * 即値で得る場合(右辺値)は0。
                                 */
        void* const_variable;   /* 変数が定数の場合の値 */
};

extern int32_t cur_initializer_type;

void var_print(struct Var* var);
struct Var* new_var(void);
void var_pop_stack(struct Var* var, const char* register_name);
void varlist_scope_push(void);
void varlist_scope_pop(void);
struct Var* varlist_search_common(const char* iden, const int32_t varlist_bottom);
struct Var* varlist_search_global(const char* iden);
struct Var* varlist_search_local(const char* iden);
struct Var* varlist_search(const char* iden);
void varlist_add_common(const char* iden,
                        int32_t* unit_len,
                        const int32_t dim_len,
                        const int32_t indirect_len,
                        const int32_t type);
void varlist_add_global(const char* str,
                        int32_t* unit_len,
                        const int32_t dim_len,
                        const int32_t indirect_len,
                        const int32_t type);
void varlist_add_local(const char* str,
                       int32_t* unit_len,
                       const int32_t dim_len,
                       const int32_t indirect_len,
                       const int32_t type);
void varlist_set_scope_head(void);
struct Var* __new_var_initializer_local(struct Var* var);
struct Var* __new_var_initializer_global(struct Var* var);
struct Var* __new_var_initializer(struct Var* var);

#endif /* __ONBC_VAR_H__ */
