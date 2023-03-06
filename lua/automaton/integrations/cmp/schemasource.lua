local SchemaSource = { }

function SchemaSource.new(automaton)
    return setmetatable({
        automaton = automaton
    }, { __index = SchemaSource })
end

function SchemaSource:complete(request, callback)
    local Schema = require("automaton.schema")
    local type = request.context.filetype:sub(#"automaton" + 1)

    -- local input = request.context.cursor_before_line:sub(request.offset - 1)
    -- local prefix = request.context.cursor_before_line:sub(1, request.offset - 1)

    callback({
        items = vim.tbl_map(function(x)
            return { label = x }
        end, Schema[type] or {}),
    })
end

return SchemaSource
