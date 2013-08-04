## OsecpuBasic version 0.0.2

OsecpuBasic は古典的な BASIC 言語のコンパイラーです。

osecpu-aska（マクロアセンブラー）によってコンパイルできるソースを出力します。

ライセンスはflex/bisonの義理を感じるので GPL2 です。



***
### 重要:

現在の osecpu-basic が吐くアセンブラコードは osecpu067d 以上用です。

osecpu067d 未満のバージョンでは正常動作しません。



***

ビルド方法:

・ビルドには autoconf, automake, libtool が必要です。また、flex, bison も必要です。そして gcc, libc も当然必要です。

    ./autogen.sh --prefix=/usr
    make

これで src/ 以下に osecpubasic というバイナリができます。



***

使用方法:

・以下の方法で、BASICのソースファイルから、osecpu-aska のアセンブラコードへ変換できます。

    ./osecpubasic BASICのソースファイル.bas

これで、同名で拡張子が.askのファイルとして、カレントディレクトリ内に出力されます。
また、明示的に出力ファイル名を指定したい場合は

    ./osecpubasic BASICのソースファイル.bas 出力ファイル名.ask

とすることも可能です。
（ファイル名にパス名を含めても動作します）

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

四則演算、符号付き剰余算、論理演算、演算の括弧によるくくり

・演算子の優先順位は * / mod の方が + - よりも優先されます。

（従って以下の例では 1 + 2 - (3 * 4 / 5 mod 6)の順番で計算されます）

・また、論理演算は * / mod よりも優先されますが、これについてはたまたまです。

（正式なBASIC言語の仕様では、優先順位が異なるかもしれません。
現状は仕様はあまり調べずに適当に作ってる段階なので、そのうち変わる可能性もあります）

・冪乗は未実装です

    1 + 2 - 3 * 4 / 5 mod 6
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
        gosub *F
    next

    *F
    print 1
    return



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

・gosub の中でさらに gosub しても、正常に return できます。

    gosub *X
    print 4

    goto *END

    *X
    print 1
    gosub *Y
    print 3
    return

    *Y
    print 2
    return

    *END



***

条件分岐 goto, gosub

    on a = 1 goto *L
    on a < 1 gosub *E



***

文字の扱いに関しては何も作ってません。

現状では文字は未サポートです。



