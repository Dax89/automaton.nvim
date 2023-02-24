local Select = require("automaton.dialogs.select")
local EntryDisplay = require("telescope.pickers.entry_display")

local function table(items, options, cb)
    options = options or { }

    local displayer = EntryDisplay.create({
        separator = vim.F.if_nil(options.separator, " "),
        items = options.columns
    })

    local make_display = function(entry)
        return displayer(options.displayer(entry))
    end

    Select(items, {
        prompt_title = options.prompt_title,

        entry_maker = function(e)
            local entry = options.entry_maker(e)
            entry.display = make_display
            return entry
        end,

        previewer = options.previewer
    }, cb)
end

return table
