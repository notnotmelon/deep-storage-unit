local shared = require 'shared'
local compactify = shared.compactify
local update_power_usage = shared.update_power_usage
local power_table = shared.power_table

local function format_energy(energy)
	local consumption = energy * 60 / 1000000

	local mag = 1
	while consumption >= 1000 do
		consumption = consumption / 1000
		mag = mag + 1
	end

	local unit_table = {
		[1] = 'MW',
		[2] = 'GW',
		[3] = 'TW',
		[4] = 'PW',
		[5] = 'EW'
	}

	local suffix = unit_table[mag] or 'a lot!'
	
	return string.format('%.2f',consumption ) .. suffix
end

local function mark_warning(header, bool)
	if bool then
		header.style = "negative_subheader_frame"
	else
		header.style = "subheader_frame"
	end
	---@diagnostic disable-next-line: inject-field
	header.style.horizontally_stretchable = true
end

local function update_gui(gui, fresh_gui)
	local unit_data = global.units[gui.tags.unit_number]
	if not unit_data then gui.destroy() return end
	local content_flow = gui.main_flow.content_frame.content_flow
	
	local memory_frame = gui.main_flow.memory_frame
	local mc_frame = gui.main_flow.mc_frame
	
	local entity = unit_data.entity
	local powersource = unit_data.powersource
	
	if not entity.valid or not powersource.valid then return end
	
	local containment_field_max = settings.global["memory-unit-se-fox-containment-field"].value

	local count = unit_data.count
	local inventory = unit_data.inventory
	local deconstructed = entity.to_be_deconstructed()
	local inventory_count = 0
	if unit_data.item then
		inventory_count = inventory.get_item_count(unit_data.item)
		if fresh_gui or not deconstructed then
			content_flow.storage_flow.info_flow.content_sprite.sprite = 'item/' .. unit_data.item
			content_flow.storage_flow.info_flow.current_storage.caption = {
				'',
				{'', '[font=default-semibold][color=255,230,192]', game.item_prototypes[unit_data.item].localised_name},
				{'', ':[/color][/font] ', compactify(count + inventory_count)}
			}
		end
	end
	local visible = not not unit_data.item
	content_flow.storage_flow.visible = visible
	content_flow.storage_flow.io_flow.visible = visible
	content_flow.no_input_item.visible = not visible
	
	--- Memory UI
	memory_frame.memory_containment_flow.memory_containment_strength.value = unit_data.containment_field / containment_field_max
	memory_frame.memory_status_flow.memory_electricity_flow.memory_electricity_label.caption = format_energy(powersource.energy) .. ' / [font=default-semibold][color=255,230,192]' .. format_energy(powersource.electric_buffer_size) .. '[/color][/font]'
	memory_frame.memory_header.memory_header_flow.memory_header_tier_label.caption={"mod-gui.tier-info",unit_data.energy_tier or "?", 8}
	if unit_data.energy_tier and unit_data.energy_tier < 8 then
		memory_frame.memory_header.memory_header_flow.memory_header_tier_label.tooltip={"mod-gui.memory-tab-tier-tooltip",-math.ceil(unit_data.energy_to_next_tier*100)}
	end
	
	if unit_data.item then update_power_usage(unit_data, count + inventory_count) end

	local low_power = powersource.energy < powersource.electric_buffer_size * 0.9
	
	--- Memory UI

	--States:
	--no item -> red light, no item text
	--building overloaded -> yellow light, overload text
	--discharging -> yellow light, discharge text
	--voiding items -> red light, voiding text
	--suboptimal config -> yellow light, suboptimal config text
	--working -> green light, working text
	
	local sprite = memory_frame.memory_status_flow.memory_status_sprite
	local label = memory_frame.memory_status_flow.memory_status_label
	local header = memory_frame.memory_header

	mark_warning(header,false)
	if not unit_data.item then
		sprite.sprite="utility/status_not_working"
		label.caption={"entity-status.no-input-item"}
	elseif unit_data.overloaded_sprite then
		sprite.sprite = "utility/status_yellow"
		label.caption = {"entity-status.invalid-beacon"}
	elseif low_power then
		if unit_data.containment_field > 0 then
			sprite.sprite="utility/status_yellow"
			label.caption={"entity-status.discharging"}
		else
			sprite.sprite="utility/status_not_working"
			label.caption={"entity-status.voiding"}
			mark_warning(memory_frame.memory_header,true)
		end
	else		
		local warning_threshold = power_table.tier_borders[unit_data.energy_tier]
		if unit_data.count/unit_data.stack_size > warning_threshold then
			sprite.sprite="utility/status_yellow"
			label.caption={"entity-status.suboptimal"}
			mark_warning(memory_frame.memory_header,true)
		else
			if unit_data.containment_field < containment_field_max then
				sprite.sprite="utility/status_working"
				label.caption={"entity-status.charging"}
			else
				sprite.sprite="utility/status_working"
				label.caption={"entity-status.working"}
			end
		end
	end


	--- Matter Conversion UI
	--States:
	--no item -> red light, no item text
	--building overloaded -> yellow light, overload text
	--low power -> yellow light, low power text
	--overloaded -> yellow light, overload text, warning marker
	--working -> green light, working text
	
	sprite = mc_frame.mc_status_flow.mc_status_sprite
	label = mc_frame.mc_status_flow.mc_status_label
	header = mc_frame.mc_header
	
	mark_warning(header,false)

	if not unit_data.item then
		sprite.sprite = "utility/status_not_working"
		label.caption = {"entity-status.no-input-item"}
	
	elseif unit_data.overloaded_sprite then
		sprite.sprite = "utility/status_yellow"
		label.caption = {"entity-status.invalid-beacon"}
	else
		local max_count = (unit_data.inventory.get_bar() - 1) * unit_data.stack_size
		local filled_percent = unit_data.inventory.get_item_count(unit_data.item) / max_count
		mc_frame.mc_info_flow.matter_buffer.value = filled_percent
		if low_power then
			sprite.sprite = "utility/status_yellow"
			label.caption = {"entity-status.low-power"}
			mark_warning(mc_frame.mc_header,true)
		else
			
			if filled_percent > 0.875 or (filled_percent < 0.125 and unit_data.count > 0) then
			sprite.sprite = "utility/status_yellow"
			label.caption = {"entity-status.overloaded"}
			mark_warning(mc_frame.mc_header,true)
			else
				sprite.sprite = "utility/status_working"
				label.caption = {"entity-status.working"}
			end
		end
	end


	local last_action = unit_data.last_action or 0
	local function states ()
		if not last_action or last_action == 0 then return {"entity-status.idle"} end
		if last_action < 0 then return {"entity-status.inserting"} end
		if last_action > 0 then return {"entity-status.extracting"} end
	end
	
	mc_frame.mc_status_flow.mc_info_flow.mc_info_label.caption = {
		'',
		states() , 
		' ' .. math.min(math.abs(last_action),unit_data.max_conversion_speed) .. ' / [font=default-semibold][color=255,230,192]' .. unit_data.max_conversion_speed .. '[/color][/font] items/s'
	}
	
	mc_frame.mc_header.mc_header_flow.mc_header_tier_label.caption={"mod-gui.tier-info",(unit_data.conversion_tier or "?"),17}
	if unit_data.conversion_tier and unit_data.conversion_tier < 17 then
		mc_frame.mc_header.mc_header_flow.mc_header_tier_label.tooltip={"mod-gui.matter-tab-tier-tooltip",math.ceil(unit_data.conversion_to_next_tier*100)}
	end

	
	--[[

	local status, img
	if entity.to_be_deconstructed() then
		status = {'entity-status.marked-for-deconstruction'}
		img = 'utility/status_not_working'
	elseif powersource.energy == 0 then
		status = {'entity-status.no-power'}
		img = 'utility/status_not_working'
	elseif not unit_data.item then
		for name, _ in pairs(inventory.get_contents()) do
			if not shared.check_for_basic_item(name) then
				status = {'entity-status.cannot-store', game.item_prototypes[name].localised_name}
				img = 'utility/status_not_working'
				goto cannot_store
			end
		end
		status = {'entity-status.no-input-item'}
		img = 'utility/status_not_working'
		::cannot_store::
	elseif powersource.energy < powersource.electric_buffer_size * 0.9 then
		status = {'entity-status.low-power'}
		img = 'utility/status_yellow'
	else
		status = {'entity-status.working'}
		img = 'utility/status_working'
	end
	
	content_flow.status_flow.status_text.caption = status
	content_flow.status_flow.status_sprite.sprite = img
	]]
end

script.on_nth_tick(2, function(event)
	for _, player in pairs(game.connected_players) do
		if player.opened_gui_type == defines.gui_type.item then
			local gui = player.gui.relative.memory_unit_gui
			if gui then update_gui(gui) end
		end
	end
end)

--- Destroys GUI when the player changes surface
script.on_event(defines.events.on_player_changed_surface, function(event)
	local player = game.get_player(event.player_index)
	if player.opened_gui_type == defines.gui_type.item then
		local gui = player.gui.relative.memory_unit_gui
		if gui then gui.destroy() end
	end
end)

--- Creates the GUI on click
script.on_event(defines.events.on_gui_opened, function(event)                
	if event.gui_type ~= defines.gui_type.entity or not event.entity or event.entity.name ~= 'memory-unit' then return end
	
	---@type LuaPlayer
	---@diagnostic disable-next-line: assign-type-mismatch
	local player = game.get_player(event.player_index)
	local entity = event.entity
	shared.open_inventory(player)

	local main_frame = player.gui.relative.add{
		type = 'frame', name = 'memory_unit_gui', caption = {'entity-name.memory-unit'}, direction = 'vertical',
		anchor = {
			gui = defines.relative_gui_type.item_with_inventory_gui,
			position = defines.relative_gui_position.right
		}
	}
	main_frame.style.width = 448
	main_frame.tags = {unit_number = entity.unit_number}
	local main_flow = main_frame.add{type="flow",name="main_flow",direction="vertical"}
	main_flow.style.vertical_spacing = 12
	main_flow.style.vertically_stretchable = false
	
	local controller_frame = main_flow.add{type = 'frame', name = 'content_frame', direction = 'vertical', style = 'inside_shallow_frame'}

	local controller_header = controller_frame.add{type="frame",name="controller_header", style = "subheader_frame"}
	controller_header.style.horizontally_stretchable = true
	controller_header.add{type="label",name="controller_header_label",style="subheader_caption_label",caption={"mod-gui.unit-controller-caption"}}

	local controller_flow = controller_frame.add{type = 'flow', name = 'content_flow', direction = 'vertical'}
	controller_flow.style.vertical_spacing = 8
	controller_flow.style.margin = {-4, 0, -4, 0}
	controller_flow.style.vertical_align = 'center'
	controller_flow.style.padding = 12
	
	--[[
		local electric_flow = content_flow.add{type = 'flow', name = 'electric_flow', direction = 'horizontal'}
		electric_flow.style.vertical_align = 'center'
		electric_flow.style.horizontal_align = 'right'
		electric_flow.style.width = 400
		electric_flow.style.bottom_margin = -32
		electric_flow.add{type = 'label', name = 'consumption'}.style.right_margin = 4
		electric_flow.add{type = 'progressbar', name = 'electricity', style = 'electric_satisfaction_progressbar'}.style.width = 150
	]]

	--[[local status_flow = content_flow.add{type = 'flow', name = 'status_flow', direction = 'horizontal'}
	status_flow.style.vertical_align = 'center'
	status_flow.style.top_margin = 4
	local status_sprite = status_flow.add{type = 'sprite', name = 'status_sprite'}
	status_sprite.resize_to_sprite = false
	status_sprite.style.size = {16, 16}
	local status_text = status_flow.add{type = 'label', name = 'status_text'}]]

	
	local entity_preview = controller_flow.add{type = 'entity-preview', name = 'entity_preview', style = 'mu_entity_preview'}
	entity_preview.entity = entity
	entity_preview.visible = true
	entity_preview.style.height = 155
	

	local storage_flow = controller_flow.add{type = 'flow', name = 'storage_flow', direction = 'horizontal'}
	storage_flow.style.vertical_align = 'center'
	storage_flow.style.horizontal_spacing = 18
	
	local io_flow = storage_flow.add{type = 'flow', name = 'io_flow', direction = 'horizontal'}
	storage_flow.style.vertical_align = 'center'         
	local bulk_insert = io_flow.add{type = 'sprite-button', name = 'bulk_insert', style = 'inventory_slot', sprite = 'bulk-insert', tooltip = {'mod-gui.bulk-insert'}}
	bulk_insert.tags = {unit_number = entity.unit_number}
	local bulk_extract = io_flow.add{type = 'sprite-button', name = 'bulk_extract', style = 'inventory_slot', sprite = 'bulk-extract', tooltip = {'mod-gui.bulk-extract'}}
	bulk_extract.tags = {unit_number = entity.unit_number}
	
	local info_flow = storage_flow.add{type='flow',name='info_flow',direction='horizontal'}
	info_flow.style.horizontal_spacing = 6

	local content_sprite = info_flow.add{type = 'sprite', name = 'content_sprite'}
	content_sprite.resize_to_sprite = false
	content_sprite.style.size = {32, 32}
	info_flow.add{type = 'label', name = 'current_storage'}
	
	local no_input_item = controller_flow.add{type = 'sprite-button', name = 'no_input_item', style = 'inventory_slot', tooltip = {'mod-gui.no-input-item'}}
	no_input_item.tags = {unit_number = entity.unit_number}

	local memory_frame = main_flow.add{type = 'frame', name = 'memory_frame', direction = 'vertical', style = 'inside_shallow_frame'}
	local memory_header = memory_frame.add{type="frame",name="memory_header", style = "subheader_frame"}
	memory_header.style.horizontally_stretchable = true
	local memory_header_flow = memory_header.add{type="flow",name="memory_header_flow"}
	memory_header_flow.add{type="label",name="memory_header_label",style="subheader_caption_label",tooltip={"mod-gui.memory-tab-tooltip"}, caption = {"mod-gui.memory-tab-caption"}}
	memory_header_flow.add{type="label",name="memory_header_tier_label",style="subheader_caption_label"}

	local memory_status_flow = memory_frame.add{type="flow",name="memory_status_flow",direction="horizontal"}
	memory_status_flow.style.vertical_align = "center"
	memory_status_flow.style.top_margin = 6
	memory_status_flow.style.left_padding = 12
	memory_status_flow.add{type="sprite",name="memory_status_sprite"}
	memory_status_flow.add{type="label",name="memory_status_label"}

	local memory_electricity_flow = memory_status_flow.add{type="flow",name="memory_electricity_flow"}
	memory_electricity_flow.style.right_padding = 12
	memory_electricity_flow.style.bottom_margin = 6
	memory_electricity_flow.style.horizontally_stretchable = true
	memory_electricity_flow.style.horizontal_align = "right"
	memory_electricity_flow.style.vertical_align = "center"
	memory_electricity_flow.add{type="label",name="memory_electricity_label"}.style.right_margin = 4
	--memory_electricity_flow.add{type="progressbar",name="memory_electricity",style="electric_satisfaction_progressbar"}.style.width = 100

	local memory_containment_flow = memory_frame.add{type="flow",name="memory_containment_flow"}
	memory_containment_flow.style.right_padding = 12
	memory_containment_flow.style.bottom_margin = 6
	memory_containment_flow.style.horizontally_stretchable = true
	memory_containment_flow.style.vertical_align = "center"
	memory_containment_flow.style.horizontal_align = "right"
	memory_containment_flow.add{type="label",name="memory_containment_label",caption="Containment field"}.style.right_margin = 4
	memory_containment_flow.add{type="progressbar",name="memory_containment_strength",style="electric_satisfaction_progressbar"}.style.width = 250


	local mc_frame = main_flow.add{type = 'frame', name = 'mc_frame', direction = 'vertical', style = 'inside_shallow_frame'}
	local mc_header = mc_frame.add{type="frame",name="mc_header", style = "subheader_frame"}
	mc_header.style.horizontally_stretchable = true
	local mc_header_flow = mc_header.add{type="flow",name="mc_header_flow"}
	mc_header_flow.add{type="label",name="mc_header_label",style="subheader_caption_label",caption={"mod-gui.matter-tab-caption"},tooltip={"mod-gui.matter-tab-tooltip"}}
	mc_header_flow.add{type="label",name="mc_header_tier_label",style="subheader_caption_label"}

	local mc_status_flow = mc_frame.add{type="flow",name="mc_status_flow",direction="horizontal"}
	mc_status_flow.style.vertical_align = "center"
	mc_status_flow.style.top_margin = 6
	mc_status_flow.style.left_padding = 12
	mc_status_flow.add{type="sprite",name="mc_status_sprite",sprite="utility/status_working"}
	mc_status_flow.add{type="label",name="mc_status_label"}.style.right_margin = 8

	local mc_info_flow = mc_status_flow.add{type="flow",name="mc_info_flow",direction="horizontal"}
	mc_info_flow.style.right_padding = 12
	mc_info_flow.style.bottom_margin = 6
	mc_info_flow.style.horizontally_stretchable = true
	mc_info_flow.style.vertical_align = "center"
	mc_info_flow.style.horizontal_align = "right"
	mc_info_flow.add{type="label",name="mc_info_label"}

	local mc_info_flow = mc_frame.add{type="flow",name="mc_info_flow",direction="horizontal"}
	mc_info_flow.style.right_padding = 12
	mc_info_flow.style.bottom_margin = 6
	mc_info_flow.style.vertical_align = "center"
	mc_info_flow.style.horizontal_align = "right"
	mc_info_flow.style.horizontally_stretchable = true
	mc_info_flow.add{type="label",name="matter_buffer_label", caption = {"mod-gui.matter-tab-bar-caption"}}.style.right_margin = 4
	mc_info_flow.add{type="progressbar",name="matter_buffer",style="mu_io_buffer_filled"}.style.width = 250

	update_gui(main_frame, true)
	
end)

script.on_event(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if event.gui_type == defines.gui_type.item then
		local gui = player.gui.relative.memory_unit_gui
		if gui then gui.destroy() end
	end
end)

local function bulk_io(event, element)
	local player = game.get_player(event.player_index)
	local inventory = player.get_main_inventory()
	local unit_data = global.units[element.tags.unit_number]
	local item = unit_data.item
	if not item then return end
	
	local count = (event.button == defines.mouse_button_type.right) and unit_data.stack_size * #inventory or unit_data.stack_size
	if element.name == 'bulk_insert' then -- insert
		local amount_removed = inventory.remove{name = item, count = count}
		unit_data.count = unit_data.count + amount_removed
	elseif element.name == 'bulk_extract' then -- extract
		local unit_inventory = unit_data.inventory
		local inventory_count = unit_inventory.get_item_count(item)
			
		if inventory_count + unit_data.count < count then -- not enough items are in storage
			count = inventory_count + unit_data.count
		end
		
		if count == 0 then return end
		
		local amount_inserted = inventory.insert{name = item, count = count}
		unit_data.count = unit_data.count - amount_inserted
		if unit_data.count < 0 then
			unit_inventory.remove{name = item, count = -unit_data.count}
			unit_data.count = 0
		end
	end
	
	update_unit(unit_data, element.tags.unit_number, true)
end

local function prime_unit(event, element)
	local player = game.get_player(event.player_index)
	local stack = player.cursor_stack
	if not stack.valid_for_read or not shared.check_for_basic_item(stack.name) then return end
	local unit_data = global.units[element.tags.unit_number]
	
	unit_data.count = stack.count
	unit_data.item = stack.name
	unit_data.stack_size = stack.prototype.stack_size
	unit_data.comfortable = unit_data.stack_size * #unit_data.inventory / 2
	set_filter(unit_data)
	update_inventory_limits(unit_data)
	stack.clear()
	
	update_unit(unit_data, element.tags.unit_number, true)
	update_gui(player.gui.relative.memory_unit_gui)
end

script.on_event(defines.events.on_gui_click, function(event)
	local element = event.element
	if not element.tags or not element.tags.unit_number then return end
	if element.name == 'bulk_insert' or element.name == 'bulk_extract' then
		bulk_io(event, element)
	elseif element.name == 'no_input_item' then
		prime_unit(event, element)
	end
end)
