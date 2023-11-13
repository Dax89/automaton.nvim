local Pattern = require("automaton.pattern")
local Utils = require("automaton.utils")
local Dialogs = require("automaton.dialogs")
local Previewers = require("telescope.previewers")
local JSON5 = require("automaton.json5")

local Runner = {
    jobs = {},
    termchanid = nil,
    termwinid = nil,
    termbufid = nil,

    LAUNCH = "LAUNCH",
    TASK = "TASK",
}

function Runner.show_jobs(config)
    if vim.tbl_isempty(Runner.jobs) then
        vim.notify("Job queue is empty")
        return
    end

    Dialogs.table(vim.tbl_values(Runner.jobs), {
        prompt_title = "Running Jobs",

        columns = {
            { width = 1 },
            { width = 6 },
            { width = 10 },
            { remaining = true },
        },

        entry_maker = function(e)
            return {
                ordinal = e.name,
                name = e.name,
                pid = vim.fn.jobpid(e.jobid),
                type = e.jobtype,
                ws = e.ws,
                value = e,
            }
        end,

        displayer = function(e)
            return {
                config.icons[e.value.jobtype:lower()],
                { e.type, "TelescopeResultsIdentifier" },
                { e.pid,  "TelescopeResultsNumber" },
                e.ws:get_name() .. ": \"" .. e.name .. "\"",
            }
        end,

        previewer = Previewers.new_buffer_previewer({
            dyn_title = function(_, e) return e.name end,
            define_preview = function(self, e)
                vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "json")

                local v = vim.deepcopy(e.value)
                v.ws = nil -- Remove Workspace before apply serialization
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, Utils.split_lines(JSON5.stringify(v, 2)))
            end
        }),
    }, function(e)
        vim.fn.jobstop(e.value.jobid)
    end)
end

function Runner.close_terminal()
    if Runner.termbufid ~= nil then
        if vim.fn.winbufnr(Runner.termbufid) ~= -1 then
            vim.api.nvim_win_close(Runner.termwinid, true)
        end

        vim.api.nvim_command("silent! :bd! " .. tostring(Runner.termbufid))

        Runner.termchanid = nil
        Runner.termbufid = nil
        Runner.termwinid = nil
    end
end

function Runner.clear_quickfix(e)
    vim.fn.setqflist({}, " ", { title = vim.F.if_nil(e.name, "Output") })
end

function Runner._open_quickfix()
    vim.api.nvim_command("copen")
end

function Runner._close_quickfix()
    vim.api.nvim_command("cclose")
end

function Runner._scroll_output()
    if Runner.termbufid ~= nil then
        if Runner.termbufid ~= vim.api.nvim_get_current_buf() then
            vim.fn.win_execute(Runner.termwinid, "norm G")
        end
    elseif vim.bo.buftype ~= "quickfix" then
        vim.api.nvim_command("cbottom")
    end
end

function Runner._append_line(line)
    -- HACK: https://github.com/neovim/neovim/issues/14557
    local sendlines = function(x)
        local lines = vim.split(x, "\n")
        for _, l in ipairs(lines) do
            if l ~= "" then
                vim.api.nvim_chan_send(Runner.termchanid, l)
                vim.api.nvim_chan_send(Runner.termchanid, "\r\n")
            end
        end
    end

    if type(line) == "string" then
        if Runner.termbufid ~= nil then
            sendlines(line)
        else
            vim.fn.setqflist({}, "a", { lines = { line } })
        end
    elseif type(line) == "table" then
        if Runner.termbufid ~= nil then
            for _, l in ipairs(line) do
                sendlines(l)
            end
        else
            vim.fn.setqflist({ line }, "a")
        end
    else
        return
    end

    Runner._scroll_output()
end

function Runner._append_output(lines, e)
    if e.quickfix == true then
        for _, line in ipairs(lines) do
            if string.len(line) > 0 then
                local res = Pattern.resolve(line, e)

                if res then
                    Runner._append_line(res)
                end
            end
        end
    else
        Runner._append_line(lines)
    end
end

function Runner.select_os_command(e, cmdkey)
    local osname = vim.loop.os_uname().sysname:lower()

    local cmds = {
        command = nil,
        args = nil
    }

    if type(e[osname]) == "table" then
        cmds.command = vim.F.if_nil(e[osname][cmdkey], e[cmdkey])

        -- If command is a list, args doesn't make sense
        if not vim.tbl_islist(cmds.command) then
            cmds.args = vim.F.if_nil(e[osname].args, e.args)
        end
    else
        cmds.command = e[cmdkey]

        -- If command is a list, args doesn't make sense
        if not vim.tbl_islist(cmds.command) then
            cmds.args = e.args
        end
    end

    return cmds
end

function Runner._colorize(s, color, e)
    if e.quickfix == true then
        return s
    end

    return Utils.colorize(s, color)
end

function Runner._run(config, ws, cmds, e, onexit, i)
    assert(vim.tbl_islist(cmds))
    i = i or 1

    if i > #cmds then
        return
    end

    e = e or {}
    e.ws = ws

    local options = {
        cwd = e.cwd,
        env = e.env,
        detach = e.detach,
    }

    if options.detach ~= true then
        if e.quickfix == true then
            Runner._open_quickfix()
            vim.api.nvim_command("wincmd p") -- Go Back to the previous window
        else
            options.pty = true
        end

        local handleoutput = function(_, lines, _)
            Runner._append_output(lines, e)
        end

        options.on_stdout = handleoutput
        options.on_stderr = handleoutput

        options.on_exit = function(id, code, _)
            local cmdlen, fmt = #cmds, nil
            local rescolor = code == 0 and Utils.colors.green or Utils.colors.red

            if cmdlen > 1 then
                fmt = string.format(">>> Job %d/%d terminated with code %d", i, cmdlen, code)
            else
                fmt = string.format(">>> Job terminated with code %d", code)
            end

            Runner._append_line(Runner._colorize(fmt, rescolor, e))

            if code ~= 0 or i == #cmds then
                if vim.is_callable(onexit) then
                    onexit(code)
                end
            else
                Runner._run(config, ws, cmds, e, onexit, i + 1)
            end

            Runner.jobs[id] = nil
        end
    end

    local startjob = function()
        if e.detach == true then
            vim.fn.jobstart(cmds[i], options)
            return
        end

        if e.quickfix == true then
            Runner.close_terminal()
            e.jobid = vim.fn.jobstart(cmds[i], options)
        else
            Runner._close_quickfix()

            if Runner.termbufid == nil or vim.fn.getbufinfo(Runner.termbufid)[1].hidden == 1 then
                Runner.close_terminal()
                vim.api.nvim_command(vim.F.if_nil(config.terminal.position, "botright") .. " split")
                Runner.termwinid = vim.api.nvim_get_current_win()
                Runner.termbufid = vim.api.nvim_create_buf(false, true)
                Runner.termchanid = vim.api.nvim_open_term(Runner.termbufid, {})
                vim.api.nvim_win_set_buf(Runner.termwinid, Runner.termbufid)
                vim.api.nvim_buf_set_name(Runner.termbufid, e.name)
                vim.api.nvim_command("resize " .. tostring(vim.F.if_nil(config.terminal.size, 10)))
            end

            Runner._append_line(
                Runner._colorize(">>> " .. (type(cmds[i]) == "table" and table.concat(cmds[i], " ") or cmds[i]),
                    config.terminal.cmdcolor, e))

            e.jobid = vim.fn.jobstart(cmds[i], options)
            vim.api.nvim_command("wincmd p") -- Go Back to the previous window
        end

        Runner.jobs[e.jobid] = e
    end

    local ok, err = pcall(startjob)

    if not ok then
        vim.notify(err)

        if vim.is_callable(onexit) then
            onexit(-1)
        end
    end
end

function Runner._run_shell(config, ws, oscmd, options, onexit)
    local runcmds = Runner._parse_command(oscmd)
    Runner._run(config, ws, runcmds, options, onexit)
end

function Runner._run_process(config, ws, cmds, options, onexit)
    local runcmds = Runner._parse_program(cmds, options)
    Runner._run(config, ws, runcmds, options, onexit)
end

function Runner._parse_command(oscmd)
    local cmds = vim.tbl_islist(oscmd.command) and oscmd.command or { oscmd }
    local runcmds = {}

    for _, cmd in ipairs(cmds) do
        local runcmd = { cmd.command or cmd }

        if vim.tbl_islist(cmd.args) then
            vim.list_extend(runcmd, cmd.args)
        end

        table.insert(runcmds, table.concat(runcmd, " "))
    end

    return runcmds
end

function Runner._parse_program(oscmd, concat)
    local cmds = vim.tbl_islist(oscmd.command) and oscmd.command or { oscmd }
    local runcmds = {}

    for _, cmd in ipairs(cmds) do
        local c = cmd.command or cmd
        local runcmd = {}

        if type(c) == "string" then
            runcmd = Utils.cmdline_split(c)
        else
            runcmd = { c }
        end

        if vim.tbl_islist(cmd.args) then
            vim.list_extend(runcmd, cmd.args)
        end

        table.insert(runcmds, concat and table.concat(runcmd, " ") or runcmd)
    end

    return runcmds
end

function Runner.run(config, ws, t, onexit)
    local oscmd = Runner.select_os_command(t, "command")
    t.jobtype = Runner.TASK

    if t.type == "shell" then
        Runner._run_shell(config, ws, oscmd, t, onexit)
    elseif t.type == "process" then
        Runner._run_process(config, ws, oscmd, t, onexit)
    else
        error(string.format("Invalid task type: '%s'", t.type))
    end
end

function Runner.launch(config, ws, l, debug, onexit)
    debug = vim.F.if_nil(debug, false)
    local oscmd = Runner.select_os_command(l, "program")

    if debug then
        Runner._close_quickfix()
        Runner.close_terminal()
        local ok, dap = pcall(require, "dap")
        if not ok then error("DAP is not installed") end
        dap.run(l)
    else
        l.jobtype = Runner.TASK
        Runner._run_process(config, ws, oscmd, l, onexit)
    end
end

return Runner
