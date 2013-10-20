#ifndef __ONBC_STACKFRAME_H__
#define __ONBC_STACKFRAME_H__

void push_stackframe(const char* register_name);
void pop_stackframe(void);
void init_stackframe(void);

#endif /* __ONBC_STACKFRAME_H__ */
