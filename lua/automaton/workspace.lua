local Previewers = require("telescope.previewers")
local Path = require("plenary.path")
local Runner = require("automaton.runner")
local Utils = require("automaton.utils")
local JSON5 = require("automaton.json5")
local Dialogs = require("automaton.dialogs")
local Schema = require("automaton.schema")
local Variable = require("automaton.variable")

local function show_entries(config, ws, entries, options, cb)
    Dialogs.table(entries, {
        prompt_title = options.title,

        columns = {
            {width = 1},
            {width = 50},
            {remaining = true},
        },

        entry_maker = function(e)
            return {
                ordinal = e.name,
                value = e,
            }
        end,

        displayer = function(e)
            return {
                config.icons[options.icon],
                {e.value.name, "TelescopeResultsIdentifier"},
                {e.value.default == true and "DEFAULT" or "", "TelescopeResultsNumber"},
            }
        end,

        previewer = Previewers.new_buffer_previewer({
            dyn_title = function(_, e) return e.name end,
            define_preview = function(self, e)
                local resobj = Variable.resolve(e.value, ws:get_current_variables())
                local preview = Utils.split_lines(JSON5.stringify(resobj, 2))
                vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "json")
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview)
            end
        }),
    }, function(e)
        cb(e.value)
    end)
end

return function(config, rootpath)
    local Workspace = {
        rootpath = tostring(rootpath),
        runningjobs = { },

        STARTING = 1,
        LOCK = 2,
        STOP = nil,
    }

    function Workspace:ws_root() return tostring(Path:new(self.rootpath, config.impl.workspace)) end
    function Workspace:ws_open(filename) vim.api.nvim_command(":e " .. tostring(Path:new(self:ws_root(), filename))) end
    function Workspace:open_launch() self:ws_open(config.impl.launchfile) end
    function Workspace:open_tasks() self:ws_open(config.impl.tasksfile) end
    function Workspace:open_variables() self:ws_open(config.impl.variablesfile) end
    function Workspace:open_config() self:ws_open(config.impl.configfile) end
    function Workspace:edit_config() Dialogs.edit_config(self) end
    function Workspace:get_config() return self:_load_json(config.impl.configfile) end
    function Workspace:get_state() return self:sync_state(self:_load_json(config.impl.statefile, vim.empty_dict())) end
    function Workspace:get_variables() return self:_load_json(config.impl.variablesfile, vim.empty_dict()) end
    function Workspace:get_name() return Utils.get_filename(self.rootpath) end
    function Workspace:is_active() return self.rootpath == vim.fn.getcwd() end
    function Workspace:set_active() vim.api.nvim_set_current_dir(self.rootpath) end

    -- https://code.visualstudio.com/docs/editor/variables-reference
    function Workspace:get_current_variables(vars)
        local filepath = vim.api.nvim_buf_get_name(0)

        local variables = {
            VERSION = config.impl.VERSION,
            env = vim.env,
            sep = Utils.dirsep,
            file = filepath,
            file_name = Utils.get_filename(filepath),
            file_stem = Utils.get_stem(filepath),
            selected_text = Utils.get_visual_selection(),
            os_name = vim.loop.os_uname().sysname:lower(),
            os_open = Utils.osopen_command(),
            number_of_cores = Utils.get_number_of_cores(),
            user_home = vim.loop.os_homedir(),
            workspace_folder = self.rootpath,
            workspace_name = self:get_name(),
            cwd = vim.fn.getcwd(),
            state = self:get_state(),
            globals = Variable.get_globals()
        }

        if vars ~= false then
            variables.ws = Variable.resolve(self:get_variables(), variables)
        end

        return variables
    end

    function Workspace:_load_json(filename, fallback, schema)
        fallback = fallback or { }
        local filepath = Path:new(self:ws_root(), filename)

        if filepath:is_file() then
            if schema == true then
                return Schema.load_file(filepath, fallback)
            else
                return Utils.read_json(filepath)
            end
        end

        return fallback
    end

    function Workspace:sync_state(state)
        local updated, wsconfig = false, self:get_config()

        if type(wsconfig) == "table" and vim.tbl_islist(wsconfig) then
            for _, c in ipairs(wsconfig) do
                if state[c.name] == nil and c.default then
                    state[c.name] = c.default
                    updated = true
                end
            end
        end

        if updated then
            self:update_state(state)
        end

        return state
    end

    function Workspace:update_state(state)
        local statepath = Path:new(self:ws_root(), config.impl.statefile)
        local header = "/* Autogenerated by Automaton. Do not edit */\n"
        Utils.write_file(statepath, header .. JSON5.stringify(state, 2))
    end

    function Workspace:get_tasks()
        local wstasks = self:_load_json(config.impl.tasksfile, { }, true)
        if wstasks then return Variable.resolve(wstasks.tasks or { }, self:get_current_variables()) end
        return { }
    end

    function Workspace:get_tasks_by_name(intasks)
        local tasks, byname = vim.F.if_nil(intasks, self:get_tasks()), {}

        for _, t in ipairs(tasks) do
            if t.name then
                if byname[t.name] then
                    error("Duplicate task '" .. t.name .. "'")
                else
                    byname[t.name] = t
                end
            end
        end

        return byname
    end

    function Workspace:get_launch()
        local wslaunch = self:_load_json(config.impl.launchfile, { }, true)
        if type(wslaunch) == "table" then return Variable.resolve(wslaunch.configurations or { }, self:get_current_variables()) end
        return { }
    end

    function Workspace:get_default_task()
        local tasks = self:get_tasks()

        if type(tasks) == "table" and vim.tbl_islist(tasks) then
            for _, t in ipairs(tasks) do
                if t.default == true then
                    return t
                end
            end
        end

        return nil
    end

    function Workspace:get_default_launch()
        local configs = self:get_launch()

        if type(configs) == "table" and vim.tbl_islist(configs) then
            for _, l in ipairs(configs) do
                if l.default == true then
                    return l
                end
            end
        end

        return nil
    end

    function Workspace:launch_default(debug)
        local launch = self:get_default_launch()
        if launch then self:launch(launch, debug)
        else vim.notify("Default launch configuration not found")
        end
    end

    function Workspace:tasks_default()
        local task = self:get_default_task()
        if task then self:run(task)
        else vim.notify("Default task not found")
        end
    end

    function Workspace:show_launch(debug)
        local configs = self:get_launch()

        show_entries(config, self, configs, {
            title = "Launch",
            icon = "launch",
        }, function(e) self:launch(e, debug) end)
    end

    function Workspace:show_tasks()
        local tasks = self:get_tasks()

        show_entries(config, self, tasks, {
            title = "Tasks",
            icon = "task",
        }, function(e) self:run(e, tasks) end)
    end

    function Workspace:get_depends(e, byname, depends)
        depends = depends or { }

        if vim.tbl_islist(e.depends) then
            for _, dep in ipairs(e.depends) do
                if byname[dep] then
                    Utils.list_reinsert(depends, byname[dep], function(a, b) return a.name == b.name end)
                    self:get_depends(byname[dep], byname, depends)
                else
                    error("Task '" .. dep .. "' not found")
                end
            end
        end

        return depends
    end

    function Workspace:run_depends(depends, cb, i)
        i = i or 1

        if i > #depends then
            if vim.is_callable(cb) then cb(true) end
            return
        end

        if self.runningjobs[depends[i].name] == self.LOCK then
            return
        end

        self.runningjobs[depends[i].name] = self.LOCK

        Runner.run(config, self, depends[i], function(code)
            if code == 0 then
                self:run_depends(depends, cb, i + 1)
            elseif vim.is_callable(cb) then
                cb(false)
            end

            self.runningjobs[depends[i].name] = self.STOP
        end)
    end

    function Workspace:run(e, tasks)
        if self.runningjobs[e.name] then
            return
        end

        if e.detach ~= true then -- Don't monitor detached tasks
            self.runningjobs[e.name] = self.STARTING
        end

        Runner.clear_quickfix(e)

        local byname = self:get_tasks_by_name(tasks)
        local depends = self:get_depends(e, byname)

        self:run_depends(depends, function(ok)
            if ok then
                Runner.run(config, self, e, function()
                    self.runningjobs[e.name] = self.STOP
                end)
            else
                self.runningjobs[e.name] = self.STOP
            end
        end)
    end

    function Workspace:launch(e, debug)
        if self.runningjobs[e.name] then
            return
        end

        if not debug then -- Don't monitor DAP
            self.runningjobs[e.name] = self.STARTING
        end

        Runner.close_terminal()
        Runner.clear_quickfix(e)

        local byname = self:get_tasks_by_name()
        local depends = self:get_depends(e, byname)

        self:run_depends(depends, function(ok)
            if ok then
                Runner.launch(config, self, e, debug, function()
                    self.runningjobs[e.name] = self.STOP
                end)
            else
                self.runningjobs[e.name] = self.STOP
            end
        end)
    end

    return Workspace
end
