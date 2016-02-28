override DFLAGS += -w

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/tango/core/Enforce.d \
	$C/src/tango/text/Arguments.d \
	$C/src/tango/util/log/Config.d \
	$C/src/tango/util/log/Trace.d \
	$C/src/ocean/util/app/VersionedLoggedStatsCliApp.d \
	$C/src/ocean/util/app/VersionedLoggedCliApp.d \
	$C/src/ocean/util/app/VersionedCliApp.d \
	$C/src/ocean/util/app/ConfiguredCliApp.d \
	$C/src/ocean/util/app/LoggedCliApp.d \
	$C/src/ocean/util/app/ConfiguredApp.d \
	$C/src/ocean/util/app/CommandLineApp.d \
	$C/src/ocean/io/select/client/IntervalClock.d \
	$C/src/ocean/text/util/StringReplace.d \
	$C/src/ocean/text/utf/UtfConvert.d

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
endif

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-ltokyocabinet -lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt
