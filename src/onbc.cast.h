#include "onbc.var.h"

#ifndef __ONBC_CAST_H__
#define __ONBC_CAST_H__

struct Var* new_var_binary_type_promotion(struct Var* var_a, struct Var* var_b);
void cast_regval(const char* register_name,
                 struct Var* dst_var,
                 struct Var* src_var);

#endif /* __ONBC_CAST_H__ */
