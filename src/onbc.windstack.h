#include <stdint.h>

#ifndef __ONBC_WINDSTACK_H__
#define __ONBC_WINDSTACK_H__

void push_windstack(const int32_t size);
int32_t pop_windstack(void);
void nest_windstack(void);
void init_windstack(void);

#endif /* __ONBC_WINDSTACK_H__ */
