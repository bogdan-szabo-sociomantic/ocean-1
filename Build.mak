
# Modules to exclude from testing because they are broken
TEST_FILTER_OUT += \
	$C/src/ocean/io/compress/ZlibStream.d \
	$C/src/ocean/io/compress/Zlib.d \
	$C/src/ocean/io/Retry.d

# Link unittests to all used libraries
$O/unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-ltokyocabinet -llzo2 -lreadline -lhistory

# Temporary rules for high level tests
# MakD will take care of that soon

test-cache: $O/cache
	$O/cache

$O/cache: test/cache/main.d
	rdmd1 -of$@ --build-only -I./src -L-lebtree -unittest -version=UnitTest -debug=UnitTest -g $<

test += test-cache
