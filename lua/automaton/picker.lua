local Utils = require("automaton.utils")

local function select_item(path, onchoice, options, level)
    level = level or 0

    local function is_root(p)
        if options.limitroot and level == 0 then
            return true
        end

        return Utils.is_root_path(p)
    end

    local items = Utils.read_dir(path, options)

    if not is_root(path) then
        table.insert(items, 1, "..")
    end

    if options.only_dirs then
        table.insert(items, 1, "<SELECT FOLDER>")
    end

    vim.ui.select(items, {
            prompt = vim.fs.basename(path),
            format_item = function(p)
                return (vim.fn.isdirectory(p) == 1 and " " or " ") .. vim.fs.basename(p)
            end
        },
        function(choice)
            if choice then
                if choice == "<SELECT FOLDER>" then
                    onchoice(path)
                elseif choice == ".." then
                    if not is_root(choice) then
                        select_item(Utils.get_parent(path), onchoice, options, level - 1)
                    end
                elseif vim.fn.isdirectory(choice) == 1 then
                    select_item(choice, onchoice, options, level + 1)
                elseif not options.only_dirs and vim.fn.filereadable(choice) == 1 then
                    onchoice(choice)
                end
            end
        end)
end

local PickerDialog = {}

function PickerDialog.select_folder(onchoice, options)
    options = options or {}
    select_item(options.cwd or vim.uv.os_homedir(), onchoice,
        vim.tbl_extend("force", options, { only_dirs = true }))
end

function PickerDialog.select_file(onchoice, options)
    options = options or {}
    select_item(options.cwd or vim.uv.os_homedir(), onchoice,
        vim.tbl_extend("force", options, { add_dirs = true }))
end

return PickerDialog
