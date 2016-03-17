local ffi = require "ffi"

ffi.cdef[[
int32_t jump_consistent_hash(uint64_t key, int32_t num_buckets);
]]


local function load_shared_lib(so_name)
    local string_gmatch = string.gmatch
    local string_match = string.match
    local io_open = io.open
    local io_close = io.close

    local cpath = package.cpath

    for k, _ in string_gmatch(cpath, "[^;]+") do
        local fpath = string_match(k, "(.*/)")
        fpath = fpath .. so_name

        local f = io_open(fpath)
        if f ~= nil then
            io_close(f)
            return ffi.load(fpath)
        end
    end
end


local clib = load_shared_lib("libjchash.so")
if not clib then
    error("can not load libjchash.so")
end

local _M = {}
local mt = { __index = _M }

function _M.hash_short_str(key, size)
    -- do the simple consisten hash
    -- @key: string, the string to hash
    -- @size: the maxmium value this func might return
    -- @return: a number between [1, size]
    local key2int = ngx.crc32_short(key)
    return clib.jump_consistent_hash(key2int, size) + 1
end

function _M.hash_long_str(key, size)
    -- @key: string, the string to hash
    -- @size: the maxmium value this func might return
    -- @return: a number between [1, size]
    local key2int = ngx.crc32_long(key)
    return clib.jump_consistent_hash(key2int, size) + 1
end

function _M.hash_int(key, size)
    -- @key: integer
    -- @size: the maxmium value this func might return
    -- @return: a number between [1, size]
    return clib.jump_consistent_hash(key, size) + 1
end

return _M
