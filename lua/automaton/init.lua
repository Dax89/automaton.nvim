local Path = require("plenary.path")
local Log = require("plenary.log")
local Utils = require("automaton.utils")
local DefaultConfig = require("automaton.config")
local Workspace = require("automaton.workspace")

local Automaton = {
    storage = Path:new(vim.fn.stdpath("data"), "automaton"),
    workspaces = { },
    config = nil,
    active = nil,
}

function Automaton.get_active_workspace()
    return Automaton.active
end

function Automaton.check_save()
    if Automaton.config.saveall then
        vim.api.nvim_command("silent! :wall")
    end
end

function Automaton.get_templates()
    local templates, Scan = { }, require("plenary.scandir")

    for _, p in ipairs(Scan.scan_dir(tostring(Path.new(Utils.get_plugin_root(), "templates")), {only_dirs = true, depth = 1})) do
        templates[Utils.get_filename(p)] = Path.new(p)
    end

    return templates
end

function Automaton.load_recents()
    local recentspath = Path:new(tostring(Automaton.storage), "recents.json")
    local recents = { }

    if recentspath:is_file() then
        recents = vim.tbl_filter(function(proj) -- Filter deleted projects
            return Path:new(proj.root, Automaton.config.impl.workspace):is_dir()
        end, Utils.read_json(recentspath))
    end

    return recents, recentspath
end

function Automaton.get_buffers_for_ws(ws)
    local buffers = { }

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local filepath = vim.api.nvim_buf_get_name(buf)

            if Utils.starts_with(filepath, ws.rootpath) then
                table.insert(buffers, filepath)
            end
        end
    end

    return buffers
end

function Automaton.save_workspaces()
    local recents, recentspath = Automaton.load_recents()
    local newrecents = { }

    for _, recent in ipairs(recents) do
        for _, ws in ipairs(Automaton.workspaces) do
            if recent.root == ws.rootpath then
                recent.files = Automaton.get_buffers_for_ws(ws)
                break
            end
        end

        table.insert(newrecents, recent)
    end

    Utils.write_json(recentspath, newrecents)
end

function Automaton.update_recents(ws)
    local recents, recentspath = Automaton.load_recents()
    local p, idx  = ws.rootpath, -1

    for i, proj in ipairs(recents) do
        if proj.root == p then
            idx = i
            break
        end
    end

    if idx ~= -1 then
        table.remove(recents, idx)
    end

    table.insert(recents, {
        root = ws.rootpath,
        files = Automaton.get_buffers_for_ws(ws)
    });

    Utils.write_json(recentspath, recents)
end

function Automaton.recent_workspaces()
    local recents = Automaton.load_recents()

    vim.ui.select(recents, {
        prompt = "Workspaces",
        format_item = function(item)
            return Utils.get_filename(item.root) .. " - " .. item.root
        end
    }, function(item)
        if item ~= nil then
            Automaton.load_workspace(item.root, item.files)
        end
    end)
end

function Automaton._select_folder(wsname, template)
    if not wsname or not template then
        return
    end

    local Picker = require("automaton.picker")

    Picker.select_folder(function(p)
        Automaton.init_workspace(Path.new(tostring(p), wsname), template)
    end)
end

function Automaton.create_workspace()
    vim.ui.input("Workspace name", function(wsname)
        if wsname and string.len(wsname) then
            local templates = Automaton.get_templates()

            vim.ui.select(vim.tbl_keys(templates), {
                prompt = "Select Template"
            }, function(t)
                Automaton._select_folder(wsname, t)
            end)
        end
    end)
end

function Automaton.init_workspace(filepath, template)
    filepath = vim.F.if_nil(filepath, Path:new(vim.fn.expand("%:p")):parent())
    template = vim.F.if_nil(template, "base")

    local wspath = Path:new(filepath, Automaton.config.impl.workspace)
    assert(not wspath:is_file())

    if not wspath:exists() then
        local templates = Automaton.get_templates()
        wspath:mkdir({parents = true})

        templates[template]:copy({
            recursive = true,
            override = true,
            destination = wspath,
        })

        Automaton.load_workspace(wspath:parent())
    end
end

function Automaton.check_workspace(filepath)
    for _, p in ipairs(filepath:parents()) do
        if Automaton.load_workspace(p) then
            break
        end
    end
end

function Automaton.get_current_workspace()
    local filepath = Path:new(vim.fn.expand("%:p"))

    for _, p in ipairs(filepath:parents()) do
        local ws = Automaton.workspaces[p]

        if ws then
            return ws
        end
    end

    return nil
end

function Automaton.load_workspace(searchpath, files)
    files = vim.F.if_nil(files, { })

    local wsloc = Path:new(searchpath, Automaton.config.impl.workspace)

    if wsloc:is_dir() then
        local wspath = wsloc:parent()
        local ws = Automaton.workspaces[tostring(wspath)]

        if ws then
            Log.debug("Switched active workspace")
        else
            Log.debug("Workspace found in " .. tostring(wspath))
            ws = Workspace(Automaton.config, wspath)
            Automaton.workspaces[tostring(wspath)] = ws

            -- Reload files for this workspace
            for _, filepath in ipairs(files) do
                if Path.new(filepath):is_file() then
                    vim.api.nvim_command(":e " .. filepath)
                end
            end
        end

        ws:set_active()
        Automaton.update_recents(ws)
        Automaton.active = ws

        if vim.is_callable(Automaton.config.events.workspacechanged) then
            Automaton.config.events.workspacechanged(ws)
        end

        return true
    end

    if vim.is_callable(Automaton.config.events.workspacechanged) then
        Automaton.config.events.workspacechanged(nil)
    end

    return false
end

function Automaton.setup(config)
    Automaton.config = vim.tbl_deep_extend("force", DefaultConfig, config or { })
    Automaton.config.impl = DefaultConfig.impl -- Always override 'impl' key

    Automaton.storage:mkdir({
        exists_ok = true,
        parents = true
    })

    if type(Automaton.config.debug) == "string" then
        Log.level = Automaton.config.debug
    else
        Log.level = Automaton.config.debug and "trace" or "info"
    end

    local groupid = vim.api.nvim_create_augroup("Automaton", {clear = true})

    vim.api.nvim_create_autocmd("BufEnter", {
        group = groupid,
        nested = true,
        callback = function(arg)
            if #arg.file > 0 then
                Automaton.check_workspace(Path:new(arg.file))
            end
        end
    })

    vim.api.nvim_create_autocmd("VimLeave", {
        group = groupid,
        callback = function()
            Automaton.save_workspaces()
        end
    })

    vim.api.nvim_create_user_command("AutomatonRecentWorkspaces", Automaton.recent_workspaces, { })
    vim.api.nvim_create_user_command("AutomatonCreateWorkspace", Automaton.create_workspace, { })
    vim.api.nvim_create_user_command("AutomatonInitWorkspace", Automaton.init_workspace, { })
    vim.api.nvim_create_user_command("AutomatonLoadWorkspace", Automaton.load_workspace, { })

    vim.api.nvim_create_user_command("AutomatonOpenLaunch", function()
        local ws = Automaton.get_current_workspace()
        if ws then ws:open_launch() end
    end, { })

    vim.api.nvim_create_user_command("AutomatonOpenTasks", function()
        local ws = Automaton.get_current_workspace()
        if ws then ws:open_tasks() end
    end, { })

    vim.api.nvim_create_user_command("AutomatonOpenVariables", function()
        local ws = Automaton.get_current_workspace()
        if ws then ws:open_variables() end
    end, { })

    vim.api.nvim_create_user_command("AutomatonLaunch", function()
        local ws = Automaton.get_current_workspace()

        if ws then
            Automaton.check_save()
            ws:show_launch(false)
        end
    end, { })

    vim.api.nvim_create_user_command("AutomatonDebug", function()
        local ws = Automaton.get_current_workspace()

        if ws then
            Automaton.check_save()
            ws:show_launch(true)
        end
    end, { })

    vim.api.nvim_create_user_command("AutomatonTasks", function()
        local ws = Automaton.get_current_workspace()

        if ws then
            Automaton.check_save()
            ws:show_tasks()
        end
    end, { })

    vim.api.nvim_create_user_command("AutomatonLaunchDefault", function()
        local ws = Automaton.get_current_workspace()

        if ws then
            Automaton.check_save()
            ws:launch_default(false)
        end
    end, { })

    vim.api.nvim_create_user_command("AutomatonDebugDefault", function()
        local ws = Automaton.get_current_workspace()

        if ws then
            Automaton.check_save()
            ws:launch_default(true)
        end
    end, { })

    vim.api.nvim_create_user_command("AutomatonTasksDefault", function()
        local ws = Automaton.get_current_workspace()

        if ws then
            Automaton.check_save()
            ws:tasks_default()
        end
    end, { })
end

return Automaton
