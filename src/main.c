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
#include "config.h"

static void print_usage(void)
{
        printf("使用法: %s [入力ファイル]\n"
               "\n"
               "%s version %s\n"
               "Copyright(C) 2013 Takeutch Kemeco\n"
               "GNU General Public License version 2\n"
               "\n"
               "repository: <https://github.com/takeutch-kemeco/osecpu-basic>\n"
               "bug report: <%s>\n",
               PACKAGE_NAME,
               PACKAGE_NAME, VERSION,
               PACKAGE_BUGREPORT);
}

static void print_file_open_err(char* s)
{
        printf("ファイル %s のオープンでエラーが発生しました。中止します。\n", s);
}

static FILE* open_in_file(int argc, char** argv)
{
        if (argc == 1) {
                print_usage();
                exit(EXIT_FAILURE);
        }

        FILE* fp = fopen(argv[1], "rt");
        if (fp == NULL) {
                print_file_open_err(argv[1]);
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

static FILE* open_out_file(int argc, char** argv)
{
        char* bas_name = argv[1];
        char ask_name[0x1000];
        strcpy(ask_name, bas_name);
        strcat(ask_name, ".ask");

        FILE* fp = fopen(ask_name, "wt");
        if (fp == NULL) {
                print_file_open_err(ask_name);
                print_usage();
                exit(EXIT_FAILURE);
        }

        return fp;
}

extern FILE* yyin;
extern FILE* yyout;
extern FILE* yyaskA;

int main(int argc, char** argv)
{
        yyin = open_in_file(argc, argv);
        yyout = open_null_out_file();
        yyaskA = open_out_file(argc, argv);

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
