local Select = require("automaton.dialogs.select")
local Table = require("automaton.dialogs.table")

local M = { }

function M.update_state(ws, selconfig, config, state)
    if vim.tbl_islist(selconfig.choices) then
        local choices = vim.deepcopy(selconfig.choices)
        table.insert(choices, "..")

        Select(choices, {
            prompt_title = vim.F.if_nil(selconfig.label, selconfig.name),

            entry_maker = function(e)
                local entry = { display = e, ordinal = e,  }

                if e == state[selconfig.name] then
                    entry.display = entry.display .. " [SELECTED]"
                end

                return entry
            end

        }, function(e)
            if e.display ~= ".." then
                state[selconfig.name] = e.display
                ws:update_state(state)
            end

            M.show_config(ws, config, state)
        end)
    else
    end
end

function M.show_config(ws, config, state)
    if not config then return end
    if not state then return end

    Table(config, {
        prompt_title = "Configuration",

        columns = {
            {width = 40},
            {remaining = true}
        },

        entry_maker = function(e)
            return {
                ordinal = vim.F.if_nil(e.label, e.name),
                state = vim.F.if_nil(state[e.name], e.default or ""),
                value = e
            }
        end,

        displayer = function(e)
            return {
                {e.ordinal, "TelescopeResultsIdentifier"},
                {e.state, "TelescopeResultsNumber"},
            }
        end
    }, function(e)
        M.update_state(ws, e.value, config, state)
    end)
end

local function show_config(ws, config, state)
    vim.validate({
        config = {config, "table"},
        state = {state, "table"},
    })

    if not vim.tbl_islist(config) then error("Config must be a list") end
    if vim.tbl_islist(state) then error("State must be an object") end

    if not vim.tbl_isempty(config) then
        M.show_config(ws, config, state)
    end
end

return show_config
