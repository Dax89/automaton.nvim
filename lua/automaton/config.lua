return {
    debug = false,
    saveall = true,
    ignore_ft = {},

    terminal = {
        COLORS = {
            black = 30,
            red = 31,
            green = 32,
            yellow = 33,
            blue = 34,
            magenta = 35,
            cyan = 36,
            white = 37
        },

        position = "botright",
        size = 10,
        color = 32,   -- Green
        altcolor = 33 -- Yellow
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
