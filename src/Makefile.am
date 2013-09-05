bin_PROGRAMS = osecpubasic
osecpubasic_SOURCES = main.c \
                      osecpubasic.bison.y osecpubasic.flex.l

LFLAGS = -Cf -8
YFLAGS = -dv
CFLAGS = -O0
#CFLAGS = -O0 -DDISABLE_TUNE
#CFLAGS = -O0 -g -DDEBUG_STACK -DDEBUG_VARLIST -DDEBUG_SCOPE
LIBS = -lm -lfl

