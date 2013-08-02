## OsecpuBasic

OsecpuBasic は古典的な BASIC 言語のコンパイラーです。

osecpu-aska（マクロアセンブラー）によってコンパイルできるソースを出力します。

ライセンスはflex/bisonの義理を感じるので GPL2 です。

***

現状できること:

***

スカラーおよび配列の宣言

・変数は宣言しないと使えません

・let を宣言の意味で使います

・配列宣言が dim ではなく let で宣言なのは、BASICの仕様をうろ覚えで作ってたからです

    let a
    let b(100)



***

変数への代入、および参照

・（重要！）代入は := で行います。（= ではありません。= は比較専用です）

・数は全て固定小数点型で扱われます。（符号1bit、整数15bit, 小数16bit）

    let a
    a := 10
    
    let b(100)
    b(a) := -3.14
    
    print b(a)



***

加算、減算、論理演算、演算の括弧によるくくり

・乗算、除算、余り算、冪乗は未実装です

    1 + 2 - 3
    not (1 and 2 or 3 xor 4)



***

条件分岐

    let a
    a := 0

    if a <= 10 then a := a + 1;
    if a = 0 then a := 1; else a := 0;
    if a = -1 then goto *E

    *E



***

繰り返し

    let i
    for i := 1 to 10 step 1
        print i
        goto *F
    next

    *F



***

ラベル

・ラベルは行の先頭でなければなりません。（インデントして書くことはできません）

    *L



***

ラベルへの goto

    let a
    a := 0

    *L
    a := a + 1
    goto *L



***

ラベルへの gosub, return

・現在 gosub は再帰をサポートできてません

・gosub 内で gosub を行うのは禁止です。（リターンアドレスが壊れます）

    gosub *X

    goto *END

    *X
    print 1

    *END



***

条件分岐 goto, gosub  

    on a = 1 goto *L
    on a < 1 gosub *E



***

文字の扱いに関しては何も作ってません。

現状では文字は未サポートです。



