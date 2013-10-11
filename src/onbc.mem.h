#ifndef __ONBC_MEM_H__
#define __ONBC_MEM_H__

#define MEM_SIZE (0x400000)

void init_mem(void);
void write_mem(const char* regname_data,
               const char* regname_address);
void read_mem(const char* regname_data,
              const char* regname_address);
void init_heap(void);
void debug_heap(void);

#endif /* __ONBC_MEM_H__ */
