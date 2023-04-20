local Utils = require("automaton.utils")

local Schema = {
    VERSION = "1.0.0",

    common = {
        "version",
        "default",
        "quickfix",
        "type",
        "name",
        "depends",
        "args",
        "detach",
    },

    config = {
        "name",
        "label",
        "choices",
        "default",
    }
}

Schema.tasks = vim.list_extend({
    "tasks",
    "command",
}, Schema.common)

Schema.launch = vim.list_extend({
    "configurations",
    "program",
}, Schema.common)

function Schema.load_file(filepath, fallback)
    local schema = Utils.read_json(filepath)

    if schema then
        if schema.version == nil then
            error("Missing 'version' field")
        elseif schema.version ~= Schema.VERSION then
            error("Expected version '" .. Schema.VERSION .. "', got '" .. tostring(schema.version) .. "'")
        end

        return schema
    end

    return fallback
end

return Schema
