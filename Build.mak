override DFLAGS += -w

ifeq ($(DVER),1)
override DFLAGS += -v2 -v2=-static-arr-params -v2=-volatile
endif

# Modules to exclude from testing because they are broken
TEST_FILTER_OUT += \
	$C/src/ocean/io/compress/ZlibStream.d \
	$C/src/ocean/io/compress/Zlib.d \
	$C/src/ocean/io/Retry.d

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-ltokyocabinet -llzo2 -lreadline -lhistory
