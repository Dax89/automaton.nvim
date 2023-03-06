return {
    debug = false,
    saveall = true,
    ignore_ft = {},

    icons = {
        buffer = "",
        close = "",
        launch = "",
        task = "",
        workspace = "",
        -- dap = "";
    },

    integrations = {
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
