local SchemaSource = { }

function SchemaSource.new(automaton)
    return setmetatable({
        automaton = automaton
    }, { __index = SchemaSource })
end

function SchemaSource:complete(request, callback)
    local Cmp = require("cmp")
    local Schema = require("automaton.schema")
    local type = request.context.filetype:sub(#"automaton" + 1)

    callback({
        items = vim.tbl_map(function(x)
            return {
                label = x,
                kind = Cmp.lsp.CompletionItemKind.Field
            }
        end, Schema[type] or {}),
    })
end

return SchemaSource
