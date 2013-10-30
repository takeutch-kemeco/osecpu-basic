#include "onbc.var.h"

#ifndef __ONBC_DOUBLE_H__
#define __ONBC_DOUBLE_H__

void __func_add_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_sub_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_mul_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_div_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_mod_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_minus_double(struct Var* avar, const char* areg,
                         const char* lreg, const char* rreg);
void __func_and_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_or_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_xor_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_invert_double(struct Var* avar, const char* areg,
                          const char* lreg, const char* rreg);
void __func_lshift_double(struct Var* avar, const char* areg,
                          const char* lreg, const char* rreg);
void __func_rshift_double(struct Var* avar, const char* areg,
                          const char* lreg, const char* rreg);
void __func_not_double(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_eq_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_ne_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_lt_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_gt_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_le_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_ge_double(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);

#endif /* __ONBC_DOUBLE_H__ */
