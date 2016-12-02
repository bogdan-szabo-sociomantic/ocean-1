# This will make D2 unittests fail if stomping prevention is triggered
export ASSERT_ON_STOMPING_PREVENTION=1

override DFLAGS += -w -version=GLIBC

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$(shell find $C/src/tango) \
	$C/src/ocean/core/Memory.d \
	$C/src/ocean/util/cipher/RC6.d \
	$C/src/ocean/util/compress/c/bzlib.d \
	$C/src/ocean/io/stream/Bzip.d \
	$C/src/ocean/io/stream/Patterns.d \
	$C/src/ocean/time/Ctime.d \
	$C/src/ocean/core/Enforce_tango.d \
	$C/src/ocean/net/device/SSLSocket.d \
	$C/src/ocean/net/device/Datagram.d \
	$C/src/ocean/net/device/Multicast.d \
	$C/src/ocean/net/http/HttpClient.d \
	$C/src/ocean/net/http/HttpGet.d \
	$C/src/ocean/net/http/HttpPost.d \
	$C/src/ocean/text/Arguments_tango.d \
	$C/src/ocean/text/Regex.d \
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
	$C/src/ocean/util/log/AppendMail.d \
	$C/src/ocean/util/log/AppendSocket.d \
	$C/src/ocean/util/config/ClassFiller.d \
	$C/src/ocean/util/container/HashMap.d \
	$C/src/ocean/util/container/more/CacheMap.d \
	$C/src/ocean/util/container/more/StackMap.d \
	$C/src/ocean/util/cipher/AES.d \
	$C/src/ocean/util/cipher/Blowfish.d \
	$C/src/ocean/util/cipher/Cipher.d \
	$C/src/ocean/util/cipher/HMAC.d \
	$C/src/ocean/util/cipher/misc/Bitwise.d \
	$C/src/ocean/util/cipher/misc/ByteConverter.d \
	$C/src/ocean/util/cipher/misc/Padding.d \
	$C/src/ocean/util/cipher/TEA.d \
	$C/src/ocean/util/cipher/XTEA.d \
	$C/src/ocean/util/cipher/RC4.d \
	$C/src/ocean/util/cipher/Salsa20.d \
	$C/src/ocean/util/cipher/ChaCha.d \
	$C/src/ocean/text/util/StringReplace.d \
	$C/src/ocean/text/xml/Xslt.d \
	$C/src/ocean/text/xml/c/LibXslt.d \
	$C/src/ocean/text/xml/c/LibXml2.d \
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
	$C/src/ocean/io/serialize/XmlStructSerializer.d \
	$C/src/tango/io/selector/model/ISelector.d \
	$C/src/tango/io/selector/AbstractSelector.d \
	$C/src/tango/io/selector/EpollSelector.d \
	$C/src/tango/io/selector/PollSelector.d \
	$C/src/tango/io/selector/SelectSelector.d \
	$C/src/tango/io/selector/Selector.d \
	$C/src/tango/io/selector/SelectorException.d

# This is an integration test that depends on Collectd -- Don't run it
TEST_FILTER_OUT += $C/test/collectd/main.d

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
else
# Open source Makd uses dmd by default
DC = dmd-transitional
override DFLAGS += -de
endif

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

$O/test-unixlistener: override LDFLAGS += -lebtree

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
