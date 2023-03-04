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
  <a href="https://github.com/nvim-telescope/telescope.nvim">Telescope</a> and <a href="https://json5.org">JSON5</a> powered VSCode-like Workspace, Tasks and Launch configuration
</p>

# Installation

### Packer
```lua
use {
  "Dax89/automaton.nvim",  
  requires = { 
       {"nvim-lua/plenary.nvim"},
       {"nvim-telescope/telescope.nvim"},
       {"mfussenegger/nvim-dap"}, -- Debug support for 'launch' configurations (Optional)
    }
}
```

### Lazy
```lua
{
  "Dax89/automaton.nvim",  
  dependencies = {
       "nvim-lua/plenary.nvim",
       "nvim-telescope/telescope.nvim",
       "mfussenegger/nvim-dap", -- Debug support for 'launch' configurations (Optional)
  }
}
```

# Config (with defaults)
```lua
require("automaton").setup({
    debug = false,
    saveall = true,
    
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

# Getting Started

### tasks.json
```json5
{
    version: "1.0.0",
    
    tasks: [
        {
            name: "Init NPM",
            cwd: "${workspace_dir}",
            type: "shell",
            command: "npm init -y",
        },
        {
            name: "Install dependencies",
            cwd: "${workspace_dir}",
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

### launch.json
```json5
{
    version: "1.0.0",
    
    configurations: [
        {
            name: "Execute index",
            cwd: "${workspace_dir}",
            program: "node ${workspace_dir}/index.js",
            default: true, // Set as default launch configuration
            depends: ["Install dependencies"], // Always execute dependency installation

            // DAP Configuration (optional)
            type: "cppdpg", // Equals to 'dap.adapters.[key]' from your DAP config

            // Extra fields are forwarded to dap.run() command
        }
    ]
}
```


# Commands

```lua
:Automaton create  -- Create a new workspace
           recents -- Shows recent workspaces
           init    -- Initializes a workspace in "cwd"
           load    -- Loads a workspace in "cwd"
           workspaces -- Manage loaded workspaces
           jobs    -- Shows running tasks/launch (can be killed too)
           config  -- Show/Edit workspace settings
           launch default [debug] -- Exec default launch configuration ("debug" is optional)
           launch [debug] -- Select and exec a launch configuration ("debug" is optional)
           tasks default -- Exec default task
           tasks  -- Select and exec task
           open launch -- Open workspace's launch.json
           open tasks-- Open workspace's tasks.json
           open variables -- Open workspace's variables.json
           open config -- Open workspace's config.json
```

# Related Projects
- [projectmgr](https://github.com/charludo/projectmgr.nvim)
- [project.nvim](https://github.com/ahmedkhalf/project.nvim)
- [neovim-cmake](https://github.com/Shatur/neovim-cmake)
