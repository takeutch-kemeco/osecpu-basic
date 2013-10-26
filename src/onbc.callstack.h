#include "onbc.mem.h"

#ifndef __ONBC_CALLSTACK_H__
#define __ONBC_CALLSTACK_H__

#define CALLSTACK_BEGIN_ADDRESS (MEM_SIZE - 0x30000)

void push_callstack(const char* register_name);
void pop_callstack(const char* register_name);
void init_callstack(void);

#endif /* __ONBC_CALLSTACK_H__ */
