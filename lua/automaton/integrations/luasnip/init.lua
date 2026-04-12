local LuaSnipIntegration = {}

function LuaSnipIntegration.integrate(automaton)
    local Utils = require("automaton.utils")
    local ok, luasnip = pcall(require, "luasnip.loaders.from_vscode")

    if ok then
        local path = vim.fs.joinpath(Utils.get_plugin_root(), "integrations", "luasnip", "snippets")
        luasnip.load({ paths = tostring(path) })
    else
        automaton.config.integrations.luasnip = false
    end
end

return LuaSnipIntegration
