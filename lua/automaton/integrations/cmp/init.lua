local CmpIntegration = { }

function CmpIntegration.integrate(automaton)
    local ok, cmp = pcall(require, "cmp")

    if ok then
        local SchemaSource = require("automaton.integrations.cmp.schemasource")
        cmp.register_source("automatonschema", SchemaSource.new(automaton))
    else
        automaton.config.integrations.cmp = false
        vim.notify("Cmp is not installed, integration disabled")
    end
end

return CmpIntegration
