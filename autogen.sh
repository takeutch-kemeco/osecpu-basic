aclocal --force
autoheader
automake -acf
autoconf
./configure $@
