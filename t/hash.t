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

=== TEST 0: hash func
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash = require "resty.chash.jchash"
                local random_str = "a06fdeed699ba9e75996b0e268daed0c"
                local i = jchash.hash_short_str(random_str, 0)
                if i ~= 0 then
                    return ngx.say("nok 1")
                end

                i = jchash.hash_long_str(random_str, 1)
                if i ~= 1 then
                    return ngx.say("nok 2")
                end

                local N = 31
                for i = 1, 10000 do
                    local j = jchash.hash_int(i, N)
                    if j > N or j < 1 then
                        return ngx.say("nok 3")
                    end
                end

                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: hash distribution
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash = require "resty.chash.jchash"
                local mt = { __index = function(t, k) return 0 end }
                local count = setmetatable({}, mt)
                local N = 5
                local TOTAL = 10000
                local AVG = TOTAL / 5
                for i = 1, TOTAL do
                    local j = jchash.hash_int(i, N)
                    count[j] = count[j] + 1
                end

                for i = 1, N do
                    if math.abs(count[i] - AVG) > (AVG * 0.1) then
                        return ngx.say("nok 1")
                    end
                end
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok

=== TEST 0: rehash distribution
--- http_config eval: $::HttpConfig
--- config
        location = / {
            content_by_lua_block {
                local jchash = require "resty.chash.jchash"
                local N = 6
                local TOTAL = 10000
                local hit = 0
                local mis = 0
                for i = 1, TOTAL do
                    local j = jchash.hash_int(i, N)
                    local k = jchash.hash_int(i, N * 2)
                    if j == k then
                        hit = hit + 1
                    else
                        mis = mis + 1
                    end
                end
                if math.abs(hit / TOTAL - 0.5) > 0.01 then
                    return ngx.say("nok 1")
                end
                -- `hit` approximates `mis`
                ngx.say("ok")
            }
        }
--- request
GET /
--- response_body
ok
