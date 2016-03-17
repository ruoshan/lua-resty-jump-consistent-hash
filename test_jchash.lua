local ffi = require "ffi"

ffi.cdef[[
int32_t jump_consistent_hash(uint64_t key, int32_t num_buckets);
]]


local clib = ffi.load("./libjchash.so")
if not clib then
    error("can not load libjchash.so")
end

local function hash(key, size)
    return clib.jump_consistent_hash(key, size)
end

local count = {}
local buckets = 8
for i = 1, buckets do
    count[i] = 0
end

for i = 1, 1000 do
    local id = hash(i, buckets) + 1
    count[id] = count[id] + 1
end

for i = 1, buckets do
    print(tostring(i) .. " = " .. tostring(count[i]))
end
