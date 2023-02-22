local Pickers = require("telescope.pickers")
local Finders = require("telescope.finders")
local Config = require("telescope.config").values
local Actions = require("telescope.actions")
local ActionState = require("telescope.actions.state")

-- https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
local function select(entries, options, cb)
    options = options or { }

    Pickers.new({ }, {
        prompt_title = options.prompt_title,
        sorter = vim.F.if_nil(options.sorter, Config.generic_sorter({ })),

        finder = Finders.new_table({
            entry_maker = options.entry_maker,
            results = entries
        }),

        previewer = options.previewer,

        attach_mappings = function(promptbufnr)
            Actions.select_default:replace(function()
                Actions.close(promptbufnr)
                cb(ActionState.get_selected_entry())
            end)
            return true
        end
    }):find()
end

return select
