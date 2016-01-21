override DFLAGS += -w

ifeq ($(DVER),1)
override DFLAGS += -v2 -v2=-static-arr-params -v2=-volatile
endif

override RDMDFLAGS += --extra-file=$C/src/tango/core/Version.d

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-ltokyocabinet -lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt
