local CmpIntegration = { }

function CmpIntegration.integrate(automaton)
    local ok, cmp = pcall(require, "cmp")

    if ok then
        local SchemaSource = require("automaton.integrations.cmp.schemasource")
        local VariableSource = require("automaton.integrations.cmp.variablesource")
        cmp.register_source("automatonschema", SchemaSource.new(automaton))
        cmp.register_source("automatonvariable", VariableSource.new(automaton))
    else
        automaton.config.integrations.cmp = false
        vim.notify("Cmp is not installed, integration disabled")
    end
end

return CmpIntegration
