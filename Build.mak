
# Modules to exclude from testing because they are broken
TEST_FILTER_OUT += \
	$C/src/ocean/io/compress/ZlibStream.d \
	$C/src/ocean/io/compress/Zlib.d \
	$C/src/ocean/io/Retry.d

# Link unittests to all used libraries
$O/unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxslt -lebtree \
		-ltokyocabinet -llzo2

