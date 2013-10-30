#include "onbc.var.h"

#ifndef __ONBC_UINT_H__
#define __ONBC_UINT_H__

void __func_add_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_sub_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_mul_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_div_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_mod_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_minus_uint(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_and_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_or_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_xor_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_invert_uint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg);
void __func_lshift_uint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg);
void __func_rshift_uint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg);
void __func_not_uint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_eq_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_ne_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_lt_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_gt_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_le_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_ge_uint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);

#endif /* __ONBC_UINT_H__ */
