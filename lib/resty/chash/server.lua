local jchash = require "resty.chash.jchash"

local ok, new_table = pcall(require, "table.new")
if not ok then
    new_table = function (narr, nrec) return {} end
end

local function svname(server)
    -- @server: {addr, port, id}
    -- @return: concat the addr and port with ":" as seperator
    return string.format("%s:%s#%s", tostring(server[1]), tostring(server[2]), tostring(server[3]))
end

local function init_name2index(servers)
    -- map server name to index
    local map = {}
    for index, s in ipairs(servers) do
        -- name is just the concat of addr , port and inner id
        map[ svname(s) ] = index
    end
    return map
end

local function expand_servers(servers)  --> list<{addr, port, id}>, err
    -- expand servers list of {addr, port, weight} into a list of {addr, port, id}
    local total_weight = 0
    for _, s in ipairs(servers) do
        local weight = s[3] or 1
        if weight < 1 then
            return nil, "invalid weight found"
        end
        total_weight = total_weight + weight
    end

    local expanded_servers = new_table(total_weight, 0)
    for _, s in ipairs(servers) do
        local addr = s[1]
        local port = s[2]
        if type(addr) ~= "string" or type(port) ~= "number" then
            return nil, "invalid type of addr or port"
        end
        local weight = s[3] or 1
        for id = 1, weight do
            expanded_servers[#expanded_servers + 1] = {addr, port, id}
        end
    end
    if #expanded_servers ~= total_weight then
        return nil, "expanded servers' size mismatch"
    end
    return expanded_servers, nil
end

local function update_name2index(old_servers, new_servers)  --> dict[svname]:idx
    -- new servers may have some servers of the same name in the old ones.
    -- we could assign the same index(if in range) to the server of same name,
    -- and as to new servers whose name are new will be assigned to indexes that're
    -- not occupied

    local old_name2index = init_name2index(old_servers)
    local new_name2index = init_name2index(new_servers)
    local new_size = #new_servers  -- new_size is also the maxmuim index
    local old_size = #old_servers

    local unused_indexes = {}

    for old_index, old_sv in ipairs(old_servers) do
        if old_index <= new_size then
            local old_sv_name = svname(old_sv)
            if new_name2index[ old_sv_name ] then
                -- restore the old_index
                new_name2index[ old_sv_name ] = old_index
            else
                -- old_index can be recycled
                unused_indexes[#unused_indexes + 1] = old_index
            end
        else
            -- index that exceed maxmium index is of no use, we should mark it nil.
            -- the next next loop (assigning unused_indexes) will make use of this mark
            old_name2index[ svname(old_sv) ] = nil
        end
    end

    for i = old_size + 1, new_size do  -- only loop when old_size < new_size
        unused_indexes[#unused_indexes + 1] = i
    end

    -- assign the unused_indexes to the real new servers
    local index = 1
    for _, new_sv in ipairs(new_servers) do
        local new_sv_name = svname(new_sv)
        if not old_name2index[ new_sv_name ] then
            -- it's a new server, or an old server whose old index is too big
            assert(unused_indexes[index] ~= nil, "invalid index")
            new_name2index[ new_sv_name ] = unused_indexes[index]
            index = index + 1
        end
    end

    return new_name2index
end


local _M = {}
local mt = { __index = _M }

function _M.new(servers)  --> instance/nil, err
    if not servers then
        return nil, "nil servers"
    end

    local expanded_servers, err = expand_servers(servers)
    if err then
        return nil, err
    end
    return setmetatable({servers = expanded_servers}, mt)
end

-- instance methods

function _M.size(self)  --> num
    return #self.servers
end

function _M.lookup(self, key)  --> server/nil
    -- @key: user defined string, eg. uri
    -- @return: {addr, port, id}
    -- the `id` is a number in [1, weight], to identify server of same addr and port,
    if #self.servers == 0 or not key then
        return nil
    end
    local index = jchash.hash_short_str(key, #self.servers)
    return self.servers[index]
end

function _M.update_servers(self, new_servers)  --> ok, err
    -- @new_servers: remove all old servers, and use the new servers
    --               but we would keep the server whose name is not changed
    --               in the same `id` slot, so consistence is maintained.
    if not new_servers then
        return false, "nil servers"
    end
    local old_servers = self.servers
    local new_servers, err = expand_servers(new_servers)
    if err then
        return false, err
    end
    local name2index = update_name2index(old_servers, new_servers)
    self.servers = new_table(#new_servers, 0)

    for _, s in ipairs(new_servers) do
        self.servers[name2index[ svname(s) ]] = s
    end
    return true, nil
end

function _M.dump(self)  --> list<{addr, port, id}>
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
    if not servers then
        return
    end
    -- restore servers from dump (deepcopy the servers)
    self.servers = {}
    for index, sv in ipairs(servers) do
        self.servers[index] = {sv[1], sv[2], sv[3]}
    end
end

_M._VERSION = "0.1.3"

return _M
