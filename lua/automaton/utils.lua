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
