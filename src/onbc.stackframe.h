#include <stdint.h>
#include "onbc.mem.h"
#include "onbc.stack.h"

#ifndef __ONBC_STACKFRAME_H__
#define __ONBC_STACKFRAME_H__

#define STACKFRAME_BEGIN_ADDRESS (MEM_SIZE - 0x10000)

void push_stackframe(const char* register_name);
void pop_stackframe(void);
void init_stackframe(void);
void debug_stackframe(const int32_t n);

#endif /* __ONBC_STACKFRAME_H__ */
