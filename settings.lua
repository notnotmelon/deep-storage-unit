data:extend{
	{
		type = 'string-setting',
		name = 'memory-unit-power-usage',
		setting_type = 'runtime-global',
		default_value = '300kW',
		allowed_values = {'0W', '60kW', '180kW', '300kW', '480kW', '600kW', '1.2MW', '2.4MW'}
	},
	{
		type = 'int-setting',
		name = 'memory-unit-se-fox-containment-field',
		setting_type = 'runtime-global',
		default_value = 120,
		minimum_value = 60
	},
	{
		type = 'double-setting',
		name = 'memory-unit-se-fox-item-loss',
		setting_type = 'runtime-global',
		default_value = 0.001,
		minimum_value = 0,
		maximum_value = 1
	}
}
