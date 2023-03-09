local LuaSnipIntegration = { }

function LuaSnipIntegration.integrate(automaton)
    local Path = require("plenary.path")
    local Utils = require("automaton.utils")
    local ok, luasnip = pcall(require, "luasnip.loaders.from_vscode")

    if ok then
        local path = Path:new(Utils.get_plugin_root(), "integrations", "luasnip", "snippets")
        luasnip.load({paths = tostring(path)})
    else
        automaton.config.integrations.luasnip = false
        vim.notify("LuaSnip is not installed, integration disabled")
    end
end

return LuaSnipIntegration

