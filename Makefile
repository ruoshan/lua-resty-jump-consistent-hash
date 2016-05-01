PREFIX ?= /usr/local/openresty
LUA_LIB_DIR ?=$(PREFIX)/lualib
CFLAGS := -Wall -O3 -g -fPIC
INSTALL ?= install

all: libjchash.so

libjchash.so: jchash.o
	$(CC) $(CFLAGS) -shared -o libjchash.so jchash.o

jchash.o: jchash.c
	$(CC) $(CFLAGS) -c jchash.c

test: libjchash.so
	prove t/*.t


.PHONY:
clean:
	@rm -vf *.o test *.so

install: all
	$(INSTALL) -d $(DESTDIR)$(LUA_LIB_DIR)/resty/chash
	$(INSTALL) -m0644 lib/resty/chash/*.lua $(DESTDIR)$(LUA_LIB_DIR)/resty/chash
	$(INSTALL) libjchash.so $(DESTDIR)$(LUA_LIB_DIR)/libjchash.so
