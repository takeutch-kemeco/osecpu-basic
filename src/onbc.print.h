#include <stdint.h>

#ifndef __ONBC_PRINT_H__
#define __ONBC_PRINT_H__

int32_t read_line_file(char* dst, const int32_t line);
void yywarning(const char *error_message);
void yyerror(const char *error_message);
void pA(const char* fmt, ...);
void pA_nl(const char* fmt, ...);
void pA_mes(const char* str);
void pA_reg(const char* register_name);

#endif /* __ONBC_PRINT_H__ */
