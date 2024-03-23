-- stop the SE-compat override
if mods["space-exploration"] then
    local recipe = data.raw.recipe["memory-unit"]
    recipe.ingredients = {
        {'aai-warehouse', 1},
        {'se-holmium-solenoid', 30},
        {'se-space-supercomputer-1',2},
        {'se-heavy-girder',20},
        {'se-magnetic-canister',10},
        {'se-forcefield-data',5},
        {type="fluid", name="water", amount=100000},
    }
    recipe.category = "advanced-crafting"
    
    local tech = data.raw.technology["memory-unit"]
    tech.prerequisites = {"se-holmium-solenoid","se-heavy-girder","se-astronomic-science-pack-1"}
    tech.unit.ingredients = {
        {"automation-science-pack",1},
        {"logistic-science-pack",1},
        {"chemical-science-pack",1},
        {"se-rocket-science-pack",1},
        {"space-science-pack",1},
        {"utility-science-pack",1},
        {"production-science-pack",1},
        {"se-astronomic-science-pack-1",1},
        {"se-energy-science-pack-2",1},
        {"se-material-science-pack-1",1},
    }
end