#include "onbc.var.h"

#ifndef __ONBC_CAST_H__
#define __ONBC_CAST_H__

struct Var* new_var_binary_type_promotion(struct Var* lvar, struct Var* rvar);
void cast_regval(struct Var* lvar, struct Var* rvar, const char* rreg);

#endif /* __ONBC_CAST_H__ */
