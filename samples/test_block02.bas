rem ブロックは入れ子構造にもできる。
rem この場合、結果は 345 234 123 と印字される

dim a
a := 123

{
        dim a
        a := 234

        {
                dim a
                a := 345
                print a
        }

        print a
}

print a
