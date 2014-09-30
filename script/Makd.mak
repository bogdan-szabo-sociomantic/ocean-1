# This file is based on:
# http://git.llucax.com.ar/w/software/makeit.git
# Distributed under the Boost Software License, Version 1.0

ifndef Makd.mak.included
Makd.mak.included := 1

# This variable should be provided by the Makefile that include us (if needed):
# S should be sub-directory where the current makefile is, relative to $T.

# Use the git top-level directory by default
T ?= $(shell git rev-parse --show-toplevel)
# Use absolute paths to avoid problems with automatic dependencies when
# building from subdirectories
T := $(abspath $T)

# Name of the current directory, relative to $T
R := $(subst $T,,$(patsubst $T/%,%,$(CURDIR)))

# Define the valid flavors
VALID_FLAVORS := devel production

# Flavor (variant), can be defined by the user in Config.mak
F ?= devel

# Load top-level directory project configuration
-include $T/Config.mak

# Load top-level directory local configuration
-include $T/Config.local.mak

# Check flavours
FLAVOR_IS_VALID_ := $(if $(filter $F,$(VALID_FLAVORS)),1,0)
ifeq ($(FLAVOR_IS_VALID_),0)
$(error F=$F is not a valid flavor (options are: $(VALID_FLAVORS)))
endif

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

# The files specified in this variable will be excluded from the generated
# unit tests targets and from the integration test main files.
# By default all files called main.d in $C/src/ are excluded too, it's assumed
# they'll have a main() function in them.
# Paths must be absolute (specify them with the $C/ prefix).
# The contents of this variable will be passed to the Make function
# $(filter-out), meaning you can specify multple patterns separated by
# whitespaces and each pattern can have one '%' that's used as a wildcard.
# For more information refer to the documentation:
# http://www.gnu.org/software/make/manual/make.html#Text-Functions
TEST_FILTER_OUT := $C/src/%/main.d


# Default compiler flags
#########################

DFLAGS ?= -di

override DFLAGS += -gc

ifeq ($F,devel)
override DFLAGS += -debug
endif

ifeq ($F,production)
override DFLAGS += -O -inline
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

# Directory for temporary files, like objects, dependency files and other
# generated intermediary files
O ?= $G/tmp

# Binaries directory
B ?= $G/bin

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


# Include the user's makefile, Build.mak
#########################################

# We do it before declaring the rules so some variables like TEST_FILTER_OUT
# are used as prerequisites, so we need to define them before the rules are
# declared.
-include $T/Build.mak


# Default rules
################

# By default we build the `all` target (it can be overriden at the end of the
# user's Makefile)
.DEFAULT_GOAL := all

# This is not a rule, but is defined to match the LINK.* variables predefined
# in Make and have a more Make-ish look & feel.
BUILD.d.depfile = $O/$*.mak
BUILD.d = $(RDMD) $(RDMDFLAGS) --makedepfile=$(BUILD.d.depfile) $(DFLAGS) \
		$($@.EXTRA_FLAGS) $(addprefix -L,$(LDFLAGS)) $(TARGET_ARCH)

# Updates the git version information
VERSION_MODULE := $T/src/Version.d
clean += $(VERSION_MODULE)
mkversion = $V$(if $V,to=0; test -r $(VERSION_MODULE) && \
		to=`stat --printf "%Y" "$(VERSION_MODULE)"`; \
	)$(OCEAN_PATH)/script/mkversion.sh -o $(VERSION_MODULE) -m Version \
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

# Clean the whole build directory, uses $(clean) to remove extra files
.PHONY: clean
clean:
	$(call exec,$(RM) -r $(VD) $(clean),$(VD) $(clean))

# Phony rule to uninstall all built targets (like "install", uses $(install)).
.PHONY: uninstall
uninstall:
	$V$(foreach i,$(install),$(call vexec,$(RM) $i,$i);)


# Unit tests rules
###################

# These are divided in 2 types: fast and slow.
# Unittests are considered fast unless stated otherwise, and the way to say
# a test is slow is by putting it in a file with the suffx _slowtest.d.
# Normally that should be appended to the file of the module that's being
# tested.
# All modules to be passed to the unit tester (fast or slow) are filtered
# through the $(TEST_FILTER_OUT) variable contents (using the Make function
# $(filter-out)).
# The target fastunittest build only the fast unit tests, the target
# allunittest builds both fast and slow unit tests, and the target unittest is
# an alias for allunittest.
.PHONY: fastunittest allunittest unittest
fastunittest: $O/fastunittests.stamp
allunittest: $O/allunittests.stamp
unittest: allunittest

# Add fastunittest to fasttest and unittest to test general targets
fasttest += fastunittest
test += unittest

# Files to be tested in unittests, the user could potentially add more
UNITTEST_FILES += $(call find_files,.d,,$C/src,$(TEST_FILTER_OUT))

# Files to test when using fast or all unit tests
$O/fastunittests.d: $(filter-out %_slowtest.d,$(UNITTEST_FILES))
$O/allunittests.d: $(UNITTEST_FILES)

# General rule to build the unittest program using the UnitTestRunner
$O/%unittests.d: $G/build-d-flags | $O/check_rdmd1
	$(call exec,printf 'module $(patsubst $O/%.d,%,$@);\n\
		import ocean.core.UnitTestRunner;\
		\n$(foreach f,$(filter %.d,$^),\
		import $(subst /,.,$(patsubst $C/src/%.d,%,$f));\n)' > \
			$@,,gen)

# Configure dependencies files specific to each special unittests target
$O/fastunittests: BUILD.d.depfile := $O/fastunittests.mak
$O/allunittests: BUILD.d.depfile := $O/allunittests.mak

# General rule to build the generated unittest program
$O/%unittests: $O/%unittests.d $G/build-d-flags | $O/check_rdmd1
	$(mkversion)
	$(call exec,$(BUILD.d) --build-only -unittest -debug=UnitTest \
		-version=UnitTest $(LOADLIBES) $(LDLIBS) -of$@ $<)

# General rule to run the unit tests binaries
$O/%unittests.stamp: $O/%unittests
	$(call exec,$< $(if $(findstring k,$(MAKEFLAGS)),-k) $(if $V,,-v -s) \
		$(foreach p,$(patsubst %.d,%,$(notdir $(shell \
			find $T/src -maxdepth 1 -mindepth 1 -name '*.d' -type f\
			))),-p $p) \
		$(foreach p,$(notdir $(shell \
			find $T/src -maxdepth 1 -mindepth 1 -type d \
			)),-p $p.) $(UTFLAGS),$<,run)
	$Vtouch $@

# Integration tests rules
##########################

# Integration tests are assumed to be standalone programs, so we just search
# for files test/%/main.d and assume they are the entry point of the program
# (and each subdirectory in test/ is a separate program).
# The sources list is filtered through the $(TEST_FILTER_OUT) variable contents
# (using the Make function $(filter-out)), so you can exclude an integration
# test by adding the location of the main.d (as an absolute path using $C) by
# adding it to this variable.
# The target integrationtest builds and runs all the integration tests.
.PHONY: integrationtest
integrationtest: $(patsubst $T/test/%/main.d,$O/test-%.stamp,\
		$(filter-out $(TEST_FILTER_OUT),$(wildcard $T/test/*/main.d)))

# Add integrationtest to the test general target
test += integrationtest

# General rule to build integration tests programs, this is the same as
# building any other binary but including unittests too.
$O/test-%: $T/test/%/main.d $G/build-d-flags | $O/check_rdmd1
	$(mkversion)
	$(call exec,$(BUILD.d) --build-only -unittest -debug=UnitTest \
		-version=UnitTest $(LOADLIBES) $(LDLIBS) -of$@ $<)

# General rule to Run the test suite binaries
$O/test-%.stamp: $O/test-%
	$(call exec,$< $(ITFLAGS),$<,run)
	$Vtouch $@


# Create build directory structure
###################################

# Create $O, $B and $D directories and replicate the directory structure of the
# project into $O. Create one symbolic link "last" to the current build
# directory.
setup_build_dir__ := $(shell \
	mkdir -p $O $B $D \
		$(addprefix $O,$(patsubst $T%,%,\
		$(shell find $T -type d $(foreach d,$(BUILD_DIR_EXCLUDE), \
			-not -path '$T/$d' -not -path '$T/$d/*' \
			-not -path '$T/*/$d' -not -path '$T/*/$d/*')))); \
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


# Targets using special variables
##################################
# These targets need to be after processing the Build.mak so all the special
# variables get populated.

# Phony rule to make all the targets (sub-makefiles can append targets to build
# to the $(all) variable).
.PHONY: all
all: $(all)

# Phony rule to install all built targets (sub-makefiles can append targets to
# build to the $(install) variable).
.PHONY: install
install: $(install)

# Phony rule to build all documentation targets (sub-makefiles can append
# documentation to build to the $(doc) variable).
.PHONY: doc
doc: $(doc)

# Phony rule to build and run all test (sub-makefiles can append targets to
# build and run tests to the $(test) variable).
.PHONY: test
test: $(test)

# Phony rule to build and run all fast tests (sub-makefiles can append targets
# to build and run tests to the $(fasttest) variable).
.PHONY: fasttest
fasttest: $(fasttest)


# Automatic dependency handling
################################

# These files are created during compilation.
-include $(shell test -d $O && find $O -name '*.mak')

endif
