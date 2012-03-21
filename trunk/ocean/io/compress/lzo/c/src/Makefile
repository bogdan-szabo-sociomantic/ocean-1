# Mini LZO library Makefile
# 
# Author: David Eckardt
#
# Unfortunately lzo_crc32() is missing in minilzo.c so it is needs to be added
# as lzo_crc.c.

NAMESTEM  = minilzo
STATICLIB = lib$(NAMESTEM).a
SHAREDLIB = lib$(NAMESTEM).so

ARCH := 32

OBJ       = minilzo.o lzo_crc.o

all: $(STATICLIB) $(SHAREDLIB)

.PHONY: cleanup clean all

$(STATICLIB): $(OBJ)
	ar rs $@ $^
	
$(SHAREDLIB): $(OBJ)
	gcc -shared -m$(ARCH) -o $@ $^
	
%.o: %.c
	gcc -fPIC -m$(ARCH) -Os -march=native -o $@ -c $<

cleanup:
	rm -f $(OBJ)
	
clean: cleanup
	rm -f $(STATICLIB) $(SHAREDLIB)
