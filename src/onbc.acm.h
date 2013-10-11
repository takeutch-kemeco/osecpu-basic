#include "onbc.var.h"
#include "onbc.int.h"
#include "onbc.float.h"

#ifndef __ONBC_ACM_H__
#define __ONBC_ACM_H__

typedef void (*void_func)(void);

struct Var*
__var_binary_operation_new(struct Var* var1,
                           struct Var* var2,
                           void_func __func_int,
                           void_func __func_char,
                           void_func __func_short,
                           void_func __func_long,
                           void_func __func_float,
                           void_func __func_double,
                           void_func __func_ptr);
struct Var*
__var_unary_operation_new(struct Var* var1,
                          void_func __func_int,
                          void_func __func_char,
                          void_func __func_short,
                          void_func __func_long,
                          void_func __func_float,
                          void_func __func_double,
                          void_func __func_ptr);
struct Var* __var_func_add_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_sub_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_mul_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_div_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_mod_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_minus_new(struct Var* var1);
struct Var* __var_func_and_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_or_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_xor_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_invert_new(struct Var* var1);
struct Var* __var_func_lshift_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_rshift_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_not_new(struct Var* var1);
struct Var* __var_func_eq_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_ne_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_lt_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_gt_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_le_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_ge_new(struct Var* var1, struct Var* var2);
struct Var* __var_func_assignment_new(struct Var* var1, struct Var* var2);

#endif /* __ONBC_ACM_H__ */
