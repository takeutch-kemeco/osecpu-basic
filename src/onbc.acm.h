#include "onbc.var.h"

#ifndef __ONBC_ACM_H__
#define __ONBC_ACM_H__

typedef void (*acm_func)(struct Var* avar,
                         const char* areg,
                         const char* lreg,
                         const char* rreg);

struct Var*
__var_func_add_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_sub_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_mul_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_div_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_mod_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_minus_new(const char* areg,
                     struct Var* lvar, const char* lreg);
struct Var*
__var_func_and_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_or_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_xor_new(const char* areg,
                   struct Var* lvar, const char* lreg,
                   struct Var* rvar, const char* rreg);
struct Var*
__var_func_invert_new(const char* areg,
                      struct Var* lvar, const char* lreg);
struct Var*
__var_func_lshift_new(const char* areg,
                      struct Var* lvar, const char* lreg,
                      struct Var* rvar, const char* rreg);
struct Var*
__var_func_rshift_new(const char* areg,
                      struct Var* lvar, const char* lreg,
                      struct Var* rvar, const char* rreg);
struct Var*
__var_func_not_new(const char* areg,
                   struct Var* lvar, const char* lreg);
struct Var*
__var_func_eq_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_ne_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_lt_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_gt_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_le_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_ge_new(const char* areg,
                  struct Var* lvar, const char* lreg,
                  struct Var* rvar, const char* rreg);
struct Var*
__var_func_assignment_new(const char* areg,
                          struct Var* lvar, const char* lreg,
                          struct Var* rvar, const char* rreg);

#endif /* __ONBC_ACM_H__ */
