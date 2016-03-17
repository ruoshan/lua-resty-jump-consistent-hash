PREFIX ?= /usr/local/openresty
LUA_LIB_DIR ?=$(PREFIX)/lualib
CFLAGS := -Wall -O3 -g -fPIC

all: so

so: jchash.o
	$(CC) $(CFLAGS) -shared -o libjchash.so jchash.o

jchash.o: jchash.c
	$(CC) $(CFLAGS) -c jchash.c


test: so
	$(CC) test_jchash.c -l jchash -L./ -o test


.PHONY:
clean:
	@rm -vf *.o test *.so

install:
	$(INSTALL) -m0644 lib/resty/jchash.lua $(DESTDIR)$(LUA_LIB_DIR)/resty
	$(INSTALL) libjchash.so $(DESTDIR)$(LUA_LIB_DIR)/libjchash.so
