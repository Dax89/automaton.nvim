local common = require("automaton.json5.common")

local ParseMeta = {
    BOOLEAN         = common.set({"true", "false"}),
    IDENTIFIER      = common.set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"),
    STRING_START    = common.set("\"'"),
    DIGITS_START    = common.set(".+-0123456789"),
    DIGITS          = common.set("0123456789."),
    HEXDIGITS       = common.set("0123456789abcdefABCDEF"),
    WHITESPACE      = common.set(" \t\r\n"),
    NULL            = "null",

    Token = common.enum({
        "COLON", "COMMA",
        "NULL", "BOOLEAN",
        "NUMBER", "HEX_NUMBER",
        "STRING", "IDENTIFIER",
        "ARRAY_START", "ARRAY_END",
        "OBJECT_START", "OBJECT_END",
    }),
}

function ParseMeta:create_token(t)
    return {
        s = self.pos,
        e = self.pos,
        type = t,
        pos  = {line = self.line, col = self.col}
    }
end

function ParseMeta:push(token)
    table.insert(self.tokens, token)
    self.tokenlen = self.tokenlen + 1
end

function ParseMeta:at_end() return self.pos > self.len end
function ParseMeta:has_tokens() return self.tokenidx <= self.tokenlen end
function ParseMeta:get_value(token) return self.str:sub(token.s, token.e) end

function ParseMeta:error()
    local token = self.tokens[self.lexing and self.tokenlen or 1]
    error(string.format("Pos: %d/%d, Last Token: [%d:%d] = '%s'", self.pos, self.len, token.pos.line, token.pos.col, self:get_value(token)))
end

function ParseMeta:char(offset)
    if self:at_end() then
        self:error()
    end

    offset = offset or 0
    return self.str:sub(self.pos + offset, self.pos + offset)
end

function ParseMeta:next()
    self.pos = self.pos + 1

    if self:at_end() then
        return nil
    end

    local c = self:char()

    if c == '\n' then
        self.line = self.line + 1
        self.col = 0
    else
        self.col = self.col + 1
    end

    return c
end

function ParseMeta:unexpected(token)
    error("Unexpected token '" .. self:get_value(token) .. "' @ [" .. token.pos.line .. ":" .. token.pos.col .. "]")
end

function ParseMeta:expect(token, types)
    if type(types) == "number" then
        types = {types}
    elseif types == nil then
        return
    end

    for _, t in ipairs(types) do
        if token.type == t then
            return
        end
    end

    self:unexpected(token)
end

function ParseMeta:skip(cb)
    while not self:at_end() and cb(self:char()) do
        self:next()
    end
end

function ParseMeta:tokenize(t, cb)
    local i, token = 1, self:create_token(t)

    while not self:at_end() and cb(self:char(), i) do
        i = i + 1
        self:next()
    end

    token.e = self.pos - 1
    self:push(token)
    return token
end

function ParseMeta:tokenize_atom(t)
    self:push(self:create_token(t))
    self:next()
end

function ParseMeta:skip_comment(start)
    if start == "//" then
        self:skip(function(c) return c ~= "\n" end)
    elseif start == "/*" then
        local prev = ""

        self:skip(function(c)
            if prev == "*" and c == "/" then return false end
            prev = c
            return false
        end)
    else
        error("Invalid comment")
    end
end

function ParseMeta:tokenize_string(quote)
    local escape = false

    self:next() -- "

    self:tokenize(self.Token.STRING, function(c)
        if escape then
            escape = false
            return true
        end

        escape = c == '\\'
        return escape or c ~= quote
   end)

    self:next() -- "
end

function ParseMeta:tokenize_identifier()
    local token = self:tokenize(self.Token.IDENTIFIER, function(c, i)
        if i == 1 then return self.IDENTIFIER[c] end
        return self.IDENTIFIER[c] or self.DIGITS[c]
    end)

    local v = self:get_value(token)
    if v == self.NULL then token.type = self.Token.NULL
    elseif self.BOOLEAN[v] then token.type = self.Token.BOOLEAN
    end
end

function ParseMeta:tokenize_number(base)
    if base == 10 then
        self:tokenize(self.Token.NUMBER, function(c, i)
            if i == 1 then return self.DIGITS_START[c] end
            return self.DIGITS[c] ~= nil
        end)
    elseif base == 16 then
        self:tokenize(self.Token.HEX_NUMBER, function(c, i)
            if i == 1 then return c == '0' end
            if i == 2 then return c == 'x' end
            return self.HEXDIGITS[c] ~= nil
        end)
    else
        error("Base " .. tostring(base) .. " is not valid")
    end
end

function ParseMeta:peek(type, offset)
    if not self:has_tokens() then error("Reached EOF") end
    offset = offset or 0
    local token = self.tokens[self.tokenidx + offset]
    if type ~= nil then self:expect(token, type) end
    return token
end

function ParseMeta:pop(types)
    if not self:has_tokens() then error("Reached EOF") end

    local token = self.tokens[self.tokenidx]
    self.tokenidx = self.tokenidx + 1

    self:expect(token, types)
    return token
end

function ParseMeta:lex()
    self.tokens = { }
    self.tokenidx = 1
    self.tokenlen = 0
    self.lexing = true

    while not self:at_end() do
        self:skip(function(x) return self.WHITESPACE[x] end)

        local c1, c2 = self:char(), nil
        if self.pos + 1 <= self.len then c2 = self:char(1) end

        if (c1 == '/' and c2 == '/') or (c1 == '/' and c2 == '*') then self:skip_comment(c1 .. c2)
        elseif c1 == '0' and c2 == 'x' then self:tokenize_number(16)
        elseif self.DIGITS_START[c1] then self:tokenize_number(10)
        elseif self.IDENTIFIER[c1] then self:tokenize_identifier()
        elseif self.STRING_START[c1] then self:tokenize_string(c1)
        elseif c1 == '{' then self:tokenize_atom(self.Token.OBJECT_START)
        elseif c1 == '}' then self:tokenize_atom(self.Token.OBJECT_END)
        elseif c1 == '[' then self:tokenize_atom(self.Token.ARRAY_START)
        elseif c1 == ']' then self:tokenize_atom(self.Token.ARRAY_END)
        elseif c1 == ',' then self:tokenize_atom(self.Token.COMMA)
        elseif c1 == ':' then self:tokenize_atom(self.Token.COLON)
        else error("Unexpected character '" .. c1 .. "' @ [" .. self.line .. ":" .. self.col .. "]")
        end

        self:skip(function(x) return self.WHITESPACE[x] end)
    end

    self.lexing = false
end

function ParseMeta:walk_array()
    local arr, token = { }, self:pop(self.Token.ARRAY_START)

    if self:peek().type ~= self.Token.ARRAY_END then -- Empty array?
        while token.type ~= self.Token.ARRAY_END do
            table.insert(arr, self:walk())

            token = self:peek()
            if token.type == self.Token.COMMA then
                self:pop()
                token = self:peek()
            end
        end
    end

    token = self:peek()

    if token.type == self.Token.ARRAY_END then
        self:pop()
    else
        self:unexpected(token)
    end

    return arr
end

function ParseMeta:walk_object()
    local obj, token = { }, self:pop(self.Token.OBJECT_START)

    if self:peek().type ~= self.Token.OBJECT_END then -- Empty object?
        while token.type ~= self.Token.OBJECT_END do
            token = self:pop({self.Token.STRING, self.Token.IDENTIFIER})
            self:pop(self.Token.COLON)
            obj[self:get_value(token)] = self:walk()

            token = self:peek()
            if token.type == self.Token.COMMA then
                self:pop()
                token = self:peek()
            end
        end
    end

    token = self:peek()

    if token.type == self.Token.OBJECT_END then
        self:pop()
    else
        self:unexpected(token)
    end

    return obj
end

function ParseMeta:dump_tokens()
    for i, t in ipairs(self.tokens) do
        print(i, "LINE:", t.pos.line, "COL:", t.pos.col, "TYPE:", t.type, "VALUE: ", self:get_value(t))
    end
end

function ParseMeta:walk()
    local res, token = nil, self:peek()

    if token.type == self.Token.OBJECT_START then
        return self:walk_object()
    elseif token.type == self.Token.ARRAY_START then
        return self:walk_array()
    elseif token.type == self.Token.IDENTIFIER or token.type == self.Token.STRING then
        res = self:get_value(token)
    elseif token.type == self.Token.NUMBER then
        res = tonumber(self:get_value(token))
    elseif token.type == self.Token.HEX_NUMBER then
        res = tonumber(self:get_value(token), 16)
    elseif token.type == self.Token.BOOLEAN then
        res = self:get_value(token) == "true"
    elseif token.type == self.Token.NULL then
        res = nil
    else
        self:unexpected(token)
    end

    self:pop()
    return res
end

ParseMeta.__index = ParseMeta

return function(s)
    local instance = setmetatable({
        tokenidx = 1,
        tokenlen = 0,
        tokens = { },
        str = s, len = #s, pos = 1,
        line = 1,
        col = 0,
    }, ParseMeta)

    instance:lex()
    return instance
end

