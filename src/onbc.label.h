#include <stdint.h>

#ifndef __ONBC_LABEL_H__
#define __ONBC_LABEL_H__

/* ラベルの使用可能最大数 */
#define LABEL_INDEX_LEN 2048

/* gosub での return 先ラベルの保存用に使うポインターレジスター */
#define CUR_RETURN_LABEL "P03"

extern int32_t cur_label_index_head;

int32_t labellist_search_unsafe(const char* str);
int32_t labellist_search(const char* str);
void labellist_add(const char* str);
void push_labelstack(void);
void pop_labelstack(void);
void init_labelstack(void);

#endif /* __ONBC_LABEL_H__ */
