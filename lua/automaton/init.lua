local Utils = require("automaton.utils")
local DefaultConfig = require("automaton.config")
local Workspace = require("automaton.workspace")
local Dialogs = require("automaton.dialogs")

local Automaton = {
    storage = vim.fs.joinpath(vim.fn.stdpath("data"), "automaton"),
    workspaces = {},
    config = nil,
    active = nil,
}

function Automaton.get_active_workspace()
    return Automaton.active
end

function Automaton.check_save()
    if Automaton.config.save_all then
        vim.api.nvim_command("silent! :wall")
    end
end

function Automaton.get_templates()
    local templates = {}

    for _, p in ipairs(Utils.read_dir(vim.fs.joinpath(Utils.get_plugin_root(), "templates"), { only_dirs = true })) do
        templates[vim.fs.basename(p)] = p
    end

    return templates
end

function Automaton.load_recents()
    local recentspath = vim.fs.joinpath(Automaton.storage, Automaton.config.impl.recentsfile)
    local recents = {}

    if vim.fn.filereadable(recentspath) == 1 then
        local recentsdata = Utils.read_json(recentspath)

        if type(recentsdata) == "table" and recentsdata.version == Automaton.config.impl.VERSION then
            recents = vim.tbl_filter(function(proj) -- Filter deleted projects
                local p = vim.fs.joinpath(proj.root, Automaton.config.impl.workspace)
                return vim.fn.isdirectory(p) == 1
            end, recentsdata.recents or {})
        end
    end

    return recents, recentspath
end

function Automaton.has_open_buffers()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            return true
        end
    end

    return false
end

function Automaton.get_buffers_for_ws(ws, options)
    options = options or {}

    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local filetype = vim.api.nvim_buf_get_option(buf, "filetype")

            if not vim.tbl_contains(Automaton.config.ignore_ft, filetype) then
                local filepath = vim.api.nvim_buf_get_name(buf)

                if vim.startswith(filepath, ws.rootpath) and vim.fn.filereadable(filepath) == 1 then
                    if options.byid == true then
                        table.insert(buffers, buf)
                    elseif options.relative == true then
                        table.insert(buffers, vim.fs.relpath(ws.rootpath, filepath))
                    else
                        table.insert(buffers, filepath)
                    end
                end
            end
        end
    end

    return buffers
end

function Automaton.save_workspaces()
    local recents, recentspath = Automaton.load_recents()
    local newrecents = {}

    for _, recent in ipairs(recents) do
        for _, ws in pairs(Automaton.workspaces) do
            if recent.root == ws.rootpath then
                recent.files = Automaton.get_buffers_for_ws(ws, { relative = true })
                break
            end
        end

        table.insert(newrecents, recent)
    end

    Utils.write_json(recentspath, {
        version = Automaton.config.impl.VERSION,
        recents = newrecents
    }, 2)
end

function Automaton.update_recents(ws)
    local recents, recentspath = Automaton.load_recents()
    local p, idx               = ws.rootpath, -1

    for i, proj in ipairs(recents) do
        if proj.root == p then
            idx = i
            break
        end
    end

    if idx ~= -1 then
        table.remove(recents, idx)
    end

    table.insert(recents, 1, {
        root = ws.rootpath,
        files = Automaton.get_buffers_for_ws(ws, { relative = true })
    });

    Utils.write_json(recentspath, {
        version = Automaton.config.impl.VERSION,
        recents = recents
    })
end

function Automaton.close_workspace(ws)
    local buffers = Automaton.get_buffers_for_ws(ws, { byid = true })
    Automaton.check_save()

    for _, buf in ipairs(buffers) do
        vim.api.nvim_command(":bd! " .. buf)
    end

    Automaton.workspaces[ws.rootpath] = nil
end

function Automaton._edit_workspace(ws)
    local items = vim.tbl_map(function(filepath)
        return {
            icon = "buffer",
            value = filepath,
        }
    end, Automaton.get_buffers_for_ws(ws, { relative = true }))

    table.insert(items, { icon = "close", value = "CLOSE" })
    table.insert(items, { icon = nil, value = ".." })

    Dialogs.select(items, {
        prompt_title = "Workspace '" .. ws:get_name() .. "'",

        entry_maker = function(e)
            local entry = {
                display = e.value,
                ordinal = e.value,
            }

            if e.icon then
                entry.display = Automaton.config.icons[e.icon] .. " " .. entry.display
            end

            return entry
        end
    }, function(e)
        if e.ordinal == ".." then
            Automaton.show_workspaces()
        elseif e.ordinal == "CLOSE" then
            Automaton.close_workspace(ws)
        else
            vim.api.nvim_command(":e " .. vim.fs.joinpath(ws.rootpath, e.ordinal))
        end
    end)
end

function Automaton.show_workspaces()
    local workspaces = vim.tbl_map(function(n)
        local ws = Automaton.workspaces[n]
        return {
            ws = ws,
            files = Automaton.get_buffers_for_ws(ws)
        }
    end, vim.tbl_keys(Automaton.workspaces))

    Dialogs.table(workspaces, {
        prompt_title = "Workspaces",

        columns = {
            { width = 40 },
            { remaining = true }
        },

        entry_maker = function(e)
            return {
                ordinal = e.ws:get_name(),
                value = e,
            }
        end,

        displayer = function(e)
            return {
                { e.value.ws:get_name(),                         "TelescopeResultsIdentifier" },
                { string.format("%d buffer(s)", #e.value.files), "TelescopeResultsNumber" },
            }
        end
    }, function(e)
        Automaton._edit_workspace(e.value.ws)
    end)
end

function Automaton.recent_workspaces()
    local recents = Automaton.load_recents()

    local gettext = function(e)
        return vim.fs.basename(e.root) .. " - " .. e.root
    end

    Dialogs.table(recents, {
        prompt_title = "Workspaces",

        columns = {
            { width = 1 },
            { width = 20 },
            { remaining = true }
        },

        entry_maker = function(e)
            return {
                ordinal = gettext(e),
                value = e,
            }
        end,

        displayer = function(e)
            return {
                Automaton.config.icons.workspace,
                { vim.fs.basename(e.value.root), "TelescopeResultsNumber" },
                { e.value.root,                  "TelescopeResultsIdentifier" },
            }
        end
    }, function(e)
        Automaton.load_workspace(e.value.root, e.value.files)
    end)
end

function Automaton.create_workspace()
    vim.ui.input({ prompt = "Workspace name " }, function(wsname)
        if wsname and string.len(wsname) then
            require("automaton.picker").select_folder(function(p)
                Automaton.init_workspace(vim.fs.joinpath(p, wsname))
            end)
        end
    end)
end

function Automaton.init_workspace(filepath)
    filepath = vim.F.if_nil(filepath, Utils.get_parent(vim.fn.expand("%:p")))
    local wspath = vim.fs.joinpath(filepath, Automaton.config.impl.workspace)

    if vim.fn.isdirectory(wspath) == 0 then
        local templates = Automaton.get_templates()

        vim.ui.select(vim.tbl_keys(templates), {
            prompt = "Select Template"
        }, function(t)
            if t then
                Utils.copy_to(templates[t], wspath)
                Automaton.load_workspace(Utils.get_parent(wspath))
            end
        end)
    else
        vim.notify("Workspace already initialized")
    end
end

function Automaton.check_workspace(filepath)
    if vim.fn.isdirectory(filepath) == 0 then
        return
    end

    for _, p in vim.fs.parents(filepath) do
        if Automaton.load_workspace(p) then
            break
        end
    end
end

function Automaton.load_workspace(searchpath, files)
    files = vim.F.if_nil(files, {})

    local wsloc = vim.fs.joinpath(searchpath, Automaton.config.impl.workspace)
    local changed = false

    if vim.fn.isdirectory(wsloc) == 1 then
        local wspath = Utils.get_parent(wsloc)
        local ws = Automaton.workspaces[wspath]

        if ws then
            vim.notify("Switched active workspace", vim.log.levels.DEBUG)
            ws:set_active()
        else
            vim.notify("Workspace found in " .. wspath, vim.log.levels.DEBUG)
            ws = Workspace(Automaton.config, wspath)
            Automaton.workspaces[wspath] = ws
            ws:set_active()

            if vim.tbl_isempty(files) and not Automaton.has_open_buffers() then
                vim.api.nvim_command(":enew")
            else -- Reload files for this workspace
                for _, relpath in ipairs(files) do
                    local filepath = vim.fs.joinpath(ws.rootpath, relpath)
                    if vim.fn.filereadable(filepath) == 1 then
                        vim.api.nvim_command(":e " .. filepath)
                    end
                end
            end
        end

        Automaton.update_recents(ws)
        changed = Automaton.active ~= ws
        Automaton.active = ws
    else
        changed = Automaton.active ~= nil
        Automaton.active = nil
    end

    if changed and vim.is_callable(Automaton.config.events.workspacechanged) then
        Automaton.config.events.workspacechanged(Automaton.active)
    end

    return Automaton.active ~= nil
end

function Automaton._get_workspace_files()
    return vim.tbl_filter(function(x)
        return vim.endswith(x, ".json")
    end, vim.tbl_values(Automaton.config.impl))
end

function Automaton._on_workspace_file_opened(arg)
    local stem = Utils.get_stem(arg.file)
    vim.api.nvim_buf_set_option(arg.buf, "filetype", "automaton" .. stem)
    vim.api.nvim_buf_set_option(arg.buf, "syntax", "jsonc")

    if Automaton.config.integrations.cmp == true then
        local ok, cmp = pcall(require, "cmp")

        if ok then
            local sources = {
                { name = "automatonschema" },
                { name = "automatonvariable" }
            }

            if Automaton.config.integrations.luasnip == true then
                table.insert(sources, { name = "luasnip" })
            end

            cmp.setup.buffer({ sources = sources })
        end
    end
end

function Automaton.setup(config)
    Automaton.config = vim.tbl_deep_extend("force", DefaultConfig, config or {})
    Automaton.config.impl = DefaultConfig.impl -- Always override 'impl' key
    vim.fn.mkdir(Automaton.storage, "p")

    for integ, enable in pairs(Automaton.config.integrations) do
        if enable == true then
            require("automaton.integrations." .. integ).integrate(Automaton)
        end
    end

    local groupid = vim.api.nvim_create_augroup("Automaton", { clear = true })

    vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
        group = groupid,
        pattern = vim.tbl_map(function(x)
            return vim.fs.joinpath("*", Automaton.config.impl.workspace, x)
        end, Automaton._get_workspace_files()),
        callback = Automaton._on_workspace_file_opened
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = groupid,
        callback = function(arg)
            if #arg.file > 0 then
                Automaton.check_workspace(arg.file)
            end
        end
    })

    vim.api.nvim_create_autocmd("VimLeave", {
        group = groupid,
        callback = function()
            Automaton.save_workspaces()
        end
    })

    vim.api.nvim_create_user_command("Automaton", function(opts)
        local action, arg = opts.fargs[1], opts.fargs[2]
        if action == nil then error("Action required") end

        local check_arg = function()
            if arg == nil then
                error("Invalid argument")
            end
        end

        if action == "create" then
            Automaton.create_workspace()
        elseif action == "recents" then
            Automaton.recent_workspaces()
        elseif action == "workspaces" then
            Automaton.show_workspaces()
        elseif action == "init" then
            Automaton.init_workspace()
        elseif action == "load" then
            Automaton.load_workspace()
        elseif action == "jobs" then
            require("automaton.runner").show_jobs(Automaton.config)
        elseif action == "config" then
            local ws = Automaton.get_active_workspace()
            if ws then ws:edit_config() end
        elseif action == "launch" or action == "debug" then
            local ws = Automaton.get_active_workspace()
            if not ws then return end
            Automaton.check_save()

            if arg == "default" then
                ws:launch_default(action == "debug")
            else
                ws:show_launch(action == "debug")
            end
        elseif action == "tasks" then
            local ws = Automaton.get_active_workspace()
            if not ws then return end
            Automaton.check_save()

            if arg == "default" then
                ws:tasks_default()
            else
                ws:show_tasks()
            end
        elseif action == "open" then
            check_arg()
            local ws = Automaton.get_active_workspace()
            if not ws then return end

            if arg == "launch" then
                ws:open_launch()
            elseif arg == "tasks" then
                ws:open_tasks()
            elseif arg == "variables" then
                ws:open_variables()
            elseif arg == "config" then
                ws:open_config()
            end
        else
            error("Unknown action '" .. action .. "'")
        end
    end, {
        nargs = "+",
        desc = "Automaton",
        complete = function(_, line)
            local ws = Automaton.get_active_workspace()
            local args = Utils.cmdline_split(line)
            table.remove(args, 1) -- Remove 'Automaton'

            local COMMANDS = { "create", "recents", "workspaces", "init", "load" }

            if ws then
                COMMANDS = vim.list_extend(COMMANDS, { "jobs", "config", "debug", "launch", "tasks", "open" })
            end

            if vim.tbl_isempty(args) then
                return COMMANDS
            end

            local last = args[#args]

            if ws then
                if last == "open" then
                    return { "launch", "tasks", "variables", "config" }
                elseif last == "tasks" or last == "debug" or last == "launch" then
                    return { "default" }
                end
            end

            return {}
        end
    })
end

return Automaton
