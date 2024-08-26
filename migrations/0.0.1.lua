-- This attempts to resolve all issues when migrating from a save with the original DSU mod
local shared = require 'shared'
local update_slots = shared.update_slots

local combinator_shift_x = 2.25
local combinator_shift_y = 1.75

local function create_combinator(surface, position, force)
    local combinator = surface.create_entity {
        name = 'memory-unit-combinator',
        position = { position.x + combinator_shift_x, position.y + combinator_shift_y },
        force = force
    }

    combinator.operable = false
    combinator.destructible = false

    return combinator
end

local function create_powersource(surface, position, force)
    local powersource = surface.create_entity {
        name = 'memory-unit-powersource',
        position = position,
        force = force
    }
    powersource.destructible = false
    return powersource
end

function update_inventory_limits(unit_data)
    local inventory_limit

    if unit_data.max_conversion_speed then
        inventory_limit = math.min(
        --- we want to be able to buffer 8 cycles in either direction
            math.ceil(unit_data.max_conversion_speed * 8 / unit_data.stack_size) * 2,
            --- use inventory size as maximum
            #unit_data.inventory)
    else
        inventory_limit = 2
    end

    unit_data.comfortable = unit_data.stack_size * inventory_limit / 2
    unit_data.inventory.set_bar(inventory_limit + 1)
end

function set_filter(unit_data)
    local inventory = unit_data.inventory
    local item = unit_data.item
    local entity = unit_data.entity
    for i = 1, #inventory do
        local stack = inventory[i]
        if not inventory.set_filter(i, item) or (stack.valid_for_read and stack.name ~= item) then
            entity.surface.spill_item_stack(entity.position, stack)
            stack.clear()
            inventory.set_filter(i, item)
        end
    end
end

local function set_item(unit_data, name)
    unit_data.item = name
    unit_data.stack_size = game.item_prototypes[name].stack_size
    set_filter(unit_data)
    update_inventory_limits(unit_data)
end

local power_usages = {
	['0W'] = 0,
	['60kW'] = 1000,
	['180kW'] = 3000,
	['300kW'] = 5000,
	['480kW'] = 8000,
	['600kW'] = 10000,
	['1.2MW'] = 20000,
	['2.4MW'] = 40000
}

local function item_count_from_power_usage(power_usage, stack_size)
    -- basically an "inverse" for the function that calculates count from the unit power consumption. Used when the actual number of items from the combinator is capped by factorio
    -- local power_usage = 1000000 / 60 + (math.ceil(count / (unit_data.stack_size or 1000)) ^ 0.35) * power_usages[settings.global['memory-unit-power-usage'].value]
    return (((power_usage - 1000000 / 60) / (power_usages[(settings.global['memory-unit-power-usage']).value])) ^ (1/0.35) * (stack_size or 1000))

end

local function patch_storage(entity)
    game.print('Unit ' .. entity.unit_number .. ' has no associated global entry, generating...')
    local position = entity.position
    local surface = entity.surface --[[@as LuaSurface]]
    local force = entity.force --[[@as LuaForce]]

    local combinator = surface.find_entity("memory-unit-combinator",
        { position.x + combinator_shift_x, position.y + combinator_shift_y })

    if not combinator then
        game.print("Unit has no associated combinator")
        combinator = create_combinator(surface, position, force)
    end

    local powersource = surface.find_entity("memory-unit-powersource", { position.x, position.y })

    if not powersource then
        game.print("Unit has no associated powersource")
        powersource = create_powersource(surface, position, force)
    end

    local unit_data = {
        entity = entity,
        count = 0,
        powersource = powersource,
        combinator = combinator,
        inventory = entity.get_inventory(defines.inventory.chest),
        lag_id = math.random(0, update_slots - 1),
        containment_field = 0
    }
    global.units[entity.unit_number] = unit_data

    local combinator_control = combinator.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    if not combinator_control then return end

    local signal = combinator_control.get_signal(1)
    if not signal or not signal.signal or signal.signal.type ~= "item" then game.print("Unable to recover unit data."); return end

    set_item(unit_data, signal.signal.name)

    local count = signal.count

    if count > 2100000000 then -- count is probably capped by factorio and we can't rely on the signal value
        if powersource and powersource.power_usage then
            count = item_count_from_power_usage(powersource.power_usage, unit_data.stack_size)
        end
    end

    global.units[entity.unit_number].count = count
end

for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = 'memory-unit' })) do
        if not global.units[entity.unit_number] then
            patch_storage(entity)
        end
    end
end
