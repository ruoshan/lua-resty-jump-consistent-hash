PREFIX ?= /usr/local/openresty
LUA_LIB_DIR ?=$(PREFIX)/lualib
CFLAGS := -Wall -O3 -g -fPIC
INSTALL ?= install

all: so

so: jchash.o
	$(CC) $(CFLAGS) -shared -o libjchash.so jchash.o

jchash.o: jchash.c
	$(CC) $(CFLAGS) -c jchash.c


test: so
	$(CC) test_jchash.c -l jchash -L./ -o test
	./test
	resty test_jchash.lua
	resty test_server.lua


.PHONY:
clean:
	@rm -vf *.o test *.so

install:
	$(INSTALL) -d $(DESTDIR)$(LUA_LIB_DIR)/resty/chash
	$(INSTALL) -m0644 lib/resty/chash/*.lua $(DESTDIR)$(LUA_LIB_DIR)/resty/chash
	$(INSTALL) libjchash.so $(DESTDIR)$(LUA_LIB_DIR)/libjchash.so
