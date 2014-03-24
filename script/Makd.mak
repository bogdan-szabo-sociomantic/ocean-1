# This file is based on:
# http://git.llucax.com.ar/w/software/makeit.git
# Distributed under the Boost Software License, Version 1.0

ifndef Makd.mak.included
Makd.mak.included := 1

# This variable should be provided by the Makefile that include us (if needed):
# S should be sub-directory where the current makefile is, relative to $T.

# Use the git top-level directory by default
T ?= $(shell dirname `git rev-parse --git-dir`)
# Use absolute paths to avoid problems with automatic dependencies when
# building from subdirectories
T := $(abspath $T)

# Name of the current directory, relative to $T
R := $(subst $T,,$(patsubst $T/%,%,$(CURDIR)))

# Flavor (variant), can be defined by the user in Config.mak
# Default available flavors: devel, production
F ?= devel

# Load top-level directory project configuration
-include $T/Config.mak

# Load top-level directory local configuration
-include $T/Config.local.mak

# Verbosity flag (empty show nice messages, non-empty use make messages)
# When used internally, $V expand to @ is nice messages should be printed, this
# way it's easy to add $V in front of commands that should be silenced when
# displaying the nice messages.
override V := $(if $V,,@)
# honour make -s flag
override V := $(if $(findstring s,$(MAKEFLAGS)),,$V)

# If $V is non-empty, colored output is used if $(COLOR) is non-empty too
COLOR ?= 1
COLOR := $(if $V,$(COLOR))

# ANSI color used for the command if $(COLOR) is non-empty
# The color is composed with 2 numbers separated by ;
# The first is the style. 00 is normal, 01 is bold, 04 is underline, 05 blinks,
# 07 is reversed mode
# The second is the color: 30 dark gray/black, 31 red, 32 green, 33 yellow, 34
# blue, 35 magenta, 36 cyan and 37 white.
# If empty, no special color is used.
COLOR_CMD ?= 00;33

# ANSI color used for the argument if $(COLOR) is non-empty
# See COLOR_CMD comment for details.
COLOR_ARG ?=

# ANSI color used for the warnings if $(COLOR) is non-empty
# See COLOR_CMD comment for details.
COLOR_WARN ?= 00;36

# ANSI color used for errors if $(COLOR) is non-empty
# See COLOR_CMD comment for details.
COLOR_ERR ?= 00;31

# ANSI color used for commands output if $(COLOR) is non-empty
# See COLOR_CMD comment for details.
COLOR_OUT ?= $(COLOR_ERR)

# Default D compiler (tries first with dmd1 and uses dmd if not present)
DC ?= dmd1

# Default rdmd binary to use (same as with dmd)
RDMD ?= rdmd1

# Garbage Collector to use
# (exported because other programs might use the variable)
D_GC ?= cdgc
export D_GC

# Default install program binary location
INSTALL ?= install

# Default mode used to install files
IMODE ?= 0644

# Default install flags
IFLAGS ?= -D


# Default compiler flags
#########################

DFLAGS ?= -wi

ifeq ($F,devel)
override DFLAGS += -debug -gc
endif

ifeq ($F,production)
override DFLAGS += -O -inline -release
endif


# Directories
##############

# Directory were ocean submodule is located, needed to find version scripts
OCEAN_PATH ?= $T/$(shell  test -r $T/.gitmodules && \
		sed -n '/\[submodule "ocean"\]/,/^\s*path\s*=/ { \
		s/^\s*path\s*=\s*\(.*\)\s*$$/\1/p }' $T/.gitmodules)

# Location of the submodules (libraries the project depends on)
SUBMODULES ?= $(shell test -r $T/.gitmodules && \
		sed -n 's/^\s*path\s*=\s//p' $T/.gitmodules)

# Name of the build directory (to use when excluding some paths)
BUILD_DIR_NAME ?= build

# Directories to exclude from the build directory tree replication
BUILD_DIR_EXCLUDE ?= $(BUILD_DIR_NAME) $(SUBMODULES) .git

# Base directory where to install files (can be overridden, should be absolute)
prefix ?= /usr/local

# Path to a complete alternative environment, usually a jail, or an installed
# system mounted elsewhere than /.
DESTDIR ?=

# Base directory where to put variants (Variants Directory)
VD ?= $T/$(BUILD_DIR_NAME)

# Generated files top directory
G ?= $(VD)/$F

# Objects (and other garbage like pre-compiled headers and dependency files)
# directory
O ?= $G/obj

# Binaries directory
B ?= $G/bin

# Test result directory
U ?= $G/unittest

# Documentation directory
D ?= $(VD)/doc

# Installation directory
I := $(DESTDIR)$(prefix)

# Directory of the current Build.mak (this might not be the same as $(CURDIR)
# This variable is "lazy" because $S changes all the time, so it should be
# evaluated in the context where $C is used, not here.
C = $T$(if $S,/$S)


# Functions
############

# Compare two strings, if they are the same, returns the string, if not,
# returns empty.
eq = $(if $(subst $1,,$2),,$1)

# Find files and get the their file names relative to another directory.
# $1 is the files suffix (".h" or ".cpp" for example).
# $2 is a directory rewrite, the matched files will be rewriten to
#    be in the directory specified in this argument (it defaults to $3 if
#    omitted).
# $3 is where to search for the files ($C if omitted).
# $4 is a `filter-out` pattern applied over the original file list (previous to
#    the rewrite). It can be empty, which has no effect (nothing is filtered).
find_files = $(patsubst $(if $3,$3,$C)/%$1,$(if $2,$2,$(if $3,$3,$C))/%$1, \
		$(filter-out $4,$(shell find $(if $3,$3,$C) -name '*$1')))

# Abbreviate a file name. Cut the leading part of a file if it match to the $T
# directory, so it can be displayed as if it were a relative directory. Take
# just one argument, the file name.
abbr_helper = $(subst $T,.,$(patsubst $T/%,%,$1))
abbr = $(if $(call eq,$(call abbr_helper,$1),$1),$1,$(addprefix \
		$(shell echo $R | sed 's|/\?\([^/]\+\)/\?|../|g'),\
		$(call abbr_helper,$1)))

# Helper functions for vexec
vexec_pc = $(if $1,\033[$1m%s\033[00m,%s)
vexec_p = $(if $(COLOR), \
	'   $(call vexec_pc,$(COLOR_CMD)) $(call vexec_pc,$(COLOR_ARG))\n$(if \
			$(COLOR_OUT),\033[$(COLOR_OUT)m)', \
	'   %s %s\n')
# Execute a command printing a nice message if $V is @.
# $1 is mandatory and it's the command to execute.
# $2 is the target name (defaults to $@).
# $3 is the command name (defaults to the first word of $1).
vexec = $(if $V,printf $(vexec_p) \
		'$(call abbr,$(if $3,$(strip $3),$(firstword $1)))' \
		'$(call abbr,$(if $2,$(strip $2),$@))' ; )$1 \
		$(if $(COLOR),$(if $(COLOR_OUT), ; r=$$? ; \
				printf '\033[00m' ; exit $$r))

# Same as vexec but it silence the echo command (prepending a @ if $V).
exec = $V$(call vexec,$1,$2,$3)

# Install a file. All arguments are optional.  The first argument is the file
# mode (defaults to 0644).  The second argument are extra flags to the install
# command (defaults to -D).  The third argument is the source file to install
# (defaults to $<) and the last one is the destination (defaults to $@).
install_file = $(call exec,$(INSTALL) -m $(if $1,$1,$(IMODE)) \
		$(if $2,$2,$(IFLAGS)) $(if $3,$3,$<) $(if $4,$4,$@))

# Concatenate variables together.  The first argument is a list of variables
# names to concatenate.  The second argument is an optional prefix for the
# variables and the third is the string to use as separator (" ~" if omitted).
# For example:
# X_A := a
# X_B := b
# $(call varcat,A B,X_, --)
# Will produce something like "a -- b --"
varcat = $(foreach v,$1,$($2$v)$(if $3,$3, ~))

# Replace variables with specified values in a template file.  The first
# argument is a list of make variables names which will be replaced in the
# target file.  The strings @VARNAME@ in the template file will be replaced
# with the value of the make $(VARNAME) variable and the result will be stored
# in the target file.  The second (optional) argument is a prefix to add to the
# make variables names, so if the prefix is PREFIX_ and @VARNAME@ is found in
# the template file, it will be replaced by the value of the make variable
# $(PREFIX_VARNAME).  The third and fourth arguments are the source file and
# the destination file (both optional, $< and $@ are used if omitted). The
# fifth (optional) argument are options to pass to the substitute sed command
# (for example, use "g" if you want to do multiple substitutions per line).
replace = $(call exec,sed '$(foreach v,$1,s|@$v@|$($2$v)|$5;)' $(if $3,$3,$<) \
		> $(if $4,$4,$@))

# Create a file with flags used to trigger rebuilding when they change. The
# first argument is the name of the file where to store the flags, the second
# are the flags and the third argument is a text to be displayed if the flags
# have changed (optional).  This should be used as a rule action or something
# where a shell script is expected.
gen_rebuild_flags = $(shell if test x"$2" != x"`cat $1 2>/dev/null`"; then \
		$(if $3,test -f $1 && echo "$(if $(COLOR),$(if $(COLOR_WARN),\
			\033[$(COLOR_WARN)m$3\033[00m,$3),$3);";) \
		echo "$2" > $1 ; fi)

# Include sub-directory's Build.mak.  The only argument is a list of
# subdirectories for which Build.mak should be included.  The $S directory is
# set properly before including each sub-directory's Build.mak and restored
# afterwards.
define build_subdir_code
_parent__$d__dir_ := $$S
S := $$(if $$(_parent__$d__dir_),$$(_parent__$d__dir_)/$d,$d)
include $$T/$$S/Build.mak
S := $$(_parent__$d__dir_)
endef
include_subdirs = $(foreach d,$1,$(eval $(build_subdir_code)))

# Check if a certain debian package exists and if we have an appropriate
# version.
#
# $1 is the name of the package (required)
# $2 is the version string to check against (required)
# $3 is the compare operator (optional: >= by default, but it can be any of
#    <,<=,=,>=,>)
#
# Y`ou can use this as the first command to run for a target action, for example:
#
# myprogram: some-source.d
# 	$(call check_deb,dstep,0.0.1-sociomantic1)
# 	rdmd --build --whatever.
#
check_deb = $Vi=`apt-cache policy $1 | grep Installed | cut -b14-`; \
	op="$(if $3,$3,>=)"; \
	test "$$i" = "(none)" -o -z "$$i" && { \
		printf "%bUnsatisfied dependency:%b %s\npackage '$1' is not installed (version $$op $2 is required)\n" \
			$(if $(COLOR),'\033[$(COLOR_ERR)m' '\033[00m', '' '') \
			>&2 ; exit 1; }; \
	dpkg --compare-versions "$$i" "$$op" "$2" || { \
		printf "%bUnsatisfied dependency:%b package '$1' version $$op $2 is required but $$i is installed\n" \
			$(if $(COLOR),'\033[$(COLOR_ERR)m' '\033[00m', '' '') \
			>&2 ; exit 1; };


# Overridden and default flags
###############################

# Default rdmd flags
RDMDFLAGS ?= --force --compiler=$(DC) --exclude=tango

# Default dmd flags
override DFLAGS += -version=WithDateTime -I./src \
	$(foreach dep,$(SUBMODULES), -I./$(dep)/src)


# Default rules
################

# By default we build the `all` target if we didn't get a exlicit default
# before.
ifeq ($(.DEFAULT_GOAL),)
.DEFAULT_GOAL := all
endif

# This is not a rule, but is defined to match the LINK.* variables predefined
# in Make and have a more Make-ish look & feel.
BUILD.d = $(RDMD) $(RDMDFLAGS) --makedepfile=$O/$*.mak $(DFLAGS) \
		$($@.EXTRA_FLAGS) $(addprefix -L,$(LDFLAGS)) $(TARGET_ARCH)

# Updates the git version information
VERSION_MODULE ?= $T/src/Version.d
clean += $(VERSION_MODULE)
mkversion = $V$(if $V,to=0; test -r $(VERSION_MODULE) && \
		to=`stat --printf "%Y" "$(VERSION_MODULE)"`; \
	)$(OCEAN_PATH)/script/mkversion.sh -o $(VERSION_MODULE) \
	-m "$(subst /,.,$(subst $T/,,$(VERSION_MODULE:.d=)))" \
	$(D_GC) $(OCEAN_PATH)/script/appVersion.d.tpl $(SUBMODULES)$(if $V,\
		; tn=`stat --printf "%Y" "$(VERSION_MODULE)"`; \
		test "$$tn" -gt "$$to" && { \
			printf $(vexec_p) mkversion $(VERSION_MODULE); \
			$(if $(COLOR),printf  '\033[00m';) \
		} || true)

# Dummy target to check for rdmd1 package (this is a transitional check, once
# we all use the new packages this should be removed)
$O/check_rdmd1: $(shell which $(RDMD))
	$(call check_deb,rdmd1,2.065.0+16~dmd1~gbfa9b6a)
	$Vtouch $@

# Link binary programs
$B/%: $G/build-d-flags | $O/check_rdmd1
	$(mkversion)
	$(call exec,$(BUILD.d) --build-only $(LOADLIBES) $(LDLIBS) -of$@ \
		$(firstword $(filter %.d,$^)))

# Install binary programs
$I/bin/%:
	$(call install_file,0755)

# Install system binary programs
$I/sbin/%:
	$(call install_file,0755)

# Runs unittests for all D modules in a projects.
# If the variable TEST_FILTER_OUT is defined is used to exclude some modules.
# The Make function $(filter-out) is used, which basically means you can
# specify multple patterns separated by whitespaces and each pattern can have
# one '%' that's used as a wildcard. For more information refer to the
# documentation:
# http://www.gnu.org/software/make/manual/make.html#Text-Functions
.PHONY: unittest
unittest: $(patsubst %.d,%,\
		$(call find_files,.d,$U/src,$T/src,$(TEST_FILTER_OUT)))
test += unittest

# Build the individual unittest binaries
$U/%: $T/%.d $G/build-d-flags | $O/check_rdmd1
	$(mkversion)
	$(call exec,$(BUILD.d) --main -unittest -debug=UnitTest \
		-version=UnitTest $(LOADLIBES) $(LDLIBS) -of$@ $< \
		2>&1 > $@.log || { cat $@.log; false; },$<,test)

# Clean the whole build directory, uses $(clean) to remove extra files
.PHONY: clean
clean:
	$(call exec,$(RM) -r $(VD) $(clean),$(VD) $(clean))

# Phony rule to uninstall all built targets (like "install", uses $(install)).
.PHONY: uninstall
uninstall:
	$V$(foreach i,$(install),$(call vexec,$(RM) $i,$i);)

# These rules use the "Secondary Expansion" GNU Make feature, to allow
# sub-makes to add values to the special variables $(all), $(install), $(doc)
# and $(test), after this makefile was read.
.SECONDEXPANSION:

# Phony rule to make all the targets (sub-makefiles can append targets to build
# to the $(all) variable).
.PHONY: all
all: $$(all)

# Phony rule to install all built targets (sub-makefiles can append targets to
# build to the $(install) variable).
.PHONY: install
install: $$(install)

# Phony rule to build all documentation targets (sub-makefiles can append
# documentation to build to the $(doc) variable).
.PHONY: doc
doc: $$(doc)

# Phony rule to build and run all test (sub-makefiles can append targets to
# build and run tests to the $(test) variable).
.PHONY: test
test: $$(test)


# Create build directory structure
###################################

# Create $O, $B, $D and $U directories and replicate the directory
# structure of the project into $O and $U. Create one symbolic link "last"
# to the current build directory.
setup_build_dir__ := $(shell \
	mkdir -p $O $B $D $U \
		$(foreach t,$O $U,$(addprefix $t,$(patsubst $T%,%,\
		$(shell find $T -type d $(foreach d,$(BUILD_DIR_EXCLUDE), \
			-not -path '$T/$d' -not -path '$T/$d/*' \
			-not -path '$T/*/$d' -not -path '$T/*/$d/*'))))); \
	rm -f $(VD)/last && ln -s $F $(VD)/last )


# Automatic rebuilding when flags or commands changes
######################################################

# Re-build binaries and libraries if one of this variables changes
BUILD.d.FLAGS := $(call varcat,RDMD RDMDFLAGS DFLAGS LDFLAGS TARGET_ARCH prefix)

setup_flag_files__ := $(setup_flag_files__)$(call gen_rebuild_flags, \
	$G/build-d-flags, $(BUILD.d.FLAGS),D compiler)

# Print any generated message (if verbose)
$(if $V,$(if $(setup_flag_files__), \
	$(info !! Flags or commands changed:$(setup_flag_files__) re-building \
			affected files...)))

# Include the Build.mak for this directory
-include $T/Build.mak


# Automatic dependency handling
################################

# These files are created during compilation.
-include $(shell test -d $O && find $O -name '*.mak')

endif
