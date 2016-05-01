# vim: ft=perl

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');
no_long_string();

repeat_each(1);

plan tests => repeat_each() * blocks() * 2;

my $pwd = cwd();
our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "$pwd/?.so;;";
};

run_tests();

__DATA__

=== TEST 0: new chash servers
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash_server = require "resty.chash.server"

                local servers, err = jchash_server.new({{"127.0.0.1", 80, -1}})
                if not err then
                    return ngx.say("nok 1")
                end

                local servers, err = jchash_server.new({{127, 80, 1}})
                if not err then
                    return ngx.say("nok 2")
                end

                local WEIGHT = 7
                local servers_1 = {
                    { "127.0.0.1", 8081, WEIGHT }
                }
                local servers, err = jchash_server.new(servers_1)
                if not servers then
                    return ngx.say("nok 3")
                end
                if servers:size() ~= WEIGHT then
                    return ngx.say("nok 4")
                end
                local r = servers:lookup("abc")
                local host = r[1]
                local port = r[2]
                if host ~= "127.0.0.1" or port ~= 8081 then
                    return ngx.say("nok 5")
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: update chash servers
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash_server = require "resty.chash.server"

                local servers_1 = {
                    { "127.0.0.1", 8081 }
                }
                local servers_2 = {
                    { "127.0.0.2", 8082, 2 }
                }
                local servers = jchash_server.new(servers_1)
                servers:update_servers(servers_2)
                local r = servers:lookup("abc")
                local host = r[1]
                local port = r[2]
                if host ~= "127.0.0.2" or port ~= 8082 then
                    return ngx.say("nok 1")
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: distribution: same size
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash_server = require "resty.chash.server"
                local old = {
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                    {"127.0.0.3", 80},
                }

                local new = {
                    {"127.0.0.4", 80},
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                }

                local cs, err = jchash_server.new(old)

                local match_keys = {}
                for k = 1, 10000 do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        match_keys[#match_keys + 1] = k
                    end
                end

                cs:update_servers(new)

                local hit, mis = 0, 0
                for _, k in ipairs(match_keys) do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        hit = hit + 1
                    else
                        mis = mis + 1
                    end
                end

                if mis ~= 0 then
                    return ngx.say("nok")
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: distribution: decrease size
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash_server = require "resty.chash.server"
                local old = {
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                    {"127.0.0.3", 80},
                }

                local new = {
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                }

                local cs, err = jchash_server.new(old)

                local match_keys = {}
                for k = 1, 10000 do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        match_keys[#match_keys + 1] = k
                    end
                end

                cs:update_servers(new)

                local hit, mis = 0, 0
                for _, k in ipairs(match_keys) do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        hit = hit + 1
                    else
                        mis = mis + 1
                    end
                end

                if mis ~= 0 then
                    return ngx.say("nok")
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: distribution: increase size
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash_server = require "resty.chash.server"
                local old = {
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                    {"127.0.0.3", 80},
                }

                local new = {
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                    {"127.0.0.3", 80},
                    {"127.0.0.4", 80},
                    {"127.0.0.5", 80},
                    {"127.0.0.6", 80},
                }

                local cs, err = jchash_server.new(old)

                local match_keys = {}
                for k = 1, 10000 do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        match_keys[#match_keys + 1] = k
                    end
                end

                cs:update_servers(new)

                local hit, mis = 0, 0
                for _, k in ipairs(match_keys) do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        hit = hit + 1
                    else
                        mis = mis + 1
                    end
                end

                if math.abs((hit/(hit + mis) - 0.5)) > 0.01 then
                    return ngx.say("nok")
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: distribution: increase size using weight
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash_server = require "resty.chash.server"
                local old = {
                    {"127.0.0.1", 80},
                    {"127.0.0.2", 80},
                    {"127.0.0.3", 80},
                    {"127.0.0.4", 80},
                    {"127.0.0.5", 80},
                    {"127.0.0.6", 80},
                }

                local new = {
                    {"127.0.0.1", 80, 2},
                    {"127.0.0.2", 80, 2},
                    {"127.0.0.3", 80, 2},
                }

                local cs, err = jchash_server.new(old)

                local match_keys = {}
                for k = 1, 10000 do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        match_keys[#match_keys + 1] = k
                    end
                end

                cs:update_servers(new)

                local hit, mis = 0, 0
                for _, k in ipairs(match_keys) do
                    local sv = cs:lookup(tostring(k))
                    if sv[1] == old[2][1] then
                        hit = hit + 1
                    else
                        mis = mis + 1
                    end
                end

                if mis ~= 0 then
                    return ngx.say("nok")
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok
