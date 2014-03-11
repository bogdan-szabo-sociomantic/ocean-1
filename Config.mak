
# We are ocean, this is a special case
OCEAN_PATH := $T

# Modules to exclude from testing
TEST_FILTER_OUT += \
	$T/src/ocean/time/timeout/ExpiryPoolTimeoutManager.d \
	$T/src/ocean/io/select/model/ITimeoutSelectClient.d \
	$T/src/ocean/io/compress/ZlibStream.d \
	$T/src/ocean/io/compress/Zlib.d \
	$T/src/ocean/db/tokyocabinet/c/tctdb.d \
	$T/src/ocean/db/tokyocabinet/TokyoCabinetB.d \
	$T/src/ocean/db/tokyocabinet/TokyoCabinetH.d \
	$T/src/ocean/util/app/ConfiguredApp.d \
	$T/src/ocean/util/app/ConsoleToolApp.d \
	$T/src/ocean/util/Profiler.d \
	$T/src/ocean/util/MemUsage.d \
	$T/src/ocean/io/Retry.d \
	$T/src/ocean/db/sqlite/SQLite.d \
	$T/src/ocean/db/mysql/MySQL.d

