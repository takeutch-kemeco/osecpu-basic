#ifndef __ONBC_IDEN_H__
#define __ONBC_IDEN_H__

#define IDENLIST_STR_LEN 0x100

void idenlist_push(const char* src);
void idenlist_pop(char* dst);

#endif /* __ONBC_IDEN_H__ */
