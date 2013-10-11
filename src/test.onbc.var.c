#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "onbc.print.h"
#include "onbc.iden.h"
#include "onbc.stack.h"
#include "onbc.var.h"

test01()
{
        puts("new_var()によって生成される初期状態のVarのスペックの確認");

        struct Var* var = new_var();
        var_print(var);

        putchar('\n');
}

test02()
{
        puts("varlist_scope_{push,pop}()のスタックアンダーフローエラーのテスト");

        int32_t i;
        const int32_t len = 0x1000 - 1;
        for (i = 0; i < len; i++) {
                varlist_scope_push();
        }
        printf("varlist_scope_push() * %d ... compleate\n", len);

        for (i = 0; i < len; i++) {
                varlist_scope_pop();
        }
        printf("varlist_scope_pop() * %d ... compleate\n", len);

#if 0
        varlist_scope_pop();
        puts("varlist_scope_pop()でわざとエラーを生じさせる。エラーが表示されれば正常");
        varlist_scope_pop();
#endif

        putchar('\n');
}

test03()
{
        puts("varlist_add_global()で、指定したスペックのグローバル変数が作成されるかのテスト");

        const char iden[] = "global_int_x";
        const int32_t dim_len = 5;
        int32_t unit_len[5] = {1,2,3,4,5};
        const int32_t indirect_len = 10;
        const int32_t type = TYPE_INT;

        puts("指定したスペック:");
        printf("iden[%s], dim_len[%d], "
               "unit_len[dim_len] = {1,2,3,4,5}, "
               "indirect_len[%d], type[%d]\n",
               iden, dim_len, indirect_len, type);

        varlist_add_global(iden, unit_len, dim_len, indirect_len, type);

        puts("実際に作成されたスペック:");
        struct Var* var = varlist_search(iden);
        var_print(var);
        printf("var->type & TYPE_AUTO = [%d]\n", var->type & TYPE_AUTO);

        putchar('\n');
}

test04()
{
        puts("varlist_add_global()で、指定したスペックのローカル変数が作成されるかのテスト");

        const char iden[] = "local_float_x";
        const int32_t dim_len = 5;
        int32_t unit_len[5] = {1,2,3,4,5};
        const int32_t indirect_len = 10;
        const int32_t type = TYPE_FLOAT;

        puts("指定したスペック:");
        printf("iden[%s], dim_len[%d], "
               "unit_len[dim_len] = {1,2,3,4,5}, "
               "indirect_len[%d], type[%d]\n",
               iden, dim_len, indirect_len, type);

        varlist_add_local(iden, unit_len, dim_len, indirect_len, type);

        puts("実際に作成されたスペック:");
        struct Var* var = varlist_search(iden);
        var_print(var);
        printf("var->type & TYPE_AUTO = [%d]\n", var->type & TYPE_AUTO);

        putchar('\n');
}

test05()
{
        puts("__new_var_initializer_global()で、指定したスペックのグローバル変数が作成されるかのテスト");

        struct Var* var = new_var();
        strcpy(var->iden, "global_float_x");
        var->unit_len[0] = 10;
        var->unit_len[1] = 20;
        var->unit_len[2] = 30;
        var->dim_len = 3;
        var->indirect_len = 100;

        cur_initializer_type = TYPE_FLOAT;

        puts("指定したスペック:");
        printf("var->iden[%s], var->dim_len[%d], "
               "var->unit_len[] = {10,20,30}, "
               "var->indirect_len[%d], cur_initializer_type[%d]\n",
               var->iden, var->dim_len, var->indirect_len, cur_initializer_type);

        __new_var_initializer_global(var);

        puts("実際に作成されたスペック:");
        struct Var* dst = varlist_search(var->iden);
        var_print(dst);
        printf("dst->type & TYPE_AUTO = [%d]\n", dst->type & TYPE_AUTO);

        putchar('\n');

}

test06()
{
        puts("__new_var_initializer_local()で、指定したスペックのローカル変数が作成されるかのテスト");

        struct Var* var = new_var();
        strcpy(var->iden, "local_int_x");
        var->unit_len[0] = 10;
        var->unit_len[1] = 20;
        var->unit_len[2] = 30;
        var->dim_len = 3;
        var->indirect_len = 100;

        cur_initializer_type = TYPE_INT;

        puts("指定したスペック:");
        printf("var->iden[%s], var->dim_len[%d], "
               "var->unit_len[] = {10,20,30}, "
               "var->indirect_len[%d], cur_initializer_type[%d]\n",
               var->iden, var->dim_len, var->indirect_len, cur_initializer_type);

        __new_var_initializer_local(var);

        puts("実際に作成されたスペック:");
        struct Var* dst = varlist_search(var->iden);
        var_print(dst);
        printf("dst->type & TYPE_AUTO = [%d]\n", dst->type & TYPE_AUTO);

        putchar('\n');

}

FILE* yyaskA;
int32_t linenumber = 0;
char filepath[] = "empty";

int main(int argc, char** argv)
{
        yyaskA = fopen("test.onbc.var.ask", "wt");

        test01();
        test02();
        test03();
        test04();
        test05();
        test06();

        return EXIT_SUCCESS;
}
