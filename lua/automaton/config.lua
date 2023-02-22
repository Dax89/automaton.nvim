return {
    debug = false,
    saveall = true,

    icons = {
        launch = "",
        task = "",
        -- dap = "";
    },

    events = {
        workspacechanged = nil,
    },

    impl = {
        workspace = ".automaton",
        variablesfile = "variables.json",
        tasksfile = "tasks.json",
        launchfile = "launch.json",
    }
}
