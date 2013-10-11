aclocal --force
libtoolize
autoheader
automake -acf
autoconf
./configure $@
