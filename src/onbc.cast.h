#include "onbc.var.h"

#ifndef __ONBC_CAST_H__
#define __ONBC_CAST_H__

struct Var* var_cast_new(struct Var* var1, struct Var* var2);
void cast_regval(const char* register_name,
                 struct Var* dst_var,
                 struct Var* src_var);

#endif /* __ONBC_CAST_H__ */
