#include <stdint.h>
#include "onbc.var.h"

#ifndef __ONBC_EC_H__
#define __ONBC_EC_H__

/* ExpressionContainer 関連
 */

/* EC の演算種類を示すフラグ
 */
#define EC_ASSIGNMENT           1       /* 代入 */
#define EC_CONDITIONAL          3       /* (a == b) ? x : y; 構文による分岐 */
#define EC_CALC                 5       /* 二項演算。論理演算(a || b など)も含む */
#define EC_UNARY                7       /* 前置演算子による演算 */
#define EC_POSTFIX              8       /* 後置演算子による演算 */
#define EC_PRIMARY              9       /* 参照演算 */
#define EC_CONSTANT             10      /* 定数 */
#define EC_CAST                 11      /* 型変換 */
#define EC_ARGUMENT_EXPRESSION_LIST 12  /* 関数コール時の引数リスト */
#define EC_EXPRESSION           13      /* expression単位 */
#define EC_EXPRESSION_STATEMENT 14      /* expression命令 */
#define EC_INLINE_ASSEMBLER_STATEMENT 15 /* inline_assembler命令 */
#define EC_JUMP_STATEMENT       16      /* jump命令 */
#define EC_ITERATION_STATEMENT  17      /* 反復命令 */
#define EC_SELECTION_STATEMENT  18      /* 分岐命令 */
#define EC_COMPOUND_STATEMENT   19      /* 命令ブロック */
#define EC_LABELED_STATEMENT    20      /* ラベル定義命令 */
#define EC_STATEMENT            21      /* 命令単位 */
#define EC_STATEMENT_LIST       22      /* 命令リスト */
#define EC_DECLARATION          23      /* 宣言命令単位 */
#define EC_DECLARATION_LIST     24      /* 宣言命令リスト */
#define EC_INIT_DECLARATOR      25      /* 初期宣言単位 */
#define EC_INIT_DECLARATOR_LIST 26      /* 初期化宣言リスト */
#define EC_DECLARATOR           27      /* 宣言単位 */
#define EC_DIRECT_DECLARATOR    28      /* 間接参照を伴わない宣言単位 */
#define EC_PARAMETER_TYPE_LIST  29      /* 関数引数リストのラッパー */
#define EC_PARAMETER_LIST       30      /* 関数引数リスト */
#define EC_PARAMETER_DECLARATION 31     /* 関数引数の宣言命令単位 */
#define EC_FUNCTION_DEFINITION  32      /* 関数定義 */

/* EC の演算子を示すフラグ
 */
#define EC_OPE_MUL              1
#define EC_OPE_DIV              2
#define EC_OPE_MOD              3
#define EC_OPE_ADD              4
#define EC_OPE_SUB              5
#define EC_OPE_LSHIFT           6
#define EC_OPE_RSHIFT           7
#define EC_OPE_AND              8
#define EC_OPE_OR               9
#define EC_OPE_XOR              10
#define EC_OPE_INV              29      /* ~ */
#define EC_OPE_NOT              11      /* ! */
#define EC_OPE_EQ               12      /* == */
#define EC_OPE_NE               13      /* != */
#define EC_OPE_LT               14      /* < */
#define EC_OPE_GT               15      /* > */
#define EC_OPE_LE               16      /* <= */
#define EC_OPE_GE               17      /* >= */
#define EC_OPE_LOGICAL_AND      18      /* && */
#define EC_OPE_LOGICAL_OR       19      /* || */
#define EC_OPE_INC              20      /* ++ */
#define EC_OPE_DEC              21      /* -- */
#define EC_OPE_ADDRESS          22      /* & によるアドレス取得 */
#define EC_OPE_POINTER          23      /* ポインター * によるアクセス */
#define EC_OPE_SIZEOF           24      /* sizeof */
#define EC_OPE_ARRAY            25      /* [] による配列アクセス */
#define EC_OPE_FUNCTION         26      /* f() による関数コール */
#define EC_OPE_DIRECT_STRUCT    27      /* . による構造体メンバーへの直接アクセス */
#define EC_OPE_INDIRECT_STRUCT  28      /* -> による構造体メンバーへの間接アクセス */
#define EC_OPE_VARIABLE         29      /* 変数アクセス */
#define EC_OPE_SUBST            30      /* = */
#define EC_OPE_LIST             31      /* , によって列挙されたリスト */
#define EC_OPE_GOTO             33
#define EC_OPE_RETURN           34
#define EC_OPE_ASM_STATEMENT    35      /* アセンブラ命令リスト */
#define EC_OPE_ASM_SUBST_VTOR   36      /* 変数からレジスターへの代入 */
#define EC_OPE_ASM_SUBST_RTOV   37      /* レジスターから変数への代入 */
#define EC_OPE_IF               38
#define EC_OPE_WHILE            39
#define EC_OPE_DO_WHILE         40
#define EC_OPE_FOR              41

/* EC (ExpressionContainer)
 * 構文解析の expression_statement 以下から終端記号までの情報を保持するためのコンテナ
 *
 * type_operator: 演算子
 * type_expression: 演算種類
 * child_ptr[]: この EC をルートとして広がる枝ECへのポインター
 * child_len: child_ptr[] に登録されている枝の数
 */
struct EC {
        struct Var* var;
        uint32_t type_operator;
        uint32_t type_expression;
        struct EC* child_ptr[4];
        int32_t child_len;
};

struct EC* new_ec(void);
void delete_ec(struct EC* ec);
void translate_ec(struct EC* ec);

#endif /* __ONBC_EC_H__ */
