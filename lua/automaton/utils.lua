local Utils = { }

function Utils.starts_with(s, start)
    return s:sub(1, string.len(start)) == start
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

    if uname == "Windows" then cmd = "cmd /c start"
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
    return vim.json.decode(Utils.read_file(filepath))
end

function Utils.write_json(filepath, json)
    Utils.write_file(filepath, vim.json.encode(json))
end

return Utils
