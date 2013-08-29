/* ブロックは入れ子構造にもできる。
 * この場合、結果は 345 234 123 と印字される
 */

dim a = 123;

{
        dim a = 234;

        {
                dim a = 345;
                print a;
        }

        print a;
}

print a;
