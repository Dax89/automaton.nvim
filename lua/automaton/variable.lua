local function tokenize_string(s)
    local tokenized, len = {}, #s
    local i, start = 1, 1
    local ch = function(_i) return s:sub(_i, _i) end

    while i <= len do
        local c1, c2 = ch(i), ch(i + 1)

        if c1 == '$' and c2 == '{' then
            if i ~= start then
                table.insert(tokenized, {type = "str", value = s:sub(start, i - 1)})
                start = i
            end

            while i <= len and ch(i) ~= '}' do i = i + 1 end

            if start + 2 ~= i then -- Ignore empty variables
                table.insert(tokenized, {type = "var", value = s:sub(start + 2, i - 1)})
            end

            start = i + 1
        end

        i = i + 1
    end

    if start < i then
        table.insert(tokenized, {type = "str", value = s:sub(start, i)})
    end

    return tokenized
end

local function get_variable(name, variables)
    local v = variables

    for n in name:gmatch("([^\\.]+)") do
        if v then v = v[n]
        else break
        end
    end

    return v
end

local function interpolate(s, variables)
    local res, tokens = { }, tokenize_string(s)

    for _, tok in ipairs(tokens) do
        if tok.type == "var" then
            table.insert(res, get_variable(tok.value, variables))
        else
            table.insert(res, tok.value)
        end
    end

    if #tokens == 1 then -- If "tokens" is a single value it can be an object
        return res[1]
    end

    return table.concat(res)
end

local function resolve_all(obj, variables)
    local t = type(obj)

    if t == "table" then
        if vim.tbl_islist(obj) then
            for i, item in ipairs(obj) do
                obj[i] = vim.F.if_nil(resolve_all(item, variables), item)
            end
        else
            for key, value in pairs(obj) do
                obj[key] = vim.F.if_nil(resolve_all(value, variables), value)
            end
        end
    elseif t == "string" then
        return interpolate(obj, variables)
    end

    return obj
end

local Variable = { }

function Variable.resolve(obj, variables)
    return resolve_all(obj, variables)
end

return Variable
