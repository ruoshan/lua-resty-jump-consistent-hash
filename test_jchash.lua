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

for i = 1, 10000 do
    local id = hash(i, buckets) + 1
    count[id] = count[id] + 1
end

print("hash = count, hash outcome distribution(before)")
for i = 1, buckets do
    print(tostring(i) .. " = " .. tostring(count[i]))
end

print("\n\n")

local hit = 0
local mis = 0

for i = 1, buckets do
    count[i] = 0
end

for i = 1, 10000 do
    local id_before = hash(i, buckets) + 1
    local id_after = hash(i, buckets - buckets/3) + 1
    count[id_after] = count[id_after] + 1
    if id_before == id_after then
        hit = hit + 1
    else
        mis = mis + 1
    end
end

print("derease bucket size to 2/3")
print("hit = " .. tostring(hit) .. ", mis = " .. tostring(mis))

print("\n\n")

print("hash = count, hash outcome distribution(after)")
for i = 1, buckets do
    print(tostring(i) .. " = " .. tostring(count[i]))
end
