local jchash = require "resty.chash.jchash"

local ok, new_table = pcall(require, "table.new")
if not ok then
    new_table = function (narr, nrec) return {} end
end

local function svname(server)
    -- @server: {addr, port, id}
    -- @return: concat the addr and port with ":" as seperator
    return server[1] .. ":" .. tostring(server[2]) .. "#" .. tostring(server[3])
end

local function init_name2index(servers)
    -- map server name to index
    local map = {}
    for index, s in ipairs(servers) do
        -- name is just the concat of addr and port
        map[ svname(s) ] = index
    end
    return map
end

local function expand_servers(servers)
    -- expand servers list of {addr, port, weight} into a list of {addr, port, id}
    local total_weight = 0
    for _, s in ipairs(servers) do
        total_weight = total_weight + (s[3] or 1)
    end

    local expanded_servers = new_table(total_weight, 0)
    local weight
    for _, s in ipairs(servers) do
        weight = s[3] or 1
        for id = 1, weight do
            expanded_servers[#expanded_servers + 1] = {s[1], s[2], id}
        end
    end
    assert(#expanded_servers == total_weight, "expand_servers size not match")
    return expanded_servers
end

local function update_name2index(old_servers, new_servers)
    -- new servers may have some servers of the same name in the old ones.
    -- we could assign the same index(if in range) to the server of same name,
    -- and as to new servers whose name are new will be assigned to indexs that're
    -- not occupied

    local old_name2index = init_name2index(old_servers)
    local new_name2index = init_name2index(new_servers)
    local new_size = #new_servers  -- new_size is also the maxmuim index
    local old_size = #old_servers

    local unused_indexs = {}

    for old_index, old_sv in ipairs(old_servers) do
        if old_index <= new_size then
            local old_sv_name = svname(old_sv)
            if new_name2index[ old_sv_name ] then
                -- restore the old_index
                new_name2index[ old_sv_name ] = old_index
            else
                -- old_index can be recycled
                unused_indexs[#unused_indexs + 1] = old_index
            end
        else
            -- index that exceed maxmium index is of no use, we should mark it nil.
            -- the next next loop (assigning unused_indexs) will make use of this mark
            old_name2index[ svname(old_sv) ] = nil
        end
    end

    for i = old_size + 1, new_size do  -- only loop when old_size < new_size
        unused_indexs[#unused_indexs + 1] = i
    end

    -- assign the unused_indexs to the real new servers
    local index = 1
    for _, new_sv in ipairs(new_servers) do
        local new_sv_name = svname(new_sv)
        if not old_name2index[ new_sv_name ] then
            -- it's a new server, or an old server whose old index is too big
            assert(index <= #unused_indexs, "no enough indexs for new server")
            new_name2index[ new_sv_name ] = unused_indexs[index]
            index = index + 1
        end
    end
    assert(index == #unused_indexs + 1, "recycled indexs are not exhausted")

    return new_name2index
end


local _M = {}
local mt = { __index = _M }

function _M.new(servers)
    assert(servers, "nil servers")
    return setmetatable({servers = expand_servers(servers)}, mt)
end

-- instance methods

function _M.lookup(self, key)
    -- @key: user defined string, eg. uri
    -- @return: {addr, port, id}
    -- the `id` is a number in [1, weight], to identify server of same addr and port,
    local index = jchash.hash_short_str(key, #self.servers)
    return self.servers[index]
end

function _M.update_servers(self, new_servers)
    -- @new_servers: remove all old servers, and use the new servers
    --               but we would keep the server whose name is not changed
    --               in the same `id` slot, so consistence is maintained.
    assert(new_servers, "nil new_servers")
    local old_servers = self.servers
    local new_servers = expand_servers(new_servers)
    local name2index = update_name2index(old_servers, new_servers)
    self.servers = new_table(#new_servers, 0)

    for _, s in ipairs(new_servers) do
        self.servers[name2index[ svname(s) ]] = s
    end
end

function _M.debug(self)
    print("* Instance Info *")
    print("* size: " .. tostring(#self.servers))
    print("* servers -> id ")
    for id, s in ipairs(self.servers) do
        print(svname(s) .. " -> " .. tostring(id))
    end
    print("\n")
end

function _M.dump(self)
    -- @return: deepcopy a self.servers
    -- this can be use to save the server list to a file or something
    -- and restore it back some time later. eg. nginx restart/reload
    --
    -- please NOTE: the data being dumped is not the same as the data we
    -- use to do _M.new or _M.update_servers, though it looks the same, the third
    -- field in the {addr, port, id} is an `id`, NOT a `weight`
    local servers = {}
    for index, sv in ipairs(self.servers) do
        servers[index] = {sv[1], sv[2], sv[3]} -- {addr, port, id}
    end
    return servers
end

function _M.restore(self, servers)
    assert(servers, "nil servers")
    -- restore servers from dump (deepcopy the servers)
    self.servers = {}
    for index, sv in ipairs(servers) do
        self.servers[index] = {sv[1], sv[2], sv[3]}
    end
end

_M._VERSION = "0.1.0"

return _M
