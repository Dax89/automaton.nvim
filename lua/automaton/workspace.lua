local Pickers = require("telescope.pickers")
local Finders = require("telescope.finders")
local Previewers = require("telescope.previewers")
local Config = require("telescope.config").values
local Actions = require("telescope.actions")
local ActionState = require("telescope.actions.state")
local Path = require("plenary.path")
local Runner = require("automaton.runner")
local Utils = require("automaton.utils")
local JSON5 = require("automaton.json5")

-- https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
local function show_entries(entries, cb)
    Pickers.new({ }, {
        prompt_title = "Tasks",
        sorter = Config.generic_sorter({ }),

        finder = Finders.new_table({
            results = entries,
            entry_maker = function(e)
                local r = {
                    value = e,
                    display = e.name,
                    ordinal = e.name,
                }

                if e.default == true then
                    r.display = r.display .. " [DEFAULT]"
                end

                return r
            end
        }),

        previewer = Previewers.new_buffer_previewer({
            dyn_title = function(_, e) return e.name end,
            define_preview = function(self, e)
                vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "json")
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, Utils.split_lines(JSON5.stringify(e.value, 2)))
            end
        }),

        attach_mappings = function(promptbufnr)
            Actions.select_default:replace(function()
                Actions.close(promptbufnr)
                cb(ActionState.get_selected_entry().value)
            end)
            return true
        end
    }):find()
end

return function(config, rootpath)
    local Workspace = {
        rootpath = tostring(rootpath),
    }

    function Workspace:ws_root()
        return tostring(Path:new(self.rootpath, config.impl.workspace))
    end

    function Workspace:get_variables()
        local filepath = Path:new(self:ws_root(), config.impl.variablesfile)

        if filepath:is_file() then
            return self:read_resolved(filepath, self:builtin_variables()) or { }
        end

        return { }
    end

    function Workspace:open_launch()
        vim.api.nvim_command(":e " .. tostring(Path:new(self:ws_root(), config.impl.launchfile)))
    end

    function Workspace:open_tasks()
        vim.api.nvim_command(":e " .. tostring(Path:new(self:ws_root(), config.impl.tasksfile)))
    end

    function Workspace:open_variables()
        vim.api.nvim_command(":e " .. tostring(Path:new(self:ws_root(), config.impl.variablesfile)))
    end

    function Workspace:get_default_task()
        local wstasks = self:read_resolved(Path:new(self:ws_root(), config.impl.tasksfile))

        if wstasks then
            for _, t in ipairs(wstasks.tasks or { }) do
                if t.default == true then
                    return t
                end
            end
        end

        return nil
    end

    function Workspace:get_default_launch()
        local wslaunch = self:read_resolved(Path:new(self:ws_root(), config.impl.launchfile))

        if wslaunch then
            for _, l in ipairs(wslaunch.configurations or { }) do
                if l.default == true then
                    return l
                end
            end
        end

        return nil
    end

    function Workspace:launch_default(debug)
        local launch = self:get_default_launch()

        if launch then
            Runner.launch(launch, debug)
        else
            error("Default launch configuration not found")
        end
    end

    function Workspace:tasks_default()
        local task = self:get_default_task()

        if task then
            Runner.run(task)
        else
            error("Default task not found")
        end
    end

    function Workspace:show_launch(debug)
        local wslaunch = self:read_resolved(Path:new(self:ws_root(), config.impl.launchfile))

        if wslaunch then
            show_entries(wslaunch.configurations or { }, function(e) Runner.launch(e, debug) end)
        end
    end

    function Workspace:show_tasks()
        local wstasks = self:read_resolved(Path:new(self:ws_root(), config.impl.tasksfile))

        if wstasks then
            show_entries(wstasks.tasks or { }, function(e) Runner.run(e) end)
        end
    end

    function Workspace:read_resolved(filepath, variables)
        if not filepath:is_file() then
            return nil
        end

        local c = Utils.read_file(filepath)

        if type(variables) == "table" then
            return self:_resolve_variables(c, variables)
        end

        return self:resolve_variables(c)
    end

    function Workspace:builtin_variables()
        return {
            env = vim.env,
            os_name = vim.loop.os_uname().sysname:lower(),
            os_open = Utils.osopen_command(),
            number_of_cores = Utils.get_number_of_cores(),
            user_home = vim.loop.os_homedir(),
            workspace_folder = self.rootpath,
            workspace_name = self:get_name(),
            cwd = vim.fn.getcwd(),
        }
    end

    -- https://code.visualstudio.com/docs/editor/variables-reference
    function Workspace:resolve_variables(s)
        local variables = vim.tbl_extend("force", {ws = self:get_variables()}, self:builtin_variables())
        return self:_resolve_variables(s, variables)
    end

    function Workspace:_resolve_variables(s, variables)
        -- NOTE: If 'repl' is a table, then the table is queried for every match, 
        --       using the first capture as the key; if the pattern specifies no captures, 
        --       then the whole match is used as the key. 
        -- FROM: https://www.ibm.com/docs/en/ias?topic=manipulation-stringgsub-s-pattern-repl-n
        for k, v in pairs(variables) do
            local p = type(v) == "table" and "%${" .. k .. ":([_%w]+)}" or "%${" .. k .. "}"
            s = s:gsub(p, v)
        end

        return JSON5.parse(s)
    end

    function Workspace:get_name()
        return Utils.get_filename(self.rootpath)
    end

    function Workspace:is_active()
        return self.rootpath == vim.fn.getcwd()
    end

    function Workspace:set_active()
        vim.api.nvim_set_current_dir(self.rootpath)
    end

    return Workspace
end
