local function set(v)
    local r = { }
    if type(v) == "table" then
        for _, vv in ipairs(v) do
            r[vv] = true
        end
    else
        for c in v:gmatch(".") do
            r[c] = true
        end
    end

    return r
end

local function enum(items)
    assert(type(items) == "table")

    local r = { }
    for i, v in ipairs(items) do r[v] = i end
    return r
end

local String = function(arg)
    local meta = {
        __tostring = function(self) return table.concat(self.buffer) end,
    }

    meta.__index = meta
    local instance = { count = 0, buffer = { } }

    function instance:clear() self.count = 0 end

    function instance:append(s)
        local i = 0

        for c in s:gmatch(".") do
            i = i + 1
            self.buffer[self.count + i] = c
        end

        self.count = self.count + i
    end

    if arg then instance:append(arg) end
    return setmetatable(instance, meta)
end

return {
    set = set,
    enum = enum,
    String = String,
}
