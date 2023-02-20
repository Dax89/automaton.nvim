local Pattern = require("automaton.pattern")
local Utils = require("automaton.utils")

local Runner = { }

function Runner.clear_quickfix(e)
    vim.fn.setqflist({ }, " ", {title = vim.F.if_nil(e.name, "Output")})
end

function Runner._open_quickfix()
    vim.api.nvim_command("copen")
end

function Runner._scroll_quickfix()
    if vim.bo.buftype ~= "quickfix" then
        vim.api.nvim_command("cbottom")
    end
end

function Runner._append_quickfix(line)
    if type(line) == "string" then
        vim.fn.setqflist({ }, "a", {lines = {line}})
    elseif type(line) == "table" then
        vim.fn.setqflist({line}, "a")
    else
        return
    end

    Runner._scroll_quickfix()
end

function Runner._append_output(lines, e)
    for _, line in ipairs(lines) do
        if string.len(line) > 0 then
            local res = Pattern.resolve(line, e)

            if res then
                Runner._append_quickfix(res)
            end
        end
    end
end

function Runner.extract_commands(e, cmdkey)
    local osname = vim.loop.os_uname().sysname:lower()

    local cmd = {
        command = nil,
        args = nil
    }

    if type(e[osname]) == "table" then
        cmd.command = vim.F.if_nil(e[osname][cmdkey], e[cmdkey])
        cmd.args = vim.F.if_nil(e[osname].args, e.args)
    else
        cmd.command = e[cmdkey]
        cmd.args = e.args
    end

    return cmd
end

function Runner._run(cmd, e, onsuccess)
    e = e or { }

    local options = {
        cwd = e.cwd,
        env = e.env,
        detach = e.detach,
    }

    if options.detach ~= true then
        Runner._open_quickfix()
        vim.api.nvim_command("wincmd p") -- Go Back to the previous window
        Runner._append_quickfix(">>> " .. (type(cmd) == "table" and table.concat(cmd, " ") or cmd))

        options.on_stdout = function(_, lines, _) Runner._append_output(lines, e) end
        options.on_stderr = function(_, lines, _) Runner._append_output(lines, e) end

        options.on_exit = function(_, code, _)
            Runner._append_quickfix(">>> Job terminated with code " .. code)

            if vim.is_callable(onsuccess) and code == 0 then
                onsuccess()
            end
        end
    end

    vim.fn.jobstart(cmd, options)
end

function Runner._run_shell(cmd, options, onsuccess)
    local runcmd = cmd.command

    if vim.tbl_islist(cmd.args) then
        for _, arg in ipairs(cmd.args) do
            runcmd = runcmd .. " " .. arg
        end
    end

    Runner._run(runcmd, options, onsuccess)
end

function Runner._parse_program(cmd, concat)
    local runcmd = {}

    if type(cmd.command) == "string" then
        runcmd = Utils.cmdline_split(cmd.command)
    else
        runcmd = {cmd.command}
    end

    if vim.tbl_islist(cmd.args) then
        vim.list_extend(runcmd, cmd.args)
    end

    return concat and table.concat(runcmd, " ") or runcmd
end

function Runner._run_process(cmd, options, onsuccess)
    local runcmd = Runner._parse_program(cmd, options)
    Runner._run(runcmd, options, onsuccess)
end

function Runner.run(t, onsuccess)
    local cmd = Runner.extract_commands(t, "command")

    if t.type == "shell" then
        Runner._run_shell(cmd, t, onsuccess)
    elseif t.type == "process" then
        Runner._run_process(cmd, t, onsuccess)
    else
        error(string.format("Invalid task type: '%s'", t.type))
    end
end

function Runner.launch(l, debug)
    debug = vim.F.if_nil(debug, false)
    local cmd = Runner.extract_commands(l, "program")

    if debug then
        Runner._append_quickfix(">>> " .. Runner._parse_program(cmd, true))
        local ok, dap = pcall(require, "dap")
        if not ok then error("DAP is not installed") end
        dap.run(l)
    else
        Runner._run_process(cmd, l)
    end
end

return Runner
