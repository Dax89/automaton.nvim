local VariableSource = {
    IGNORE_FT = { state = true, config = true}
}

function VariableSource.new(automaton)
    return setmetatable({
        automaton = automaton
    }, { __index = VariableSource })
end

function VariableSource:get_trigger_characters()
  return { "{", "." }
end

function VariableSource:_extract(q, variables)
    local offset, succ = #q, nil

    while offset >= 1 do
        local ch = q:sub(offset, offset)

        if ch == '$' and succ == '{' then
            break
        end

        succ = ch
        offset = offset - 1
    end

    if offset > 0 then
        q = q:sub(offset)
    end

    local m = q:sub(3)

    if m then
        local parts = vim.split(m, ".", {trimempty = true, plain = true})
        local v = variables

        for _, p in ipairs(parts) do
            if type(v[p]) ~= "table" then
                return vim.empty_dict()
            end

            v = v[p]
        end

        return v
    end

    return variables
end

function VariableSource:complete(request, callback)
    local type = request.context.filetype:sub(#"automaton" + 1)
    local ws = self.automaton.active
    local items = { }

    if ws and not self.IGNORE_FT[type] then
        local curr = request.context.cursor_before_line:sub(request.offset - 1, request.offset - 1)
        local prev = request.context.cursor_before_line:sub(request.offset - 2, request.offset - 2)

        if prev == '$' or curr == "." then
            local variables = self:_extract(request.context.cursor_before_line, ws:get_current_variables(type ~= "variables"))

            items = vim.tbl_map(function(x)
                return {
                    label = x,
                    kind = require("cmp").lsp.CompletionItemKind.Variable,
                    data = variables[x]
                }
            end, vim.tbl_keys(variables))
        end
    end

    callback({items = items})
end

function VariableSource:resolve(completionitem, callback)
    local ws = self.automaton.active

    if ws and type(completionitem.data) ~= "table" then
        completionitem.documentation = {
            kind = require("cmp").lsp.MarkupKind.PlainText,
            value = type(completionitem.data) == "string" and "\"" .. completionitem.data .. "\"" or tostring(completionitem.data)
        }
    end

    callback(completionitem)
end

return VariableSource

