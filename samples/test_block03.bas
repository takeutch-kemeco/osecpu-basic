rem ブロック内から外部へ goto や gosub した場合は、
rem そのジャンプ先がブロック外である場合は、ブロック内で宣言されたローカル変数は無効となる。
rem そして、ジャンプ先から再びブロック内に戻ってきた場合であれば、ローカル変数は再び有効となる。（値も保持されたままで）

rem 一方、ジャンプ先がブロック内である場合は、ローカル変数もそのまま有効となる。

rem すなわち、たとえばブロックの途中で goto によってブロックを抜ければ、
rem （普通にブロックの最後まで到達した場合と同様に）、ブロック内のローカル変数は破棄され、オーバーライドは解除される。

rem また逆に、ブロックの外から goto などでブロック内にジャンプしてきた場合でも、
rem ブロック内で宣言された変数は（ブロック内の宣言行を読み飛ばした位置へジャンプしてきた場合でも）、既に宣言された状態となる。
rem しかし、宣言はされるが、初期値が代入済みかどうかに関しては別の話となる。
rem 初期値を代入する行を読み飛ばした場合等であれば、これに関してはの動作は不定となる。
rem （おそらく初期化はされてないか、またはゴミが入った状態となるだろう）

dim a
a := 123

{
        dim a
        a := 234

        gosub *L0
        print a
}

print a



dim b
b := 345
goto *LB

{
        dim b
*LB
        b := 456
        print b
}


dim c
c := 567
goto *LC

{
        dim c
        c := 678
*LC
        print c
}



goto *END

*L0
        print a
        return

*END
