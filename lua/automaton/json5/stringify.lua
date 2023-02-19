local Stringify = { }

function Stringify.is_list(obj)
    if type(obj) ~= "table" then return false end
    local c = 0

    for k, _ in pairs(obj) do
        if type(k) == "number" then c = c + 1
        else return false
        end
    end

    return c > 0
end

function Stringify.space(s, n) for _ = 1, math.max(n or 0, 0) do s:append(" ") end end
function Stringify.nl_indent(s, indent) s:append(indent > 0 and "\n" or "") end
function Stringify.comma_sep(s, indent) s:append(indent > 0 and ", " or ",")end

function Stringify.unescape_string(str)
    local ITEMS = {
        ["\\\n"] = ""
    }

    for k, v in pairs(ITEMS) do
        str = str:gsub(k, v)
    end

    return str
end

function Stringify.key(s, v)
    local t = type(v)
    if t == "number"  then Stringify.walk_string(s, tostring(v))
    elseif t == "string" then Stringify.walk_identifier(s, v) -- TODO: Handle "classic json" too
    else error("Type '" .. t .. "' is not a valid json key")
    end
end

function Stringify.walk_list(s, obj, indent, level)
    s:append("[")
    if indent and next(obj) then Stringify.nl_indent(s, indent) end

    local i = 0

    for _, v in pairs(obj) do
        if i > 0 then
            Stringify.comma_sep(s, indent)
            Stringify.nl_indent(s, indent)
        end

        Stringify.walk(s, v, indent, level + 1, true)
        i = i + 1
    end

    if i > 0 then
        Stringify.nl_indent(s, indent)
        Stringify.space(s, (indent * (level - 1)))
    end

    s:append("]")
end

function Stringify.walk_object(s, obj, indent, level)
    s:append("{")
    if indent and next(obj) then Stringify.nl_indent(s, indent) end

    local i = 0

    for k, v in pairs(obj) do
        assert(type(k) == "string")

        if i > 0 then
            Stringify.comma_sep(s, indent)
            Stringify.nl_indent(s, indent)
        end

        Stringify.space(s, indent * level)
        Stringify.key(s, k)
        s:append(": ")
        Stringify.walk(s, v, indent, level, false)
        i = i + 1
    end

    if i > 0 then
        Stringify.nl_indent(s, indent)
        Stringify.space(s, (indent * (level - 1)))
    end

    s:append("}")
end

function Stringify.walk_identifier(s, v) s:append(v) end
function Stringify.walk_string(s, v) s:append("\"") s:append(Stringify.unescape_string(v)) s:append("\"") end
function Stringify.walk_number(s, v) s:append(tostring(v)) end
function Stringify.walk_boolean(s, v) s:append(tostring(v)) end
function Stringify.walk_nil(s) s:append("null") end

function Stringify.walk(s, obj, indent, level, startindent)
    local t = type(obj)

    if startindent ~= false then Stringify.space(s, (indent * (level - 1))) end

    if t == "table" then
        if Stringify.is_list(obj) then Stringify.walk_list(s, obj, indent, level + 1)
        else Stringify.walk_object(s, obj, indent, level + 1)
        end
    elseif t == "string" then Stringify.walk_string(s, obj)
    elseif t == "number" then Stringify.walk_number(s, obj)
    elseif t == "boolean" then Stringify.walk_boolean(s, obj)
    elseif t == "nil" then Stringify.walk_nil(s)
    else error("Unexpected type '" .. t .. "'")
    end
end

return Stringify
