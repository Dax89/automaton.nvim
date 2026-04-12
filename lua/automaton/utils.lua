local Utils = {}

Utils.colors = {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37
}

function Utils.colorize(s, color)
    return string.format("\027[%dm%s\027[0m", color, s)
end

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
    assert(vim.islist(t))
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
    local result = {}

    for line in s:gmatch("[^\n]+") do
        table.insert(result, line)
    end

    return result
end

function Utils.get_number_of_cores()
    return #vim.tbl_keys(vim.uv.cpu_info())
end

function Utils.get_parent(p)
    return vim.fn.fnamemodify(p, ":h")
end

function Utils.get_stem(p)
    local filename = vim.fs.basename(p)
    local idx = filename:match(".*%.()")
    if idx == nil then return filename end
    return filename:sub(0, idx - 2)
end

function Utils.is_root_path(p)
    local sep = package.config:sub(1, 1)

    if sep == '\\' then
        return string.match(p, "^[A-Z]:\\?$")
    end

    return p == sep
end

function Utils.read_dir(path, options)
    options = options or {}

    return vim
        .iter(vim.fs.dir(path))
        :map(function(name, type)
            if not vim.startswith(name, ".") and
                (not options.only_dirs or (options.only_dirs and type == "directory")) then
                return vim.fs.joinpath(path, name)
            end
        end)
        :totable()
end

function Utils.get_plugin_root()
    local this_path = debug.getinfo(1).source:sub(2)

    if package.config:sub(1, 1) == '\\' then
        -- we are on windows. debug.getinfo(1).source incorrectly returns
        -- a path using '/' as path separator.
        this_path = this_path:gsub("/", "\\")
    end

    return Utils.get_parent(this_path)
end

function Utils.copy_to(src, dst)
    vim.fn.mkdir(dst, "p")

    for name, type in vim.fs.dir(src) do
        local s = vim.fs.joinpath(src, name)
        local d = vim.fs.joinpath(dst, name)

        if type == "directory" then
            Utils.copy_to(s, d)
        else
            vim.uv.fs_copyfile(s, d)
        end
    end
end

function Utils.list_reverse(l)
    vim.validate("l", l, vim.islist)

    local rev = {}

    for i = #l, 1, -1 do
        rev[#rev + 1] = l[i]
    end

    return rev
end

function Utils.cmdline_split(s)
    local cmd, w = {}, {}
    local quote, escape = false, false

    for c in s:gmatch(".") do
        if not escape and c == '\\' then
            escape = true
        else
            table.insert(w, c)

            if c == '"' and not escape then
                quote = not quote
            elseif c == ' ' and not quote and not escape then
                table.remove(w, #w) -- Remove Last ' '
                table.insert(cmd, table.concat(w))
                w = {}
            end

            if escape then
                escape = false
            end
        end
    end

    if #w > 0 then -- Check last word
        table.insert(cmd, table.concat(w))
    end

    return cmd
end

function Utils.osopen_command()
    local uname = vim.uv.os_uname().sysname
    local cmd = nil

    if uname == "Windows" or uname == "Windows_NT" then
        cmd = "cmd /c start"
    elseif uname == "Darwin" then
        cmd = "open"
    elseif uname == "Linux" then
        cmd = "xdg-open"
    else
        error("Unsupported Platform '" .. uname .. "'")
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
