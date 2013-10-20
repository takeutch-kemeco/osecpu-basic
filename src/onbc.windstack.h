#include "onbc.mem.h"

#ifndef __ONBC_WINDSTACK_H__
#define __ONBC_WINDSTACK_H__

#define WINDSTACK_BEGIN_ADDRESS (MEM_SIZE - 0x20000)

void push_windstack(const char* register_name);
void pop_windstack(const char* register_name);
void init_windstack(void);

#endif /* __ONBC_WINDSTACK_H__ */
