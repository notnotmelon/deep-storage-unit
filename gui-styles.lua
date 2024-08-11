local styles = data.raw['gui-style'].default
local mod_prefix = 'mu_'

styles[mod_prefix .. 'entity_preview'] = {
	type = 'empty_widget_style',
	vertically_stretchable = 'on',
	horizontally_stretchable = 'on',
	padding = 0,
	graphical_set = {
		base = {
			position = {17, 0}, corner_size = 8,
			center = {position = {76, 8}, size = {1, 1}},
			draw_type = 'outer'
		},
		shadow = default_inner_shadow
	}
}

styles[mod_prefix .. 'io_buffer_filled'] = {
	type="progressbar_style",
	color = {218, 69, 53},
	other_colors =
	{
		{less_than = 0.125, color = {218, 69, 53}},
		{less_than = 0.25, color = {219, 176, 22}},
		{less_than = 0.75, color = {43, 227, 39}},
		{less_than = 0.875, color = {219, 176, 22}},
	}
}