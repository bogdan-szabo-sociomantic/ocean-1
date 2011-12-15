# This GNU Makefile supports different OS and CPU combinations.
#
# You should use it this way :
#   [g]make ARCH=arch CPU=cpu
#
# Variables useful for packagers :
#   CC is set to "gcc" by default and is used for compilation only.
#   LD is set to "gcc" by default and is used for linking only.
#   ARCH may be useful to force build of 32-bit binary on 64-bit systems
#   CFLAGS is automatically set for the specified CPU and may be overridden.
#   LDFLAGS is automatically set to -g and may be overridden.
#

#### TARGET CPU
# Use CPU=<cpu_name> to optimize for a particular CPU, among the following
# list :
#    generic, native, i586, i686, ultrasparc, custom
CPU = native

#### Architecture, used when not building for native architecture
# Use ARCH=<arch_name> to force build for a specific architecture. Known
# architectures will lead to "-m32" or "-m64" being added to CFLAGS and
# LDFLAGS. This can be required to build 32-bit binaries on 64-bit targets.
# Currently, only 32, 64, x86_64, i386, i486, i586 and i686 are understood.
ARCH =

#### Toolchain options.
# GCC is normally used both for compiling and linking.
CC = gcc
LD = $(CC)

#### Debug flags (typically "-g").
# Those flags only feed CFLAGS so it is not mandatory to use this form.
DEBUG_CFLAGS = -g

#### Compiler-specific flags that may be used to disable some negative over-
# optimization or to silence some warnings. -fno-strict-aliasing is needed with
# gcc >= 4.4.
SPEC_CFLAGS = -fno-strict-aliasing

#### CPU dependant optimizations
# Some CFLAGS are set by default depending on the target CPU. Those flags only
# feed CPU_CFLAGS, which in turn feed CFLAGS, so it is not mandatory to use
# them. You should not have to change these options. Better use CPU_CFLAGS or
# even CFLAGS instead.
CPU_CFLAGS.generic    = -Os
CPU_CFLAGS.native     = -Os -march=native
CPU_CFLAGS.i586       = -Os -march=i586
CPU_CFLAGS.i686       = -Os -march=i686
CPU_CFLAGS.ultrasparc = -O6 -mcpu=v9 -mtune=ultrasparc
CPU_CFLAGS            = $(CPU_CFLAGS.$(CPU))

#### ARCH dependant flags, may be overriden by CPU flags
ARCH_FLAGS.32     = -m32
ARCH_FLAGS.64     = -m64
ARCH_FLAGS.i386   = -m32 -march=i386
ARCH_FLAGS.i486   = -m32 -march=i486
ARCH_FLAGS.i586   = -m32 -march=i586
ARCH_FLAGS.i686   = -m32 -march=i686
ARCH_FLAGS.x86_64 = -m64 -march=x86-64
ARCH_FLAGS        = $(ARCH_FLAGS.$(ARCH))

#### Common CFLAGS
# These CFLAGS contain general optimization options, CPU-specific optimizations
# and debug flags. They may be overridden by some distributions which prefer to
# set all of them at once instead of playing with the CPU and DEBUG variables.
CFLAGS = $(ARCH_FLAGS) $(CPU_CFLAGS) $(SPEC_CFLAGS) -fPIC

#### Common LDFLAGS
# These LDFLAGS are used as the first "ld" options, regardless of any library
# path or any other option. They may be changed to add any linker-specific
# option at the beginning of the ld command line.
LDFLAGS = $(ARCH_FLAGS) -g

EBTREE_OBJS = ebtree.o eb32tree.o eb64tree.o eb128tree.o ebmbtree.o ebsttree.o ebimtree.o ebistree.o

# ebtree libraries
LIB_EBTREE_STATIC = libebtree.a
LIB_EBTREE_SHARED = libebtree.so

all: $(LIB_EBTREE_STATIC) $(LIB_EBTREE_SHARED)

$(LIB_EBTREE_STATIC): $(EBTREE_OBJS)
	$(AR) r $@ $^
	ranlib $@

$(LIB_EBTREE_SHARED): $(EBTREE_OBJS)
	$(LD) $(LDFLAGS) -shared -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

cleanup:
	rm -f *.o

clean: cleanup
	rm -f $(LIB_EBTREE_STATIC) $(LIB_EBTREE_SHARED)
