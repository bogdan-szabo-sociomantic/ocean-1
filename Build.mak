
# Modules to exclude from testing
TEST_FILTER_OUT += \
	$C/src/ocean/io/compress/ZlibStream.d \
	$C/src/ocean/io/compress/Zlib.d \
	$C/src/ocean/io/Retry.d

# Link particular tests with the appropriate libraries they need
$U/src/ocean/text/utf/UtfUtil \
$U/src/ocean/text/utf/GlibUnicode \
$U/src/ocean/text/utf/UtfConvert \
$U/src/ocean/net/http/HttpResponse \
$U/src/ocean/net/http/cookie/HttpCookieGenerator \
$U/src/ocean/net/http/cookie/HttpCookieParser \
$U/src/ocean/net/http/cookie/CookiesHttpResponse \
$U/src/ocean/net/http/HttpConnectionHandler \
$U/src/ocean/net/http/HttpRequest \
$U/src/ocean/net/http/message/HttpHeader \
$U/src/ocean/net/http/message/HttpHeaderParser \
$U/src/ocean/net/util/QueryParams \
$U/src/ocean/net/util/UrlDecoder \
$U/src/ocean/net/util/ParamSet \
$U/src/ocean/io/console/StructTable \
$U/src/ocean/io/console/Tables \
$U/src/ocean/text/url/PercentEncoding: \
	override LDFLAGS += -lglib-2.0

$U/src/ocean/text/regex/PCRE: \
	override LDFLAGS += -lpcre

$U/src/ocean/text/xml/Xslt: \
	override LDFLAGS += -lxslt

$U/src/ocean/core/Cache \
$U/src/ocean/util/container/cache/model/containers/TimeToIndex \
$U/src/ocean/util/container/cache/model/containers/KeyToNode \
$U/src/ocean/util/container/cache/model/ITrackCreateTimesCache \
$U/src/ocean/util/container/cache/model/ICache \
$U/src/ocean/util/container/cache/Cache \
$U/src/ocean/util/container/cache/ExpiringCache \
$U/src/ocean/util/container/cache/CachingDataLoader \
$U/src/ocean/util/container/cache/CachingStructLoader \
$U/src/ocean/time/timeout/model/ExpiryRegistrationBase \
$U/src/ocean/time/timeout/TimeoutManager \
$U/src/ocean/io/select/client/Scheduler \
$U/src/ocean/io/select/timeout/TimerEventTimeoutManager \
$U/src/ocean/util/container/ebtree/%: \
	override LDFLAGS += -lebtree

$U/src/ocean/db/tokyocabinet/c/tcbdb \
$U/src/ocean/db/tokyocabinet/c/tctdb \
$U/src/ocean/db/tokyocabinet/c/bdb/tcbdbcur \
$U/src/ocean/db/tokyocabinet/util/TokyoCabinetList \
$U/src/ocean/db/tokyocabinet/util/TokyoCabinetCursor \
$U/src/ocean/db/tokyocabinet/util/TokyoCabinetExtString \
$U/src/ocean/db/tokyocabinet/TokyoCabinetB \
$U/src/ocean/db/tokyocabinet/TokyoCabinetH \
$U/src/ocean/db/tokyocabinet/TokyoCabinetM: \
	override LDFLAGS += -ltokyocabinet

$U/src/ocean/io/compress/lzo/c/lzo_crc: \
	override LDFLAGS += -llzo2

