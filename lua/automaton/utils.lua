local Utils = { }

Utils.dirsep = (vim.loop.os_uname().sysname == "Windows" or vim.loop.os_uname().sysname == "Windows_NT") and "\\" or "/"

function Utils.get_visual_selection()
    local _, ssrow, sscol, _ = unpack(vim.fn.getpos("'<"))
    local _, serow, secol, _ = unpack(vim.fn.getpos("'>"))
    local nlines = math.abs(serow - ssrow) + 1

    local lines = vim.api.nvim_buf_get_lines(0, ssrow - 1, serow, false)
    if vim.tbl_isempty(lines) then return "" end

    lines[1] = string.sub(lines[1], sscol, -1)

    if nlines == 1 then
        lines[nlines] = string.sub(lines[nlines], 1, secol - sscol + 1)
    else
        lines[nlines] = string.sub(lines[nlines], 1, secol)
    end

    return table.concat(lines, "\n")
end

function Utils.list_reinsert(t, inv, cmp)
    assert(vim.tbl_islist(t))
    if not cmp then cmp = function(a, b) return a == b end end

    local idx = 0

    for i, v in ipairs(t) do
        if cmp(v, inv) then
            idx = i
            break
        end
    end

    if idx > 0 then
        table.remove(t, idx)
    end

    table.insert(t, 1, inv)
end

function Utils.split_lines(s)
    local result = { }

    for line in s:gmatch("[^\n]+") do
        table.insert(result, line)
    end

    return result
end

function Utils.get_number_of_cores()
    return #vim.tbl_keys(vim.loop.cpu_info())
end

function Utils.get_plugin_root()
    return tostring(require("plenary.path"):new(debug.getinfo(1).source:sub(2)):parent())
end

function Utils.get_filename(p)
    return vim.fn.fnamemodify(tostring(p), ":t")
end

function Utils.get_stem(p)
    local filename = Utils.get_filename(p)
    local idx = filename:match(".*%.()")
    if idx == nil then return filename end
    return filename:sub(0, idx - 2)
end

function Utils.list_reverse(l)
    vim.validate({
        l = {1, function() return vim.tbl_islist(l) end}
    })

    local rev = { }

    for i = #l, 1, -1 do
        rev[#rev + 1] = l[i]
    end

    return rev
end

function Utils.cmdline_split(s)
    local cmd, w = { }, { }
    local quote, escape = false, false

    for c in s:gmatch(".") do
        table.insert(w, c)

        if c == '\\' then
            escape = true
        elseif c == '"' and not escape then
            quote = not quote
        elseif c == ' ' and not quote and not escape then
            table.remove(w, #w) -- Remove Last ' '
            table.insert(cmd, table.concat(w))
            w = { }
        elseif escape then
            escape = false
        end
    end

    if #w > 0 then -- Check last word
        table.insert(cmd, table.concat(w))
    end

    return cmd
end

function Utils.osopen_command()
    local uname = vim.loop.os_uname().sysname
    local cmd = nil

    if uname == "Windows" or uname == "Windows_NT" then cmd = "cmd /c start"
    elseif uname == "Darwin" then cmd = "open"
    elseif uname == "Linux" then cmd = "xdg-open"
    else error("Unsupported Platform '" .. uname .. "'")
    end

    return cmd
end

function Utils.read_file(filepath)
    local f = require("io").open(tostring(filepath), "r")

    if f then
        local data = f:read("*all")
        f:close()
        return data
    end

    error("Cannot read file '" .. tostring(filepath) .. "'")
end

function Utils.write_file(filepath, data)
    local f = require("io").open(tostring(filepath), "w")

    if f then
        f:write(data)
        f:close()
    else
        print("Cannot write file '" .. tostring(filepath) .. "'")
    end
end

function Utils.read_json(filepath)
    local JSON5 = require("automaton.json5")
    return JSON5.parse(Utils.read_file(filepath))
end

function Utils.write_json(filepath, json, indent)
    local JSON5 = require("automaton.json5")
    Utils.write_file(filepath, JSON5.stringify(json, indent))
end

return Utils
