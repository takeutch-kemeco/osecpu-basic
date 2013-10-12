bin_PROGRAMS = onbc \
               test.onbc.var

onbc_SOURCES = main.c \
               onbc.bison.y onbc.flex.l \
               onbc.ec.c onbc.ec.h
onbc_CFLAGS = -lonbc

lib_LTLIBRARIES = libonbc.la
libonbc_la_SOURCES = onbc.print.c onbc.print.h \
                     onbc.iden.c onbc.iden.h \
                     onbc.var.c onbc.var.h \
                     onbc.mem.c onbc.mem.h \
                     onbc.stack.c onbc.stack.h \
                     onbc.label.c onbc.label.h \
                     onbc.eoe.c onbc.eoe.h \
                     onbc.func.c onbc.func.h \
                     onbc.int.c onbc.int.h \
                     onbc.float.c onbc.float.h \
                     onbc.cast.c onbc.cast.h \
                     onbc.acm.c onbc.acm.h \
                     onbc.struct.c onbc.struct.h

test_onbc_var_SOURCES = test.onbc.var.c
test_onbc_var_CFLAGS = -lonbc

LFLAGS = -Cf -8
YFLAGS = -dv
CFLAGS = -O0 -g
#CFLAGS += -DDISABLE_TUNE
#CFLAGS += -DDEBUG_SCOPE -DDEBUG_STACK
#CFLAGS += -DDEBUG_STACK -DDEBUG_SCOPE
CFLAGS += -DDEBUG_VARLIST
#CFLAGS += -DDEBUG_STRUCTSPEC_PTRLIST -DDEBUG_STRUCTSPEC
#CFLAGS += -DDEBUG_VARIABLE
#CFLAGS += -DDEBUG_ASSIGNMENT
#CFLAGS += -DDEBUG_DEFINE -DDEBUG_IFDEF
#CFLAGS += -DDEBUG_ATTACHSTACK
#CFLAGS += -DDEBUG_VAR_CAST
CFLAGS += -DDEBUG_CAST_REGVAL
LIBS = -lm -lfl
