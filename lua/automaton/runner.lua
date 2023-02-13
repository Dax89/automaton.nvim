local Runner = { }

function Runner._open_quickfix()
    vim.api.nvim_command("copen")
end

function Runner._scroll_quickfix()
    if vim.bo.buftype ~= "quickfix" then
        vim.api.nvim_command("cbottom")
    end
end

function Runner._clear_quickfix(title)
    vim.fn.setqflist({ }, " ", {title = title})
end

function Runner._append_quickfix(lines)
    if type(lines) == "string" then
        lines = {lines}
    end

    vim.fn.setqflist({ }, "a", {lines = lines})
    Runner._scroll_quickfix()
end

function Runner._show_output(_, data, _)
    Runner._append_quickfix(vim.tbl_filter(function(x)
        return #x > 0
    end, data))
end

function Runner._run(cmd, options)
    options = options or { }

    Runner._open_quickfix()
    vim.api.nvim_command("wincmd p") -- Go Back to the previous window
    Runner._clear_quickfix(options.name or "Output")
    Runner._append_quickfix(">>> " .. (type(cmd) == "table" and table.concat(cmd, " ") or cmd))

    vim.fn.jobstart(cmd, {
        cwd = options.cwd,
        env = options.env,

        on_stdout = Runner._show_output,
        on_stderr = Runner._show_output,

        on_exit = function(_, code, _)
            Runner._append_quickfix(">>> Job terminated with code " .. code)
        end
    })
end

function Runner._run_shell(cmd, options)
    local runcmd = cmd

    if vim.tbl_islist(options.args) then
        for _, arg in ipairs(options.args) do
            runcmd = runcmd .. " " .. arg
        end
    end

    Runner._run(runcmd, options)
end

function Runner._run_process(cmd, options)
    local runcmd = {cmd}

    if vim.tbl_islist(options.args) then
        vim.list_extend(runcmd, options.args)
    end

    Runner._run(runcmd, options)
end

function Runner.run(t)
    if t.type == "shell" then
        Runner._run_shell(t.command, t)
    elseif t.type == "process" then
        Runner._run_process(t.command, t)
    else
        error(string.format("Invalid task type: '%s'", t.type))
    end
end

function Runner.launch(l, debug)
    debug = vim.F.if_nil(debug, false)

    if debug then
        local ok, dap = pcall(require, "dap")
        if not ok then error("DAP is not installed") end
        dap.run(l)
    else
        Runner._run_process(l.program, l)
    end
end

return Runner
