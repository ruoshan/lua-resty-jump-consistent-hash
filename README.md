## Jump Consisten Hash for luajit
a simple implementation of [this paper](http://arxiv.org/pdf/1406.2294.pdf).

## Installation
```
make
make PREFIX=/usr/local/openresty install
```

## Usage

```
local jchash = require "resty.jchash"

local buckets = 8
local id = jchash.hash("random key", buckets)
```

## Test
> todo
```
make test
./test
luajit-2.1.0-alpha
```
