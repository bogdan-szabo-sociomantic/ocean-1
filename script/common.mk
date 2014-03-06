# Common Makefile that provides often used targets and variables
#
# Use it by writing 'include ocean/script/common.mk' at the beginning of your makefile
# Note that it sets the default target to 'debug'. You can specify another
# default target by setting the .DEFAULT_GOAL variable right after the include.
#
# Variables that influence the behavior of this makefile (set them right after
# the include):

### Global settings ###

SHELL := /bin/bash

ifeq ($(shell which dmd1), )
	DC ?= dmd
else
	DC ?= dmd1
endif

ifeq ($(shell which rdmd1), )
	RDMD ?= rdmd
else
	RDMD ?= rdmd1
endif

RDMDFLAGS = --force --compiler=$(DC) --exclude=tango \
               $(DFLAGS) $(DEFAULT_FLAGS) $(OCEAN_LDFLAGS)


### User Setting Variable Defaults ###

# Directory were ocean submodule is located, needed to find version scripts
OCEAN_PATH=./submodules/ocean

# Garbage Collector to use
D_GC ?= cdgc
export D_GC

# Source libraries that the project depends on
# Defaults to submodule list
DEPENDENCIES := $(shell test -r .gitmodules && \
		sed -n 's/^\s*path\s*=\s//p' .gitmodules)

# Files to delete when doing dist clean (for example generated binaries)
DIST_CLEAN_FILES=

# Default Target to build if none is specified
.DEFAULT_GOAL=debug

# Where to put the Version.d file generated by the revision target
VERSION_MODULE=src/Version.d

# Skip those files when running unittests, usually you want mask out
# modules that contain "main" functions. Default one matches nothing.
# Right now only single pattern is supported
TEST_EXCLUSION_PATTERN="$$^"


### Useful Predefined Variables ###

REPO_NAME = $(notdir $(PWD))

DEBUG_FLAGS = -debug \
		-gc

RELEASE_FLAGS = -release \
		-inline \
		-O

DEFAULT_FLAGS = \
		-version=WithDateTime \
		-I./src \
		$(foreach dep,$(DEPENDENCIES), -I./$(dep)/src)

XFBUILD_DEFAULT_FLAGS = +c=$(DC) \
		+x=tango \
		+x=std

OCEAN_LDFLAGS = -L-ldl \
		-L-ldrizzle

# All sources can be found in ./src folder for applications, but for libraries
# it matches name of library

TESTED_SOURCE_ROOT = ./src

### Utility functions ###

# "package/subpackage/module.d" -> "package.subpackage.module"

path_to_module = $(subst /,.,$(1:.d=))

# $(1) is directory path to target binary, assumed to start with 'bin/'

invoke_xfbuild = xfbuild \
	+o=$(1) \
	+O=$(subst bin/,obj/,$(1)) \
	+D=$(subst bin/,obj/,$(1)).deps \
	+full

# Check if a certain debian package exists and if we have an appropriate
# version.
#
# $1 is the name of the package (required)
# $2 is the version string to check against (required)
# $3 is the compare operator (optional: >= by default, but it can be any of
#    <,<=,=,>=,>)
#
# This is best used with an order-only dependency (specified with a | after the
# normal dependencies), which means the target will be executed each time you
# have to build a target, but if doesn't affect if the target needs to be
# rebuilt or not.
#
# Example usage:
#
# .PHONY: check_deb_dependencies
# check_deb_dependencies:
# 	$(call check_deb,dstep,0.0.1-sociomantic1)
#
# myprogram: some-source.d | check_deb_dependencies
check_deb = @i=`apt-cache policy $1 | grep Installed | cut -b14-`; \
	op="$(if $3,$3,>=)"; \
	test "$$i" = "(none)" -o -z "$$i" && { \
		echo "Unsatisfied dependency: package '$1' is not" \
		"installed (version $$op $2 is required)" >&2 ; exit 1; }; \
	dpkg --compare-versions "$$i" "$$op" "$2" || { \
		echo "Unsatisfied dependency: package '$1' version $$op $2" \
			"is required but $$i is installed" >&2 ; exit 1; };

### TARGETS ###

# Updates the revision version information
revision:
	@echo Updating revision information …
	@cd ${CURDIR} && \
	${OCEAN_PATH}/script/mkversion.sh \
		-o ${VERSION_MODULE} \
		$(D_GC) \
		${OCEAN_PATH}/script/appVersion.d.tpl \
		$(DEPENDENCIES)

# Deletes every file created in the build process
# To add files to be deleted, add them to DIST_CLEAN_FILES
dist-clean:
	rm .objs-* .deps-* ${DIST_CLEAN_FILES} -rf

# internal convenience variable
tested_sources_ = $(shell find $(TESTED_SOURCE_ROOT) -name *.d | grep -v "$(TEST_EXCLUSION_PATTERN)")

# Runs unittests for all D modules in a projects
unittest: $(tested_sources_)
	@for module in $(tested_sources_); do \
		echo "Testing $$module"; \
		$(RDMD) --main $(RDMDFLAGS) -unittest -debug=UnitTest -version=UnitTest \
			$(DEBUG_FLAGS) $$module \
			2>&1 > /dev/null \
			|| exit 1; \
	done
	@echo "All tests have finished"

