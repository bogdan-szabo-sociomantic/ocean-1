override DFLAGS += -w -version=GLIBC

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$(shell find $C/src/tango) \
	$C/src/ocean/core/Memory.d \
	$C/src/ocean/util/cipher/RC6.d \
	$C/src/ocean/util/compress/c/bzlib.d \
	$C/src/ocean/io/stream/Bzip.d \
	$C/src/ocean/time/Ctime.d \
	$C/src/ocean/core/Enforce_tango.d \
	$C/src/ocean/text/Arguments_tango.d \
	$C/src/ocean/util/VariadicArg.d \
	$C/src/ocean/util/log/Config_tango.d \
	$C/src/ocean/util/log/Trace.d \
	$C/src/ocean/util/app/VersionedLoggedStatsCliApp.d \
	$C/src/ocean/util/app/VersionedLoggedCliApp.d \
	$C/src/ocean/util/app/VersionedCliApp.d \
	$C/src/ocean/util/app/ConfiguredCliApp.d \
	$C/src/ocean/util/app/LoggedCliApp.d \
	$C/src/ocean/util/app/ConfiguredApp.d \
	$C/src/ocean/util/app/CommandLineApp.d \
	$C/src/ocean/text/util/StringReplace.d \
	$C/src/ocean/text/utf/UtfConvert.d \
	$C/src/ocean/io/compress/lzo/c/lzo_crc.d \
	$C/src/ocean/io/selector/model/ISelector.d \
	$C/src/ocean/io/selector/AbstractSelector.d \
	$C/src/ocean/io/selector/EpollSelector.d \
	$C/src/ocean/io/selector/PollSelector.d \
	$C/src/ocean/io/selector/SelectSelector.d \
	$C/src/ocean/io/selector/Selector.d \
	$C/src/ocean/io/selector/SelectorException.d \
	$C/src/ocean/io/select/client/IntervalClock.d \
	$C/src/ocean/io/select/client/Scheduler.d \
	$C/src/tango/io/selector/model/ISelector.d \
	$C/src/tango/io/selector/AbstractSelector.d \
	$C/src/tango/io/selector/EpollSelector.d \
	$C/src/tango/io/selector/PollSelector.d \
	$C/src/tango/io/selector/SelectSelector.d \
	$C/src/tango/io/selector/Selector.d \
	$C/src/tango/io/selector/SelectorException.d

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
else
# Open source Makd uses dmd by default
DC = dmd-transitional
override DFLAGS += -de
endif

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
