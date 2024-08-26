data:extend{
	{
		type = 'double-setting',
		name = 'memory-unit-se-power-usage',
		setting_type = 'runtime-global',
		default_value = 1
	},
	{
		type = 'int-setting',
		name = 'memory-unit-se-containment-field',
		setting_type = 'runtime-global',
		default_value = 120,
		minimum_value = 60
	},
	{
		type = 'double-setting',
		name = 'memory-unit-se-item-loss',
		setting_type = 'runtime-global',
		default_value = 0.001,
		minimum_value = 0,
		maximum_value = 1
	}
}
