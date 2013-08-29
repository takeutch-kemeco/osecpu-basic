dim x=123;
print fact(5);
print x;

function fact(x)
{
        if (x > 1)
                return x * fact(x - 1);
        else
                return 1;
}
