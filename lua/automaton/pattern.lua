local Pattern = { }

-- https://neovim.io/doc/user/luaref.html#luaref-patterns
-- https://neovim.io/doc/user/builtin.html#setqflist()

function Pattern.error_to_qflist(err)
    err = err:upper()

    if string.len(err) > 0 then
        return err[1]
    end

    return "G" -- General Purpose
end

function Pattern.to_qflist(p, r)
    local qf = { }

    for t, idx in pairs(p) do
        if t ~= "pattern" then -- Skip 'pattern' key
            if r[idx] ~= nil then
                qf[t] = t == "type" and Pattern.error_to_qflist(r[idx]) or r[idx]
            else
                return nil
            end
        end
    end

    return qf
end

function Pattern.resolve(line, e)
    local problems = vim.F.if_nil(e.problems, { })
    local patterns = vim.F.if_nil(problems.patterns, { })

    for _, p in ipairs(patterns) do
        local r = {line:match(p.pattern)}

        if not vim.tbl_isempty(r) then
            local qf = Pattern.to_qflist(p, r)

            if qf then
                return qf
            end
        end
    end

    return line
end

return Pattern
