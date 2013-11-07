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
#define TYPE_CONST      (1 << 18)
#define TYPE_CONST_PTR  (1 << 19)
#define TYPE_VOLATILE   (1 << 20)

/* 記憶領域クラス
 */
#define TYPE_ARRAY      (1 << 22)
#define TYPE_WIND       (1 << 23)
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
        int32_t base_ptr;       /* この変数が値の記録に用いる記憶域の先頭アドレス */
        int32_t unit_total_len; /* 配列変数全体の長さ */
        int32_t unit_len[VAR_DIM_MAX];  /* 各配列次元の長さ */
        int32_t dim_len;        /* 配列の次元数 */
        int32_t indirect_len;   /* 間接参照の深さ。直接参照(非ポインター型)ならば0 */
        int32_t type;           /* specifier | qualifier | storage_class による変数属性 */
        int32_t is_lvalue;      /* この変数が値を間接参照で得る場合(左辺値)は1。
                                 * 即値で得る場合(右辺値)は0。
                                 */
        void* const_variable;   /* 変数が定数の場合の値 */
};

extern int32_t next_local_varlist_add_set_new_scope;

void var_print(struct Var* var);
struct Var* var_set_param(struct Var* var,
                          const char* iden,
                          const int32_t base_ptr,
                          int32_t* unit_len,
                          const int32_t dim_len,
                          const int32_t unit_total_len,
                          const int32_t indirect_len,
                          const int32_t type,
                          const int32_t is_lvalue,
                          void* const_valiable);
struct Var* new_var(void);
void free_var(struct Var* var);
void var_read_value(struct Var* var, const char* register_name);
void var_read_value_dummy(struct Var* var);
void var_read_address(struct Var* var, const char* register_name);
void var_indirect_read_value(struct Var* var, const char* register_name);
void local_varlist_scope_push(void);
void local_varlist_scope_pop(void);
int32_t var_get_type_to_size(struct Var* var);
struct Var* global_varlist_search(const char* iden);
struct Var* varlist_search(const char* iden);
struct Var* var_initializer_new(struct Var* var, const int32_t type);
struct Var* var_clear_type(struct Var* var);
struct Var* var_normalization_type(struct Var* var);
int32_t var_is_integral(struct Var* var);
int32_t var_is_floating(struct Var* var);
int32_t var_is_void(struct Var* var);

#endif /* __ONBC_VAR_H__ */
