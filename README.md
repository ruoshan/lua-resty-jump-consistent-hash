## Jump Consisten Hash for luajit
A simple implementation of [this paper](http://arxiv.org/pdf/1406.2294.pdf).

## Features
- small memory footprint and fast
- consistence is maintained through servers' updating

## Installation
```
make
make PREFIX=/usr/local/openresty install
```

## Usage

* you can use the basic jchash module to do consistent-hash
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

-- what's more, consistence is maintained even the number of servers changes! eg.
local my_less_servers = {
    { "127.0.0.2", 80 },
    { "127.0.0.3", 80 }
}
cs:update_servers(my_less_servers)
svr = cs:lookup(uri)   -- if the server was 127.0.0.2, then it stays the same,
                       -- if the server was 127.0.0.4, then it has 50% chance to be
                       -- 127.0.0.3 or 127.0.0.4

cs:update_servers(my_new_servers)
svr = cs:lookup(uri)   -- if the server was 127.0.0.2, then it has 66% chance to stay the same

```

## Todo
- weight for the servers list

## Test
please checkout the `test_server.lua` file, it demonstrates the correct hash distribution
that I intend to maintain after updating servers

```
make test
```
