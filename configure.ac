#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([osecpubasic], [0.0.1], [takeutchkemeco@gmail.com])
AM_INIT_AUTOMAKE([foreign])
AC_CONFIG_SRCDIR([src/main.c])
AC_CONFIG_HEADERS([src/config.h])

# Checks for programs.
AC_PROG_CC
AC_PROG_YACC
AC_PROG_LEX

AC_PATH_PROG([FLEX],  [flex])
AC_PATH_PROG([BISON], [bison])

if test -z test -z $FLEX || test -z $BISON
then
        AC_MSG_NOTICE([memcalc のビルドには flex, bison が必要です])

        if test -z $FLEX
        then
                AC_MSG_NOTICE([gnu flex が存在しません])
        fi

        if test -z $BISON
        then
                AC_MSG_NOTICE([bison が存在しません])
        fi

        AC_MSG_ERROR([ビルドを中止します])
fi

# Checks for libraries.

# Checks for header files.
AC_CHECK_HEADERS([stdio.h stdlib.h string.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_C_INLINE
AC_TYPE_SIZE_T

# Checks for library functions.
AC_FUNC_MALLOC

AC_CONFIG_FILES([Makefile src/Makefile])
AC_OUTPUT

