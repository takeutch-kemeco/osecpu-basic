#include "onbc.var.h"

#ifndef __ONBC_SINT_H__
#define __ONBC_SINT_H__

void __func_add_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_sub_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_mul_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_div_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_mod_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_minus_sint(struct Var* avar, const char* areg,
                       const char* lreg, const char* rreg);
void __func_and_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_or_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_xor_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_invert_sint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg);
void __func_lshift_sint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg);
void __func_rshift_sint(struct Var* avar, const char* areg,
                        const char* lreg, const char* rreg);
void __func_not_sint(struct Var* avar, const char* areg,
                     const char* lreg, const char* rreg);
void __func_eq_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_ne_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_lt_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_gt_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_le_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);
void __func_ge_sint(struct Var* avar, const char* areg,
                    const char* lreg, const char* rreg);

#endif /* __ONBC_SINT_H__ */
