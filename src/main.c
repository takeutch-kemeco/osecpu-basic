/* main.c
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
#include <unistd.h>
#include "config.h"

extern FILE* yyin;
extern FILE* yyout;
extern FILE* yyaskA;

static void print_usage(void)
{
        printf("使用法: %s 入力ファイル.bas [出力ファイル.ask]\n"
               "\n"
               "%s version %s\n"
               "Copyright(C) 2013 Takeutch Kemeco\n"
               "GNU General Public License version 2\n"
               "This is free software; see the source for copying conditions.  There is NO\n"
               "warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n"
               "[参考訳 -- 法的効力は英文が適用されます]\n"
               "これはフリーソフトウェアです -- 複製についての条件はソースを見ましょう。\n"
               "一切の保証はありません -- 商業性や目的適合性についての保証すらありません。\n"
               "\n"
               "repository: <https://github.com/takeutch-kemeco/osecpu-basic>\n"
               "bug report: <%s>\n",
               PACKAGE_NAME,
               PACKAGE_NAME, VERSION,
               PACKAGE_BUGREPORT);
}

static void print_file_open_err(const char* s)
{
        printf("ファイル %s のオープンでエラーが発生しました。中止します。\n", s);
}

static FILE* open_in_file(const char* in_path)
{
        FILE* fp = fopen(in_path, "rt");
        if (fp == NULL) {
                print_file_open_err(in_path);
                print_usage();
                exit(EXIT_FAILURE);
        }

        return fp;
}

static FILE* open_null_out_file(void)
{
        FILE* fp = fopen("/dev/null", "w");
        if (fp == NULL) {
                print_file_open_err("/dev/null");
                print_usage();
                exit(EXIT_FAILURE);
        }

        return fp;
}

static FILE* open_out_file(const char* out_path)
{
        FILE* fp = fopen(out_path, "wt");
        if (fp == NULL) {
                print_file_open_err(out_path);
                print_usage();
                exit(EXIT_FAILURE);
        }

        return fp;
}

static int path_to_filename(char* dst, char* src)
{
        char* p = src;
        char* head = src;

        while (*p != '\0') {
                if (*p++ == '/')
                        head = p;
        }

        strcpy(dst, head);
}

static int swap_filename_extention_bas_to_ask(char* a)
{
        size_t len = strlen(a);
        if (strcat(a + len - 3, "bas") == 0) {
                printf("読み込もうとしてるソースファイルの拡張子が bas ではありません\n");
                print_usage();
                exit(EXIT_FAILURE);
        }

        strcpy(a + len - 3, "ask");
}

int main(int argc, char** argv)
{
        char* in_path = argv[1];
        char out_path[0x1000];

        switch (argc) {
        case 2:
                path_to_filename(out_path, in_path);
                swap_filename_extention_bas_to_ask(out_path);
                break;

        case 3:
                strcpy(out_path, argv[2]);
                break;

        default:
                print_usage();
                exit(EXIT_FAILURE);
        }

        yyin = open_in_file(in_path);
        yyout = open_null_out_file();
        yyaskA = open_out_file(out_path);

        start_linelist_process();
        while (yylex() != 0) {
        }

        fseek(yyin, 0, SEEK_SET);
        yyrestart(yyin);

        start_pre_process();
        while (yylex() != 0) {
        }

        fseek(yyin, 0, SEEK_SET);
        yyrestart(yyin);

        init_all();
        start_main_process();
        yyparse();

        return EXIT_SUCCESS;
}
