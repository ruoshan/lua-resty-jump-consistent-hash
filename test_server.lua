package.path = "./lib/?.lua;;"

local chash_server = require "resty.chash.server"
local jchash = require "resty.chash.jchash"

local servers1 = {
    {"127.0.0.1", 80},
    {"127.0.0.2", 80},
    {"127.0.0.3", 80},
}

local servers2 = {
    {"127.0.0.4", 80},
    {"127.0.0.1", 80},
    {"127.0.0.2", 80},
}

local server3 = {
    {"127.0.0.1", 80},
    {"127.0.0.2", 80},
}

local servers4 = {
    {"127.0.0.1", 80},
    {"127.0.0.2", 80},
    {"127.0.0.3", 80},
    {"127.0.0.4", 80},
    {"127.0.0.5", 80},
    {"127.0.0.6", 80},
}

local servers5 = {
    {"127.0.0.1", 80, 2},
    {"127.0.0.2", 80, 2},
    {"127.0.0.3", 80, 2},
}

local function test_update_servers(old, new)
    local cs = chash_server.new(old)
    cs:debug()

    local match_keys = {}
    for k = 1, 10000 do
        local sv = cs:lookup(tostring(k))
        if sv[1] == old[2][1] then
            match_keys[#match_keys + 1] = k
        end
    end

    cs:update_servers(new)
    cs:debug()

    local hit, mis = 0, 0
    for _, k in ipairs(match_keys) do
        local sv = cs:lookup(tostring(k))
        if sv[1] == old[2][1] then
            hit = hit + 1
        else
            mis = mis + 1
        end
        --assert(sv[1] == servers1[2][1], "failed: " .. sv[1] .. " != " .. servers1[2][1])
    end
    print("hit=", hit, ", mis=", mis)
    return hit, mis
end

print("testing hit/miss after updating servers")
local hit, mis = test_update_servers(servers1, servers2) -- same size
assert(mis == 0, "test_same_size failed")

local hit, mis = test_update_servers(servers1, servers3) -- decreases size
assert(mis == 0, "test_smaller_size failed")

local hit, mis = test_update_servers(servers1, servers4) -- increases size
assert( math.abs((hit/(hit + mis) - 0.5)) < 0.01, "test_larger_size failed")

local hit, mis = test_update_servers(servers4, servers5) -- same size with weight
assert(mis == 0, "test_same_size with weight failed")

print("all good")
