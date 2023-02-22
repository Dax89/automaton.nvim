local Pattern = require("automaton.pattern")
local Utils = require("automaton.utils")
local Dialogs = require("automaton.dialogs")
local Previewers = require("telescope.previewers")
local EntryDisplay = require("telescope.pickers.entry_display")
local JSON5 = require("automaton.json5")

local Runner = {
    jobs = { },

    LAUNCH = "LAUNCH",
    TASK = "TASK",
}

function Runner.show_jobs(config)
    if vim.tbl_isempty(Runner.jobs) then
        vim.notify("Job queue is empty")
        return
    end

    local displayer = EntryDisplay.create({
        separator = " ",
        items = {
            { width = 10 },
            { width = 6 },
            { width = 1 },
            { remaining = true },
        },
    })

    local make_display = function(entry)
        return displayer({
            { entry.pid, "TelescopeResultsNumber" },
            { entry.type, "TelescopeResultsIdentifier" },
            config.icons[entry.value.jobtype:lower()],
            entry.ws:get_name() .. ": \"" .. entry.name .. "\"",
        })
    end

    Dialogs.select(vim.tbl_values(Runner.jobs), {
        prompt_title = "Running Jobs",

        entry_maker = function(e)
            return {
                display = make_display,
                ordinal = e.name,
                name = e.name,
                pid = vim.fn.jobpid(e.jobid),
                type = e.jobtype,
                ws = e.ws,
                value = e,
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

function Runner._run(ws, cmd, e, onsuccess)
    e = e or { }
    e.ws = ws

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

        options.on_exit = function(id, code, _)
            Runner._append_quickfix(">>> Job terminated with code " .. code)

            if vim.is_callable(onsuccess) and code == 0 then
                onsuccess()
            end

            Runner.jobs[id] = nil
        end
    end

    e.jobid = vim.fn.jobstart(cmd, options)

    if options.detach ~= true then
        Runner.jobs[e.jobid] = e
    end
end

function Runner._run_shell(ws, cmd, options, onsuccess)
    local runcmd = cmd.command

    if vim.tbl_islist(cmd.args) then
        for _, arg in ipairs(cmd.args) do
            runcmd = runcmd .. " " .. arg
        end
    end

    Runner._run(ws, runcmd, options, onsuccess)
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

function Runner._run_process(ws, cmd, options, onsuccess)
    local runcmd = Runner._parse_program(cmd, options)
    Runner._run(ws, runcmd, options, onsuccess)
end

function Runner.run(ws, t, onsuccess)
    local cmd = Runner.extract_commands(t, "command")
    t.jobtype = Runner.TASK

    if t.type == "shell" then
        Runner._run_shell(ws, cmd, t, onsuccess)
    elseif t.type == "process" then
        Runner._run_process(ws, cmd, t, onsuccess)
    else
        error(string.format("Invalid task type: '%s'", t.type))
    end
end

function Runner.launch(ws, l, debug)
    debug = vim.F.if_nil(debug, false)
    local cmd = Runner.extract_commands(l, "program")

    if debug then
        Runner._append_quickfix(">>> " .. Runner._parse_program(cmd, true))
        local ok, dap = pcall(require, "dap")
        if not ok then error("DAP is not installed") end
        dap.run(l)
    else
        l.jobtype = Runner.TASK
        Runner._run_process(ws, cmd, l)
    end
end

return Runner
