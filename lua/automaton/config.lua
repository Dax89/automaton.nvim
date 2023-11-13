local Utils = require("automaton.utils")

return {
    debug = false,
    saveall = true,
    ignore_ft = {},

    terminal = {
        position = "botright",
        size = 10,
        cmdcolor = Utils.colors.yellow,
    },

    icons = {
        buffer = "",
        close = "",
        launch = "",
        task = "",
        workspace = "",
        -- dap = "";
    },

    integrations = {
        luasnip = false,
        cmp = false,
    },

    events = {
        workspacechanged = nil,
    },

    impl = {
        VERSION = "1.0.0",

        workspace = ".automaton",
        variablesfile = "variables.json",
        tasksfile = "tasks.json",
        launchfile = "launch.json",
        configfile = "config.json",
        statefile = "state.json",
        recentsfile = "recents.json",
    }
}
