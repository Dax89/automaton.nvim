return {
    debug = false,
    saveall = true,

    icons = {
        buffer = "",
        close = "",
        launch = "",
        task = "",
        workspace = "",
        -- dap = "";
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
