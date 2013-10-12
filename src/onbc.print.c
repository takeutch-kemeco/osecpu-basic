/* onbc.print.c
 * Copyright (C) 2013 Takeutch Kemeco
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>

extern char filepath[0x1000];
extern int32_t linenumber;

/* 現在の filepath のファイル中から、line行目を文字列として dst へ読み出す。
 * dst には十分な長さのバッファーを渡すこと。
 *
 * line が 1 未満、または EOF 以降の場合は -1 を返す。
 *
 * これは主にエラー表示時に、補助的な情報として表示する文字列用。
 * メインの字句解析や構文解析に用いるような用途には使ってない。
 */
int32_t read_line_file(char* dst, const int32_t line)
{
        if (line < 1)
                return -1;

        FILE* fp = fopen(filepath, "rt");

        /* 目的行までシーク
         */
        int i = line - 1;
        while (i-->0) {
                while (1) {
                        int c = fgetc(fp);
                        if (c == '\n')
                                break;

                        if (c == EOF)
                                return -1;
                }
        }

        /* 改行、または EOF までを dst へ読み出す
         */
        while (1) {
                int c = fgetc(fp);
                if (c == '\n' || c == EOF)
                        break;

                *dst++ = c;
        }

        *dst = '\0';

        fclose(fp);
        return 0;
}

/* 警告表示 */
void yywarning(const char *error_message)
{
        printf("filepath: %s\n", filepath);

        /* エラー行と、その前後 3 行を表示する
         */
        char tmp[0x1000];
        int i;
        for (i = -3; i <= +3; i++) {
                if (read_line_file(tmp, linenumber + i) != -1)
                        printf("%6d: %s\n", linenumber + i, tmp);
        }

        printf("line: %d\n", linenumber);
        printf("%s\n\n", error_message);
}

/* エラー表示 */
void yyerror(const char *error_message)
{
        yywarning(error_message);
        exit(EXIT_FAILURE);
}

extern FILE* yyin;
extern FILE* yyout;
extern FILE* yyaskA;
extern FILE* yyaskB;

/* 出力ファイル yyaskA へ文字列を書き出す関数 */
void pA(const char* fmt, ...)
{
        va_list ap;
        va_start(ap, fmt);

        vfprintf(yyaskA, fmt, ap);
        va_end(ap);

        fputs("\n", yyaskA);
}

/* 出力ファイル yyaskA へ文字列を書き出す関数（改行無し）
 *
 * 主に } else { 用。
 * （elseを挟む中括弧を改行をするとエラーになるので）
 */
void pA_nl(const char* fmt, ...)
{
        va_list ap;
        va_start(ap, fmt);

        vfprintf(yyaskA, fmt, ap);
        va_end(ap);
}

/* レジスターの内容を実行時にコンソールへ印字する命令を yyaskAへ書き出す
 * 主にデバッグ用
 */
void pA_reg(const char* register_name)
{
        pA("junkApi_putConstString('%s:[');", register_name);
        pA("junkApi_putStringDec('\1', %s, 11, 0);", register_name);
        pA("junkApi_putConstString(']\\n');");
}
