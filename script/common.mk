# Common Makefile that provides often used targets and variables
#
# Use it by writing 'include ocean/script/common.mk' at the beginning of your makefile
# Note that it sets the default target to 'debug'. You can specify another
# default target by setting the .DEFAULT_GOAL variable right after the include.
#
# Variables that influence the behavior of this makefile (set them right after
# the include):

### User Setting Variable Defaults ###

# Directory were the libraries are to be found
LIB_BASEDIR=${PWD}

# Garbage Collector to use
D_GC=cdgc

# Libraries that the project depends on
DEPENDENCIES=tango ocean

# Files to delete when doing dist clean (for example generated binaries)
DIST_CLEAN_FILES=

# Default Target to build if none is specified
.DEFAULT_GOAL=debug


### Useful Predefined Variables ###

DEBUG_FLAGS = -debug \
              -gc \
              -unittest \
              -debug=SonarUnitTest \
              -debug=OceanUnitTest

RELEASE_FLAGS = -release \
                -inline \
                -O

DEFAULT_FLAGS = -L--as-needed \
                -version=CDGC \
                -version=WithDateTime \
                -m64

XFBUILD_DEFAULT_FLAGS = +c=dmd \
                        +x=tango \
                        +x=std

OCEAN_LDFLAGS = -L-lminilzo \
                        -L-ldl \
                        -L-lebtree \
                        -L-ldrizzle

### TARGETS ###

# Updates the revision version information
revision:
	@echo Updating revision information …
	@${LIB_BASEDIR}/ocean/script/mkversion.sh -L${LIB_BASEDIR} -t \
             ${LIB_BASEDIR}/ocean/script/appVersion.d.tpl $(D_GC) $(DEPENDENCIES)

# Deletes every file created in the build process
# To add files to be deleted, add them to DIST_CLEAN_FILES
dist-clean:
	rm .objs-* .deps-* ${DIST_CLEAN_FILES} -rf
