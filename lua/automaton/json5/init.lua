local JSON5 = { }

function JSON5.parse(s, options)
    assert(type(s) == "string")
    options = options or { }

    local Parse = require("automaton.json5.parse")

    if options.dump_tokens then
        Parse(s):dump_tokens()
    end

    return Parse(s):walk()
end

function JSON5.stringify(obj, indent)
    local common = require("automaton.json5.common")
    local Stringify = require("automaton.json5.stringify")
    indent = indent or 0

    local s = common.String()
    Stringify.walk(s, obj, indent, 0)
    return tostring(s)
end

return JSON5
