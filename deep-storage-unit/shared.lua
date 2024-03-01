-- shared code between memory units and fluid memory units

local min = math.min
local floor = math.floor

---turns a number into a human readable number
---@param n number
---@return table
local function compactify(n)
	n = floor(n)
	
	local suffix = 1
	local new
	while n >= 1000 do
		new = floor(n / 100) / 10
		if n == new then
			return {'big-numbers.infinity'}
		else
			n = new
		end
		suffix = suffix + 1
	end
	
---@diagnostic disable-next-line: cast-local-type
	if suffix ~= 1 and floor(n) == n then n = tostring(n) .. '.0' end
	
	return {'big-numbers.' .. suffix, n}
end

---creates a dummy inventory of some sort, idk
---@param player table
---@return LuaItemStack
local function open_inventory(player)
	if not global.blank_gui_item then
		local inventory = game.create_inventory(1)
		inventory[1].set_stack('blank-gui-item')
		inventory[1].allow_manual_label_change = false
		global.empty_gui_item = inventory[1]
	end
	player.opened = nil
	player.opened = global.empty_gui_item
	return player.opened
end


local function update_display_text(unit_data, entity, localised_string)
	if unit_data.text then
		rendering.set_text(unit_data.text, localised_string)
	else
		unit_data.text = rendering.draw_text{
			surface = entity.surface,
			target = entity,
			text = localised_string,
			alignment = 'center',
			scale = 1.5,
			only_in_alt_mode = true,
			color = {r = 1, g = 1, b = 1}
		}
	end
end

---updates the combinator for the given units
---@param combinator LuaEntity
---@param signal SignalID
---@param count number
local function update_combinator(combinator, signal, count)
---@diagnostic disable-next-line: undefined-field
	combinator.get_or_create_control_behavior().set_signal(1, {
		signal = signal,
		count = min(2147483647, count)
	})
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

local base_usage = 1000000 / 60
---updates the power usage for the given unit
---@param unit_data any
---@param count any
local function update_power_usage(unit_data, count)
	local powersource = unit_data.powersource
	local power_usage = (math.ceil(count / (unit_data.stack_size or 1000)) ^ 0.35) * power_usages[settings.global['memory-unit-power-usage'].value]
	power_usage = power_usage + base_usage
	powersource.power_usage = power_usage
	powersource.electric_buffer_size = power_usage
end

local update_rate = 15
local update_slots = 4

local function has_power(powersource, entity)
	if powersource.energy < powersource.electric_buffer_size * 0.9 then
		if powersource.energy ~= 0 then
			rendering.draw_sprite{
				sprite = 'utility.electricity_icon', 
				x_scale = 0.5,
				y_scale = 0.5,
				target = entity, 
				surface = entity.surface,
				time_to_live = 30
			}
		end
		return false
	end
	
	return not entity.to_be_deconstructed()
end


local basic_item_types = {['item'] = true, ['capsule'] = true, ['gun'] = true, ['rail-planner'] = true, ['module'] = true}
---return whether the given item is able to be stored
---@param item string
---@return boolean
local function check_for_basic_item(item)
	local items_with_metadata = global.items_with_metadata
	if not items_with_metadata then
		items_with_metadata = {}
		for item_name, prototype in pairs(game.item_prototypes) do
			if not basic_item_types[prototype.type] then
				items_with_metadata[item_name] = true
			end
		end
		global.items_with_metadata = items_with_metadata
	end
	return not items_with_metadata[item]
end

---destroys a unit
---@param unit_number number
---@param unit_data table
local function memory_unit_corruption(unit_number, unit_data)
	local entity = unit_data.entity
	local powersource = unit_data.powersource
	local combinator = unit_data.combinator
	
	if entity.valid then entity.destroy() end
	if powersource.valid then powersource.destroy() end
	if combinator.valid then combinator.destroy() end
	
	game.print{'memory-unit-corruption', unit_data.count, unit_data.item or 'nothing'}
	global.units[unit_number] = nil
end

---returns whether the memory unit is considered complete (false if ok, true if not ok)
---@param unit_number number
---@param unit_data table
---@param force LuaForce
---@return boolean
local function validity_check(unit_number, unit_data, force)
	if not unit_data.entity.valid or not unit_data.powersource.valid or not unit_data.combinator.valid then
		memory_unit_corruption(unit_number, unit_data)
		return true
	end
	
	if not force and not has_power(unit_data.powersource, unit_data.entity) then return true end
	return false
end

---combines temperatures of two given fluids respecting their ratio
---@param first_count number
---@param first_tempature number
---@param second_count number
---@param second_tempature number
---@return number
local function combine_tempatures(first_count, first_tempature, second_count, second_tempature)
	if first_tempature == second_tempature then return first_tempature end
	local total_count = first_count + second_count
	return (first_tempature * first_count / total_count) + (second_tempature * second_count / total_count)
end

return {
	update_display_text = update_display_text,
	update_combinator = update_combinator,
	has_power = has_power,
	update_power_usage = update_power_usage,
	update_rate = update_rate,
	update_slots = update_slots,
	compactify = compactify,
	open_inventory = open_inventory,
	check_for_basic_item = check_for_basic_item,
	memory_unit_corruption = memory_unit_corruption,
	validity_check = validity_check,
	combine_tempatures = combine_tempatures
}
