-- shared code between memory units and fluid memory units

local min = math.min
local floor = math.floor

function clamp (x,upper,lower)
	return math.min(upper,math.max(lower,x))
end

local tier_borders = {
	[0] =    4000,
	[1] =    8000,
	[2] =   16000,
	[3] =   32000,
	[4] =   64000,
	[5] =  128000,
	[6] =  256000,
	[7] =  512000,
	[8] = 1024000
}

local base_graphs = {
	[0] = function (x) return 100 * math.pow(x,0.9) end,
	[1] = function (x) return 90 * math.pow(x,0.875) end,
	[2] = function (x) return 80 * math.pow(x,0.85) end,
	[3] = function (x) return 70 * math.pow(x,0.825) end,
	[4] = function (x) return 60 * math.pow(x,0.8) end,
	[5] = function (x) return 50 * math.pow(x,0.775) end,
	[6] = function (x) return 40 * math.pow(x,0.75) end,
	[7] = function (x) return 30 * math.pow(x,0.725) end,
	[8] = function (x) return 20 * math.pow(x,0.7) end,
}

local transition_heights = {}

--- created to reflect https://www.desmos.com/calculator/tqogtkoo5d
---@type table <number,function<number,number>>
local power_table = {tier_borders = tier_borders}

transition_heights[0] = 0
power_table[0] = base_graphs[0]

for i = 1,8,1 do
	transition_heights[i] = - base_graphs[i](tier_borders[i-1]) + power_table[i-1](tier_borders[i-1])
	power_table[i] = function (x) return transition_heights[i] + base_graphs[i](x) end
end

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
---@param power_usage? number
local function update_combinator(combinator, signal, count, power_usage)
	---@type LuaConstantCombinatorControlBehavior
	---@diagnostic disable-next-line: assign-type-mismatch
	local behavior = combinator.get_or_create_control_behavior()

	behavior.set_signal(1, {
		signal = signal,
		count = min(2147483647, count)
	})

	if power_usage == nil then return end

	behavior.set_signal(2, {
		signal = {type="virtual",name="signal-E"},
		count = min(2147483647, math.ceil(power_usage * 60 / 1000000))
	})
end

local power_usages = {
	['0W'] = 0,
	['60kW'] = 0.2,
	['180kW'] = 0.6,
	['300kW'] = 1,
	['480kW'] = 1.6,
	['600kW'] = 2,
	['1.2MW'] = 4,
	['2.4MW'] = 8
}

local base_usage = 1000000 / 60
---updates the power usage for the given unit
---@param unit_data any
---@param count any
local function update_power_usage(unit_data, count)
	local powersource = unit_data.powersource
	local power_usage = power_table[unit_data.energy_tier or 0](math.ceil(count / (unit_data.stack_size or 1000))) / 60 * 1000
	power_usage = power_usage + base_usage
	power_usage = power_usage * power_usages[(settings.global['memory-unit-power-usage']).value]
	unit_data.operation_cost = power_usage

	if unit_data.containment_field < settings.global["memory-unit-se-fox-containment-field"].value then -- we need to charge the containment field, increase the power usage
		power_usage = power_usage * 1.2
	end

	powersource.power_usage = power_usage
	powersource.electric_buffer_size = power_usage
	return power_usage
end

--- update rate in ticks
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

---returns whether the memory unit is considered functional (false if ok, true if not ok. Also corrupts broken units)
---@param unit_number number
---@param unit_data table
---@param force LuaForce
---@return boolean
local function validity_check(unit_number, unit_data, force, ignore_power)
	if not unit_data.entity.valid or not unit_data.powersource.valid or not unit_data.combinator.valid then
		memory_unit_corruption(unit_number, unit_data)
		return true
	end
	
	if not ignore_power and not force and not has_power(unit_data.powersource, unit_data.entity) then return true end
	if unit_data.overloaded_sprite then return true end

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
	combine_tempatures = combine_tempatures,
	clamp = clamp,
	power_table = power_table
}
