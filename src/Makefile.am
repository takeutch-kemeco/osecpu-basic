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
                     onbc.stackframe.c onbc.stackframe.h \
                     onbc.callstack.c onbc.callstack.h \
                     onbc.label.c onbc.label.h \
                     onbc.eoe.c onbc.eoe.h \
                     onbc.func.c onbc.func.h \
                     onbc.sint.c onbc.sint.h \
                     onbc.uint.c onbc.uint.h \
                     onbc.double.c onbc.double.h \
                     onbc.ptr.c onbc.ptr.h \
                     onbc.cast.c onbc.cast.h \
                     onbc.acm.c onbc.acm.h \
                     onbc.struct.c onbc.struct.h

test_onbc_var_SOURCES = test.onbc.var.c
test_onbc_var_CFLAGS = -lonbc

LFLAGS = -Cf -8
YFLAGS = -dv
CFLAGS = -O0 -g
#CFLAGS += -DDISABLE_TUNE
#CFLAGS += -DDEBUG_SCOPE
#CFLAGS += -DDEBUG_STACK
#CFLAGS += -DDEBUG_STACKFRAME
#CFLAGS += -DDEBUG_CALLSTACK
#CFLAGS += -DDEBUG_SCOPE
#CFLAGS += -DDEBUG_VARLIST
#CFLAGS += -DDEBUG_STRUCTSPEC_PTRLIST -DDEBUG_STRUCTSPEC
#CFLAGS += -DDEBUG_VARIABLE
#CFLAGS += -DDEBUG_ASSIGNMENT
#CFLAGS += -DDEBUG_DEFINE -DDEBUG_IFDEF
#CFLAGS += -DDEBUG_ATTACHSTACK
#CFLAGS += -DDEBUG_CAST_REGVAL
#CFLAGS += -DDEBUG_EC_OPE_FUNCTION
#CFLAGS += -DDEBUG_EC_PARAMETER_DECLARATION
#CFLAGS += -DDEBUG_EC_ARGUMENT_EXPRESSION_LIST
#CFLAGS += -DDEBUG_EC_JUMP_STATEMENT
#CFLAGS += -DDEBUG_VAR_FUNC_ASSIGNMENT_NEW
#CFLAGS += -DDEBUG_EC_INLINE_ASSEMBLER_STATEMENT

LIBS = -lm -lfl
