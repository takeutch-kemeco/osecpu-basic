#ifndef __ONBC_STACK_H__
#define __ONBC_STACK_H__

void push_stack(const char* regname_data);
void pop_stack(const char* regname_data);
void push_stack_dummy(void);
void pop_stack_dummy(void);
void init_stack(void);
void debug_stack(void);
void debug_stack_frame(void);

#endif /* __ONBC_STACK_H__ */
