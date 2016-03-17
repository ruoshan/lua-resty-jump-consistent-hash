package.path = "./lib/?.lua;;"

local chash_server = require "resty.chash.server"

local servers = {
    {"127.0.0.1", 80},
    {"127.0.0.2", 80},
    {"127.0.0.3", 80},
}

local servers2 = {
    {"127.0.0.4", 80},
    {"127.0.0.6", 80},
    {"127.0.0.5", 80},
}

local servers3 = {
    {"127.0.0.4", 80},
    {"127.0.0.5", 80},
}

local servers4 = {
    {"127.0.0.4", 80},
    {"127.0.0.5", 80},
    {"127.0.0.6", 80},
    {"127.0.0.7", 80},
    {"127.0.0.8", 80},
}

local cs = chash_server.new(servers)

local key = "asdfghhhhh"

print(cs:lookup(key)[1])

cs:update_servers(servers2)

print(cs:lookup(key)[1])

cs:update_servers(servers3)

print(cs:lookup(key)[1])

cs:update_servers(servers4)

print(cs:lookup(key)[1])

cs:update_servers(servers3)

print(cs:lookup(key)[1])
