#include "onbc.var.h"

#ifndef __ONBC_PTR_H__
#define __ONBC_PTR_H__

void __func_add_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_sub_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_mul_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_div_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_mod_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_minus_ptr(struct Var* avar, const char* areg,
                      const char* lreg, const char* rreg);
void __func_and_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_or_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);
void __func_xor_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_invert_ptr(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_lshift_ptr(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_rshift_ptr(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_not_ptr(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_eq_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);
void __func_ne_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);
void __func_lt_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);
void __func_gt_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);
void __func_le_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);
void __func_ge_ptr(struct Var* avar, const char* areg,
                   const char* lreg, const char* rreg);

#endif /* __ONBC_PTR_H__ */
