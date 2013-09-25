asm("junkApi_putConstString('hello world\n');");

asm(
        "junkApi_putConstString('hello ');"
        "junkApi_putConstString('world\n');"
);
