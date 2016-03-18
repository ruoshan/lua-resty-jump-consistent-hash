local jchash = require "resty.chash.jchash"

local ok, new_table = pcall(require, "table.new")
if not ok then
    new_table = function (narr, nrec) return {} end
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

local function svname(server)
    -- @server: {addr, port}
    -- @return: concat the addr and port with ":" as seperator
    return tostring(server[1] .. ":" .. tostring(server[2]))
end

local function init_name2id(servers)
    -- map server name to ID
    local map = {}
    for id, s in ipairs(servers) do
        -- name is just the concat of addr and port
        map[ svname(s) ] = id
    end
    return map
end

local function update_name2id(old_servers, new_servers)
    -- new servers may have some servers of the same name in the old ones.
    -- we could assign the same id(if in range) to the server of same name,
    -- and as to new servers whose name are new will be assigned to
    -- one of the IDs there're available

    local old_name2id = init_name2id(old_servers)
    local new_name2id = init_name2id(new_servers)
    local new_size = #new_servers  -- new_size is also the maxmuim ID
    local old_size = #old_servers

    local unused_ids = {}

    for old_id, old_sv in ipairs(old_servers) do
        if old_id <= new_size then
            local old_sv_name = svname(old_sv)
            if new_name2id[ old_sv_name ] then
                -- restore the old_id
                new_name2id[ old_sv_name ] = old_id
            else
                -- old_id can be recycled
                unused_ids[#unused_ids + 1] = old_id
            end
        else
            -- ID that exceed maxmium ID is of no use, we should mark it nil.
            -- the next next loop (assigning unused_ids) will make use of this mark
            old_name2id[ svname(old_sv) ] = nil
        end
    end

    for i = old_size + 1, new_size do  -- only loop when old_size < new_size
        unused_ids[#unused_ids + 1] = i
    end

    -- assign the unused_ids to the real new servers
    local index = 1
    for _, new_sv in ipairs(new_servers) do
        local new_sv_name = svname(new_sv)
        if not old_name2id[ new_sv_name ] then
            -- it's a new server, or an old server whose old ID is too big
            assert(index <= #unused_ids, "no enough IDs for new server")
            new_name2id[ new_sv_name ] = unused_ids[index]
            index = index + 1
        end
    end
    assert(index == #unused_ids + 1, "recycled IDs are not exhausted")

    return new_name2id
end


local _M = {}
local mt = { __index = _M }

function _M.new(servers)
    if not servers then
        return
    end
    local name2id = init_name2id(servers)
    local ins = { servers = deepcopy(servers), name2id = name2id, size=#servers }
    return setmetatable(ins, mt)
end

-- instance methods

function _M.lookup(self, key)
    -- @key: user defined string, eg. uri
    -- @return: tuple {addr, port}
    local id = jchash.hash_short_str(key, self.size)
    return self.servers[id]
end

function _M.update_servers(self, new_servers)
    -- @new_servers: remove all old servers, and use the new servers
    --               but we would keep the server whose name is not changed
    --               in the same `id` slot, so consistence is maintained.
    if not new_servers then
        return
    end
    local old_servers = self.servers
    local new_servers = deepcopy(new_servers)
    self.size = #new_servers
    self.name2id = update_name2id(old_servers, new_servers)
    self.servers = new_table(self.size, 0)

    for _, s in ipairs(new_servers) do
        self.servers[self.name2id[ svname(s) ]] = s
    end
end

function _M.debug(self)
    print("*****************")
    print("* size: " .. tostring(self.size))
    print("* servers: ")
    for _, s in ipairs(self.servers) do
        print(svname(s))
    end
    print("* name2id map:")
    for k, v in pairs(self.name2id) do
        print(k .. " = " .. v)
    end
end

return _M
