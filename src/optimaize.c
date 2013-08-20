#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifndef NO_STATIC

static int32_t cur_label_index_head = 1024;
#define CUR_RETURN_LABEL "P02"

#endif /* NO_STATIC */

/* 文字列の len 行先のアドレスを得る
 * 成功でアドレス、範囲外の場合は NULL を返す。
 */
static char* optima_seek_line(char* str, int32_t len)
{
        int i;
        for (i = 0; i < len; i++) {
                while (1) {
                        char tmp = *str++;

                        if (tmp == '\0')
                                return NULL;

                        if (tmp == '\n')
                                break;
                }
        }

        return str;
}

/* 文字列 src から len 行を dst へコピーする
 * dstは十分な長さのバッファーであること。
 * 成功で src 読み込み後の次の位置のアドレスを返す。範囲外の場合は NULL を返す。
 *
 * src の 10 行目から 3 行分をコピーしたい場合等は optima_seek_line() と組み合わせればよい
 */
static char* optima_copy_line(char* dst, char* src, int32_t len)
{
        int i;
        for (i = 0; i < len; i++) {
                while (1) {
                        char tmp = *src++;
                        *dst++ = tmp;

                        if (tmp == '\0')
                                return NULL;

                        if (tmp == '\n')
                                break;
                }
        }

        *dst = '\0';

        return src;
}

/* 文字列 a b を len 行比較して、完全に一致していたら 1 を返す。
 * 一致しなければ -1 を返す
 */
static int optima_comparison(char* a, char* b, int32_t len)
{
        while (len > 0) {
                if (*a != *b)
                        return 0;

                if (*a == '\n' || *a == '\0')
                        len--;

                a++;
                b++;
        }

        return 1;
}

/* 文字列の正規化
 * 連続した空白の削除
 * 連続した改行の削除
 */
static void optima_normal(char* str)
{
        char* src = str;
        char* dst = str;

        *dst = *src;
        src++;

        while (1) {
                if (*dst == '\n' && *src == '\n') {
                } else if (*dst == ' ' && *src == ' ') {
                } else {
                        dst++;
                        *dst = *src;
                }

                src++;

                if (*src == '\0') {
                        dst++;
                        *dst = '\0';
                        return;
                }
        }
}

/* src の len 行分を、 func ラベル定義命令と、リターン命令によって囲み、dst へ書き出す。
 * (サブファンクションとして書き出す)
 *
 * func_label で渡された番号をラベル番号として用いる
 *
 * スタックからレジスターへのリターンラベルのポップに関しては、osecpu-basicのlabelstackに依存
 */
static int optima_add_func(char* dst, char* src, int32_t len, int32_t func_label)
{
        char tmp[0x1000];

        sprintf(tmp, "LB(0, %d);\n", func_label);
        strcat(dst, tmp);

        if (optima_copy_line(tmp, src, len) == NULL) {
                printf("optimazer err: optima_add_func()\n");
                exit(EXIT_FAILURE);
        }
        strcat(dst, tmp);

        sprintf(tmp,
                "labelstack_head--;\n"
                "PAPLMEM0(labelstack_socket, T_VPTR, labelstack_ptr, labelstack_head);\n"
                "PCP(P3F, %s);\n",
                CUR_RETURN_LABEL);
        strcat(dst, tmp);

        return 0;
}

/* fp funcラベルへのジャンプ命令と、returnラベル定義する命令を書き出す
 *
 * レジスターからスタックへのリターンラベルのプッシュに関しては、osecpu-basicのlabelstackに依存
 */
static int optima_add_call(char* dst, int32_t func_label)
{
        char tmp[0x200];
        sprintf(tmp,
                "PLIMM(%s, %d);\n"
                "PAPSMEM0(labelstack_socket, T_VPTR, labelstack_ptr, labelstack_head);\n"
                "labelstack_head++;\n"
                "PLIMM(P3F, %d);\n"
                "LB(0, %d);\n",
                CUR_RETURN_LABEL,
                cur_label_index_head,
                func_label,
                cur_label_index_head);
        strcat(dst, tmp);

        cur_label_index_head++;

        return 0;
}

/* テキストファイルを dst へ読み込む
 * dst_lenには、dstの使用可能な最大サイズを渡す
 *
 * 成功した場合は 0、エラーの場合は -1 が返る
 */
static int optima_fopen(char* dst, int32_t dst_len, char* file_name)
{
        FILE* fp = fopen(file_name, "rt");
        if (fp == NULL) {
                printf("optimaize err: optima_fopen(), file_name\n");
                exit(EXIT_FAILURE);
        }

        int i;
        for (i = 0; i < dst_len; i++) {
                int c = fgetc(fp);

                if (c == EOF)
                        break;

                *dst++ = c;
        }

        fclose(fp);

        *dst = '\0';

        return 0;
}

/* src をテキストファイルへ書き込む
 * src_lenには、srcのありうる最大サイズを渡す
 *
 * 成功した場合は 0、エラーの場合は -1 が返る
 */
static int optima_fwrite(char* src, int32_t src_len, char* file_name)
{
        FILE* fp = fopen(file_name, "wt");
        if (fp == NULL) {
                printf("optimaize err: optima_fwrite(), file_name\n");
                exit(EXIT_FAILURE);
        }

        int i;
        for (i = 0; i < src_len; i++) {
                int c = *src++;

                if (c == '\0')
                        break;

                fputc(c, fp);
        }

        fclose(fp);

        return 0;
}

/* 文字列 a, b について、
 * bのindex番目からlen個の文字列を x として、
 * a 中に x と完全に一致する箇所の個数を返す。
 *
 * なお、a内で、一致する箇所同士は重複しないように判別される
 *
 * エラーの場合は -1 を返す
 */
static int optima_comparison_full(char* a, char* b, int32_t index, int32_t len)
{
        b = optima_seek_line(b, index);
        if (b == NULL)
                return -1;

        int32_t count = 0;

        while (1) {
                if (optima_comparison(a, b, len) == 1) {
                        count++;
                        a = optima_seek_line(a, len);
                } else {
                        a = optima_seek_line(a, 1);
                }

                if (a == NULL)
                        break;
        }

        return count;
}

/* optima_comparison_full() の結果において 2個以上一致した場合に、この関数を用いてソース分割する
 *
 * tmpAには元ソースから重複部分を関数呼び出しに置き換えたもの
 * tmpBには、関数化された重複部分
 * が、それぞれ出力される
 *
 * エラーの場合は -1 を返す
 */
static int optima_strip(char* tmpA, char* tmpB, char* a, char* b, int32_t index, int32_t len)
{
        b = optima_seek_line(b, index);
        if (b == NULL)
                return -1;

        const int32_t func_label = cur_label_index_head;
        cur_label_index_head++;

        int32_t func_init = 0;

        while (1) {
                if (optima_comparison(a, b, len) == 1) {
                        if (func_init == 0) {
                                optima_add_func(tmpB, b, len, func_label);
                                func_init = 1;
                        }

                        optima_add_call(tmpA, func_label);

                        a = optima_seek_line(a, len);

                } else {
                        char tmp[0x1000];
                        optima_copy_line(tmp, a, 1);
                        strcat(tmpA, tmp);

                        a = optima_seek_line(a, 1);
                }

                if (a == NULL)
                        break;
        }

        return 0;
}

main()
{
        char* optima_in = malloc(0x100000);

        char* optima_tmpA = malloc(0x100000);
        char* optima_tmpB = malloc(0x100000);
        optima_tmpA[0] = '\0';
        optima_tmpB[0] = '\0';

        optima_fopen(optima_in, 0x100000, "wire2.ask");

        optima_normal(optima_in);

        char* seekA = optima_in;
        char* seekB = optima_in;

        int32_t window = 10;
        int32_t cur_index = 2030;

        {
                int32_t match = optima_comparison_full(seekA, seekB, cur_index, window);
                if (match >= 2) {
                        optima_strip(optima_tmpA, optima_tmpB, seekA, seekB, cur_index, window);

//                      printf("%s", optima_tmpA);
//                      printf("%s", optima_tmpB);
                        strcpy(optima_in, optima_tmpA);
                        strcat(optima_in, optima_tmpB);
                }
        }

        optima_fwrite(optima_in, 0x100000, "wire2x.ask");
}
