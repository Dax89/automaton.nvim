```
                                 _                                 _                   
                 /\             | |                               | |                  
                /  \     _   _  | |_    ___    _ __ ___     __ _  | |_    ___    _ __  
               / /\ \   | | | | | __|  / _ \  | '_ ` _ \   / _` | | __|  / _ \  | '_ \ 
              / ____ \  | |_| | | |_  | (_) | | | | | | | | (_| | | |_  | (_) | | | | |
             /_/    \_\  \__,_|  \__|  \___/  |_| |_| |_|  \__,_|  \__|  \___/  |_| |_|
```
<p align="center">
  <img src="https://img.shields.io/github/stars/Dax89/automaton.nvim?style=for-the-badge">
  <img src="https://img.shields.io/github/license/Dax89/automaton.nvim?style=for-the-badge">
  <img src="https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white">
  <a href="https://github.com/Dax89/automaton.nvim/wiki">
    <img src="https://img.shields.io/badge/Wiki-3c73a8?style=for-the-badge">
  </a>
</p>

<p align="center">
  <a href="https://github.com/nvim-telescope/telescope.nvim">Telescope</a> and <a href="https://json5.org">JSON5</a> powered VSCode-like Workspace configuration manager
</p>

<div align="center">
  
  [![asciicast](https://asciinema.org/a/565957.svg)](https://asciinema.org/a/565957)
  
</div>

Automaton is a Workspace configuration manager inspired to VSCode tasks/launch configurations.<br>
Configurations are stored in JSON5 format and they allows to execute tasks, run tests/profilers/linters and even debug your code (if DAP is configured)

## Table of Contents
- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
- [Workspace](#workspace)
- [Keybinds](#keybinds)
- [Contribuitng](#contributing)
- [License](#license)
- [Related Projects](#related-projects)

## Installation

#### Packer
```lua
use {
  "Dax89/automaton.nvim",  
  requires = { 
       {"nvim-lua/plenary.nvim"},
       {"nvim-telescope/telescope.nvim"},
       {"mfussenegger/nvim-dap"}, -- Debug support for 'launch' configurations (Optional)
       {"hrsh7th/nvim-cmp"},      -- Autocompletion for automaton workspace files (Optional)
       {"L3MON4D3/LuaSnip"},      -- Snippet support for automaton workspace files (Optional)
    }
}
```

#### Lazy
```lua
{
  "Dax89/automaton.nvim",  
  dependencies = {
       "nvim-lua/plenary.nvim",
       "nvim-telescope/telescope.nvim",
       "mfussenegger/nvim-dap", -- Debug support for 'launch' configurations (Optional)
       "hrsh7th/nvim-cmp",      -- Autocompletion for automaton workspace files (Optional)
       "L3MON4D3/LuaSnip",      -- Snippet support for automaton workspace files (Optional)
  }
}
```

## Configuration

#### Default Config
```lua
require("automaton").setup({
    debug = false,
    saveall = true,
    ignore_ft = { },

    terminal = {
        position = "botright",
        size = 10,
    },

    integrations = {
        luasnip = false,
        cmp = false,
        cmdcolor = require("automaton.utils").colors.yellow,
    },
    
    icons = {
        buffer = "",
        close = "",
        launch = "",
        task = "",
        workspace = "",
    },
    
    events = {
        workspacechanged = function(ws)
          -- "ws" is the current workspace object (can be nil)
        end
    }
})
```

### Commands

```lua
:Automaton create         -- Create a new workspace
           recents        -- Shows recent workspaces
           init           -- Initializes a workspace in "cwd"
           load           -- Loads a workspace in "cwd"
           workspaces     -- Manage loaded workspaces
           jobs           -- Shows running tasks/launch (can be killed too)
           config         -- Show/Edit workspace settings
           tasks default  -- Exec default task
           tasks          -- Select and exec task
           launch default -- Exec default launch configuration
           launch         -- Select and exec a launch configuration
           debug default  -- Debug default launch configuration
           debug          -- Select and debug a launch configuration
           open launch    -- Open workspace's launch.json
           open tasks     -- Open workspace's tasks.json
           open variables -- Open workspace's variables.json
           open config    -- Open workspace's config.json
```

## Workspace
Workspaces are configured with JSON5 files, the main ones are `tasks.json` and `launch.json`, the latter provides DAP integration too (if [nvim-dap](https://github.com/mfussenegger/nvim-dap) is installed).<br>
If [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) and [LuaSnip](https://github.com/L3MON4D3/LuaSnip) integrations are enabled it's possible to edit configurations with autocompletion and snippets.

Here is an example of `tasks.json` and `launch.json`:
```json5
// tasks.json
{
    version: "1.0.0",
    
    tasks: [
        {
            name: "Init NPM",
            cwd: "${workspace_folder}",
            type: "shell",
            command: "npm init -y",
        },
        {
            name: "Install dependencies",
            cwd: "${workspace_folder}",
            type: "shell",
            command: "npm install .",
        },
        {
            name: "Node Version",
            type: "shell",
            command: "node -v",
        }
    ]
}
```

```json5
// launch.json
{
    version: "1.0.0",
    
    configurations: [
        {
            name: "Execute index",
            cwd: "${workspace_folder}",
            program: "node ${workspace_folder}/index.js",
            default: true, // Set as default launch configuration
            depends: ["Install dependencies"], // Always execute dependency installation

            // DAP Configuration (optional)
            type: "cppdpg", // Equals to 'dap.adapters.[key]' from your DAP config

            // Extra fields are forwarded to dap.run() command
        }
    ]
}
```
## Keybinds
Automaton doesn't provide any keybinds, this is an example of a possible one:
```lua
vim.keymap.set("n", "<F5>", "<CMD>Automaton launch default<CR>")
vim.keymap.set("n", "<F6>", "<CMD>Automaton debug default<CR>")
vim.keymap.set("n", "<F8>", "<CMD>Automaton tasks default<CR>")

vim.keymap.set("n", "<leader>aC", "<CMD>Automaton create<CR>")
vim.keymap.set("n", "<leader>aI", "<CMD>Automaton init<CR>")
vim.keymap.set("n", "<leader>aL", "<CMD>Automaton load<CR>")

vim.keymap.set("n", "<leader>ac", "<CMD>Automaton config<CR>")
vim.keymap.set("n", "<leader>ar", "<CMD>Automaton recents<CR>")
vim.keymap.set("n", "<leader>aw", "<CMD>Automaton workspaces<CR>")
vim.keymap.set("n", "<leader>aj", "<CMD>Automaton jobs<CR>")
vim.keymap.set("n", "<leader>al", "<CMD>Automaton launch<CR>")
vim.keymap.set("n", "<leader>ad", "<CMD>Automaton debug<CR>")
vim.keymap.set("n", "<leader>at", "<CMD>Automaton tasks<CR>")

vim.keymap.set("n", "<leader>aol", "<CMD>Automaton open launch<CR>")
vim.keymap.set("n", "<leader>aov", "<CMD>Automaton open variables<CR>")
vim.keymap.set("n", "<leader>aot", "<CMD>Automaton open tasks<CR>")
vim.keymap.set("n", "<leader>aoc", "<CMD>Automaton open config<CR>")

-- Visual Mode
vim.keymap.set("v", "<F5>", "<CMD><C-U>Automaton launch default<CR>")
vim.keymap.set("v", "<F6>", "<CMD><C-U>Automaton debug default<CR>")
vim.keymap.set("v", "<F8>", "<CMD><C-U>Automaton tasks default<CR>")
vim.keymap.set("v", "<leader>al", "<CMD><C-U>Automaton launch<CR>")
vim.keymap.set("v", "<leader>ad", "<CMD><C-U>Automaton debug<CR>")
vim.keymap.set("v", "<leader>at", "<CMD><C-U>Automaton tasks<CR>")
```

## Contributing
Automaton's source code can be hacked easily, you can contribute in various ways:
- Fork this repository and send a [Pull Request](https://github.com/Dax89/automaton.nvim/pulls)
- Open an [Issue](https://github.com/Dax89/automaton.nvim/issues) with a feature request or a bug report
- Add more [Workspace Templates](https://github.com/Dax89/automaton.nvim/tree/master/lua/automaton/templates)
- Improve the [Wiki](https://github.com/Dax89/automaton.nvim/wiki)

## License
Automaton is licensed under the MIT License.<br>
See the [LICENSE](LICENSE) file for details.

## Related Projects
- [projectmgr](https://github.com/charludo/projectmgr.nvim)
- [project.nvim](https://github.com/ahmedkhalf/project.nvim)
- [neovim-cmake](https://github.com/Shatur/neovim-cmake)
