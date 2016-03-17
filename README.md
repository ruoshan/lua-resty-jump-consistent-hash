## Jump Consisten Hash for luajit
a simple implementation of [this paper](http://arxiv.org/pdf/1406.2294.pdf).

## Installation
```
make
make PREFIX=/usr/local/openresty install
```

## Usage

* you can use the basic jchash module to do consisten-hash

```
local jchash = require "resty.chash.jchash"

local buckets = 8
local id = jchash.hash_short_str("random key", buckets)
```

* or you can use the wrapping module `resty.chash.server` to consistent-hash a list of servers

```
local jchash_server = require "resty.chash.server"

local my_servers = {
    { "127.0.0.1", 80 },
    { "127.0.0.2", 80 },
    { "127.0.0.3", 80 }
}

local cs = jchash_server.new(my_servers)
local uri = ngx.var.uri
local svr = cs:lookup(uri)
local addr = svr[1]
local port = svr[2]

-- now you can use the ngx.balancer to do some consistent LB

-- you can even update the servers list, and still maintain the consistence, eg.
local my_new_servers = {
    { "127.0.0.2", 80 },
    { "127.0.0.3", 80 },
    { "127.0.0.4", 80 }
}

cs:update_servers(my_new_servers)
svr = cs:lookup(uri)   -- if the server was 127.0.0.2, then it stays the same,
                       -- as we only update the 127.0.0.4.

-- what's more, consistence is maintained even servers number are changed! eg.
local my_less_servers = {
    { "127.0.0.2", 80 },
    { "127.0.0.3", 80 }
}
cs:update_servers(my_less_servers)
svr = cs:lookup(uri)   -- if the server was 127.0.0.2, then it stays the same,
                       -- if the server was 127.0.0.4, then it has 50% chance to be
                       -- 127.0.0.3 or 127.0.0.4

cs:update_servers(my_new_servers)
svr = cs:lookup(uri)   -- if the server was 127.0.0.2, then it hash 66% chance to stay the same

```

## Test
> TODO

```
make test
./test
luajit-2.1.0-alpha test_jchash.lua
```
