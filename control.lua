require 'gui'
require 'util'

local shared = require 'shared'
local update_rate = shared.update_rate
local update_slots = shared.update_slots
local compactify = shared.compactify
local validity_check = shared.validity_check
local clamp = shared.clamp
local has_power = shared.has_power

local beacons_max_count = {
	["se-wide-beacon"] = 0,
	["se-wide-beacon-2"] = 0,
	["se-compact-beacon"] = 4,
	["se-compact-beacon-2"] = 4,
}

--#region Temp functions
local update_storage_effects
local pad_area
local apply_item_loss
local update_storage_beacons
--#endregion

local function pickersetup()
	if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
		script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), function(event)
			---@diagnostic disable-next-line: undefined-field
			local entity = event.moved_entity --[[@as LuaEntity]]
			if entity.type == "beacon" then
				local surface = entity.surface

				local affected_storages = surface.find_entities_filtered { area = pad_area(entity.bounding_box, game.entity_prototypes[entity.name].supply_area_distance + 1), name = "memory-unit" }
			
				for _, value in pairs(affected_storages) do
					update_storage_beacons(global.units[value.unit_number], entity.name)
				end
			end
		end)
	end
end

--- Generates global units table
--- blacklists memory unit for picker dollies
local function setup()
	global.units = global.units or {}

	if remote.interfaces['PickerDollies'] then
		remote.call('PickerDollies', 'add_blacklist_name', 'memory-unit', true)
		remote.call('PickerDollies', 'add_blacklist_name', 'memory-unit-combinator', true)
	end

	pickersetup()
end

script.on_init(setup)
script.on_load(pickersetup)

--- Reloads units on config change, saves units with broken items
script.on_configuration_changed(function()
	setup()
	global.beacon_prototypes = nil
	for unit_number, unit_data in pairs(global.units) do
		---@diagnostic disable-next-line: missing-parameter
		if unit_data.item and not validity_check(unit_number, unit_data) then
			local prototype = game.item_prototypes[unit_data.item]
			if prototype then
				unit_data.stack_size = prototype.stack_size
				update_inventory_limits(unit_data)
			else
				shared.memory_unit_corruption(unit_number, unit_data)
			end
		end
	end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed,
	function(event)
		if event.setting == "memory-unit-se-fox-power-usage" then
			for unit_number, unit_data in pairs(global.units) do
				local total_count = unit_data.count
				if unit_data.item then
					total_count = total_count + unit_data.inventory.get_item_count(unit_data.item)
				end
				shared.update_power_usage(unit_data, total_count)
			end
		end
	end
)

--- updates the circuit, display text and power usage
---@param unit_data table
---@param inventory_count number
local function update_unit_exterior(unit_data, inventory_count)
	local entity = unit_data.entity
	unit_data.previous_inventory_count = inventory_count
	local total_count = unit_data.count + inventory_count

	local power_draw = shared.update_power_usage(unit_data, total_count)
	shared.update_combinator(unit_data.combinator, { type = 'item', name = unit_data.item }, total_count, power_draw)
	shared.update_display_text(unit_data, entity, compactify(total_count))
end

--- sets the filters of the given unit, spills item stacks that do not match the item in the unit data
--- @param unit_data table
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

---initializes empty units with an item type
---@param unit_data table
---@return boolean
local function detect_item(unit_data)
	local inventory = unit_data.inventory
	for name, count in pairs(inventory.get_contents()) do
		if shared.check_for_basic_item(name) then
			set_item(unit_data, name)
			return true
		end
	end
	return false
end

function update_unit(unit_data, unit_number, force)
	local entity = unit_data.entity
	local powersource = unit_data.powersource
	local combinator = unit_data.combinator
	local container = unit_data.container
	local inventory = unit_data.inventory

	update_storage_effects(unit_data)

	unit_data.last_action = 0
	if validity_check(unit_number, unit_data, force, true) then return end



	if unit_data.item == nil then changed = detect_item(unit_data) end
	local item = unit_data.item

	if item == nil then return end

	local inventory_count
	local changed = false

	if force or not apply_item_loss(unit_data) then -- skips applying item loss if the event was generated artificially
		inventory_count = inventory.get_item_count(item)

		--- set i/o cap, scale up slightly to allow for some fuckery
		local max_conversion_speed = math.ceil(unit_data.max_conversion_speed * 1.05)
		local comfortable = unit_data.comfortable

		if inventory_count > comfortable then
			unit_data.last_action = comfortable - inventory_count
			local amount_removed = inventory.remove { name = item, count = math.min(inventory_count - comfortable, max_conversion_speed) }
			unit_data.count = unit_data.count + amount_removed
			inventory_count = inventory_count - amount_removed
			changed = true
		elseif inventory_count < comfortable then
			if unit_data.previous_inventory_count ~= inventory_count then
				changed = true
			end
			local to_add = math.min(comfortable - inventory_count, max_conversion_speed)
			if unit_data.count < to_add then
				to_add = unit_data.count
			end
			if to_add > 0 then
				unit_data.last_action = comfortable - inventory_count
				local amount_added = entity.insert { name = item, count = to_add }
				unit_data.count = unit_data.count - amount_added
				inventory_count = inventory_count + amount_added
			end
		end

		unit_data.last_action = unit_data.last_action or 0
	end
	if force or changed then
		inventory.sort_and_merge()
		update_unit_exterior(unit_data, inventory_count)
	end
end

script.on_nth_tick(update_rate, function(event)
	local smooth_ups = event.tick % update_slots

	for unit_number, unit_data in pairs(global.units) do
		if unit_data.lag_id == smooth_ups then
			update_unit(unit_data, unit_number)
		end
	end
end)

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



local function on_created_storage(event)
	local entity = event.created_entity or event.entity
	local position = entity.position
	local surface = entity.surface
	local force = entity.force

	local combinator = create_combinator(surface, position, force)

	local powersource = create_powersource(surface, position, force)

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

	local stack = event.stack
	local tags = stack and stack.valid_for_read and stack.type == 'item-with-tags' and stack.tags
	if tags and tags.name then
		unit_data.count = tags.count
		unit_data.item = tags.name
		unit_data.stack_size = game.item_prototypes[tags.name].stack_size
		set_filter(unit_data)
		update_inventory_limits(unit_data)
		update_unit(unit_data, entity.unit_number, true)
	else
		if unit_data.inventory.get_filter(1) then
			set_item(unit_data, unit_data.inventory.get_filter(1))
		end
		shared.update_power_usage(unit_data, 0)
	end

	update_storage_effects(unit_data)
end

local function on_created_beacon(event)
	if not global.beacon_prototypes then
		global.beacon_prototypes = game.get_filtered_entity_prototypes { { filter = "type", type = "beacon" } }
	end
	local entity = event.created_entity or event.entity --[[@as LuaEntity]]
	local surface = entity.surface

	local affected_storages = surface.find_entities_filtered { area = pad_area(entity.bounding_box, game.entity_prototypes[entity.name].supply_area_distance), name = "memory-unit" }

	for _, value in pairs(affected_storages) do
		update_storage_beacons(global.units[value.unit_number], entity.name)
	end
end

local function on_created(event)
	local entity = event.created_entity or event.entity --[[@as LuaEntity]]
	if entity.name == 'memory-unit' then
		on_created_storage(event)
	elseif entity.type == "beacon" then
		on_created_beacon(event)
	end
end

function set_item_from_filter(unit_data)
	if not unit_data.inventory or not unit_data.inventory.get_filter(1) then return end
	local name = unit_data.inventory.get_filter(1)
	set_item(unit_data, name)
	update_unit_exterior(unit_data, unit_data.count + unit_data.inventory.get_item_count(unit_data.item))
end

script.on_event(defines.events.on_entity_settings_pasted, function(event)
	entity = event.destination
	if global.units[entity.unit_number] then
		set_item_from_filter(global.units[entity.unit_number])
	end
end)

script.on_event(defines.events.on_built_entity, on_created)
script.on_event(defines.events.on_robot_built_entity, on_created)
script.on_event(defines.events.script_raised_built, on_created)
script.on_event(defines.events.script_raised_revive, on_created)

-- Handles cloning the storage
script.on_event(defines.events.on_entity_cloned, function(event)
	local source = event.source

	if source.name ~= 'memory-unit' then return end
	local destination = event.destination

	local unit_data = global.units[source.unit_number]
	local position = destination.position
	local surface = destination.surface
	local force = destination.force

	-- we have to first try to "adopt" components that already exist in the world. This is mostly because SpaceExploration spaceships will copy the components as well, which creates duplicates
	local powersource = surface.find_entities_filtered { position = position, name = "memory-unit-powersource" }[1]
	local combinator = surface.find_entities_filtered { position = { position.x + combinator_shift_x, position.y + combinator_shift_y }, name = "memory-unit-combinator" }
	[1]

	if not powersource then
		powersource = unit_data.powersource
		if powersource.valid then
			powersource = powersource.clone { position = position, surface = surface }
		else
			powersource = create_powersource(surface, position, force)
		end
	end

	if not combinator then
		if combinator.valid then
			combinator = combinator.clone { position = { position.x + combinator_shift_x, position.y+ combinator_shift_y }, surface = surface }
		else
			combinator = create_combinator(surface, position, force)
		end
	end


	local item = unit_data.item
	unit_data = {
		powersource = powersource,
		combinator = combinator,
		item = item,
		count = unit_data.count,
		entity = destination,
		comfortable = unit_data.comfortable,
		stack_size = unit_data.stack_size,
		inventory = destination.get_inventory(defines.inventory.chest),
		lag_id = math.random(0, update_slots - 1),
		containment_field = unit_data.containment_field
	}

	if not global.beacon_prototypes then
		global.beacon_prototypes = game.get_filtered_entity_prototypes { { filter = "type", type = "beacon" } }
	end

	for name, _ in pairs(global.beacon_prototypes) do
		update_storage_beacons(unit_data,name)
	end

	global.units[destination.unit_number] = unit_data

	if item then
		set_filter(unit_data)
		update_unit(global.units[destination.unit_number], destination.unit_number, true)
	end
end)



local function on_destroyed_storage(event)
	local entity = event.entity
	if entity.name ~= 'memory-unit' then return end

	local unit_data = global.units[entity.unit_number]
	global.units[entity.unit_number] = nil
	unit_data.powersource.destroy()
	unit_data.combinator.destroy()

	local item = unit_data.item
	local count = unit_data.count
	local buffer = event.buffer

	if buffer and item and count ~= 0 then
		buffer.clear()
		buffer.insert('memory-unit-with-tags')
		local stack = buffer.find_item_stack('memory-unit-with-tags')
		stack.tags = { name = item, count = count }
		stack.custom_description = {
			'item-description.memory-unit-with-tags',
			compactify(count),
			item
		}
	end
end

local function on_destroyed_beacon(event)
	if not global.beacon_prototypes then
		global.beacon_prototypes = game.get_filtered_entity_prototypes { { filter = "type", type = "beacon" } }
	end
	local entity = event.entity --[[@as LuaEntity]]
	local surface = entity.surface

	local affected_storages = surface.find_entities_filtered { area = pad_area(entity.bounding_box, game.entity_prototypes[entity.name].supply_area_distance), name = "memory-unit" }

	for _, value in pairs(affected_storages) do
		update_storage_beacons(global.units[value.unit_number], entity.name, entity.unit_number)
	end
end

local function on_destroyed(event)
	local entity = event.entity
	if entity.name == 'memory-unit' then
		on_destroyed_storage(event)
	elseif entity.type == "beacon" then
		on_destroyed_beacon(event)
	end
end

script.on_event(defines.events.on_player_mined_entity, on_destroyed)
script.on_event(defines.events.on_robot_mined_entity, on_destroyed)
script.on_event(defines.events.on_entity_died, on_destroyed)
script.on_event(defines.events.script_raised_destroy, on_destroyed)

local function pre_mined(event)
	local entity = event.entity
	if entity.name ~= 'memory-unit' then return end

	local unit_data = global.units[entity.unit_number]
	local item = unit_data.item

	if item then
		local inventory = unit_data.inventory
		local in_inventory = inventory.get_item_count(item)

		if in_inventory > 0 then
			unit_data.count = unit_data.count + inventory.remove { name = item, count = in_inventory }
		end
	end
end

script.on_event(defines.events.on_pre_player_mined_item, pre_mined)
script.on_event(defines.events.on_robot_pre_mined, pre_mined)
script.on_event(defines.events.on_marked_for_deconstruction, pre_mined)

--#region I have no idea what will come here, for now this is the code for beacon interactions
---handles overloading a storage when blacklisted beacons are used
---@param unit_data table
function overload_storage(unit_data, name)
	-- map alert
	for _, player in pairs(unit_data.entity.force.players) do
		local conflict_string
		if beacons_max_count[name] == 0 then
			conflict_string = "entity-overloading.invalid-beacon-tooltip"
		else
			conflict_string = "entity-overloading.invalid-beacon-tooltip-too-many"
		end
		player.add_custom_alert(unit_data.entity, { type = "virtual", name = "se-beacon-overload" },
			{ conflict_string, "[img=virtual-signal/se-beacon-overload]", "[img=entity/" .. name .. "]",
				beacons_max_count[name] },
			true)
	end

	-- create sprite on machine
	if not unit_data.overloaded_sprite or not rendering.is_valid(unit_data.overloaded_sprite) then
		unit_data.overloaded_sprite = rendering.draw_sprite { sprite = "virtual-signal/se-beacon-overload", surface = unit_data.entity.surface, target = unit_data.entity }
	end
end

function overload_storage_clear(unit_data)
	if unit_data.overloaded_sprite and rendering.is_valid(unit_data.overloaded_sprite) then
		rendering.destroy(unit_data.overloaded_sprite)
	end

	unit_data.overloaded_sprite = nil
end

function apply_item_loss(unit_data)
	local powersource = unit_data.powersource
	local inventory = unit_data.inventory
	local item = unit_data.item

	if not item or not powersource or not unit_data.count then
		return false --storage is not initialized yet or has invalid properties that prevent calculations
	end

	if powersource.energy >= powersource.electric_buffer_size * 0.5 then -- storage has enough power, do not leak items
		if has_power(unit_data.powersource, unit_data.entity) then
			---@diagnostic disable-next-line: param-type-mismatch
			unit_data.containment_field = math.min(unit_data.containment_field + 4,
				---@diagnostic disable-next-line: param-type-mismatch
				settings.global["memory-unit-se-fox-containment-field"].value)
			return false
		end
	end

	if unit_data.containment_field > 0 then -- storage has remaining containment field, drain that and do not delete items
		unit_data.containment_field = unit_data.containment_field - 1

		rendering.draw_sprite { sprite = "utility/warning_icon", surface = unit_data.entity.surface, target = unit_data.entity, time_to_live = 30, x_scale = 0.5, y_scale = 0.5 }
		for _, player in pairs(unit_data.entity.force.players) do
			player.add_custom_alert(unit_data.entity, { type = "item", name = "energy-shield-equipment" },
				{ "alert.power-outage-warning" },
				true)
		end
	else
		if unit_data.count > 0 then
			local inventory_count = inventory.get_item_count(item) -- no containment field left, slowly delete items
			unit_data.count = unit_data.count * (1 - settings.global["memory-unit-se-fox-item-loss"].value)
			update_unit_exterior(unit_data, inventory_count)


			signal = "virtual-signal/se-anomaly" -- the anomaly is just a cooler item that fits
			rendering.draw_sprite { sprite = signal, surface = unit_data.entity.surface, target = unit_data.entity, time_to_live = 30, x_scale = 1.5, y_scale = 1.5, tint = {} }
			rendering.draw_sprite { sprite = signal, surface = unit_data.entity.surface, target = unit_data.entity, time_to_live = 30 }

			for _, player in pairs(unit_data.entity.force.players) do
				player.add_custom_alert(unit_data.entity, { type = "virtual", name = "se-anomaly" },
					{ "alert.power-outage-critical" },
					true)
			end
		end
		return true
	end
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

---Calculates the tiers for the two different cores of the storage
---@param unit_data table
function calculate_tiers(unit_data)
	if not unit_data.effects then return end

	unit_data.conversion_tier = clamp(math.floor(unit_data.effects.speed), 17, 0)
	unit_data.energy_tier = clamp(math.floor((-unit_data.effects.energy) / 72 * 4), 8, 0)
end

function calculate_needed(unit_data)
	local conversion_tier, energy_tier = unit_data.conversion_tier, unit_data.energy_tier

	-- percentage needed for the next tier

	conversion_tier = conversion_tier + 1
	energy_tier = (energy_tier + 1) * 72

	unit_data.conversion_to_next_tier = conversion_tier - unit_data.effects.speed
	unit_data.energy_to_next_tier = energy_tier + unit_data.effects.energy -- energy is negative
end

function update_storage_beacons(unit_data, name, exclude)
	local unit = unit_data.entity

	if not unit_data.beacons then unit_data.beacons = {} end
	unit_data.beacons[name] = unit.surface.find_entities_filtered { area = pad_area(unit.bounding_box, game.entity_prototypes[name].supply_area_distance), name = name }

	if exclude then
		for i, value in pairs(unit_data.beacons[name]) do
			if value.unit_number == exclude then
				unit_data.beacons[name][i] = nil
			end
		end
	end

	if beacons_max_count[name] and unit_data.beacons[name] and #unit_data.beacons[name] > beacons_max_count[name] then
		overload_storage(unit_data, name)
	elseif unit_data.overloaded_sprite then
		overload_storage_clear(unit_data)
	end
end

function update_storage_effects(unit_data)
	local unit = unit_data.entity
	local effects = {
		speed = 0,
		energy = 0,
	}

	for name, beacons in pairs(unit_data.beacons or {}) do
		for _, beacon in pairs(beacons) do
			if beacon.energy == 0 then goto continue end
			if beacon.effects then
				local effectivity = game.entity_prototypes[name].distribution_effectivity
				effects.speed = effects.speed + ((beacon.effects.speed or { bonus = 0 }).bonus) * effectivity
				effects.energy = effects.energy + ((beacon.effects.consumption or { bonus = 0 }).bonus) * effectivity
			end
			::continue::
		end
	end

	unit_data.effects = effects

	calculate_tiers(unit_data)
	calculate_needed(unit_data)

	local new_max_conversion_speed = (unit_data.conversion_tier + 1) * (update_rate * update_slots) / 60 * 60

	if unit_data.max_conversion_speed == new_max_conversion_speed then return end

	unit_data.max_conversion_speed = new_max_conversion_speed
	if not unit_data.stack_size then return end

	update_inventory_limits(unit_data)
end

---pad an area by a given amount
---@param area BoundingBox
---@param padding number
---@return BoundingBox
function pad_area(area, padding)
	for index1, value1 in pairs(area) do
		for index2, value2 in pairs(value1) do
			if index1 == 1 or index1 == "left_top" then
				area[index1][index2] = value2 - padding
			else
				area[index1][index2] = value2 + padding
			end
		end
	end

	return area
end

--#endregion
