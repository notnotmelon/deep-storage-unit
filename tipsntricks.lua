data:extend{{
    type = 'tips-and-tricks-item',
    name = 'main',
    tag = '[item=memory-unit]',
    category = 'memory-unit',
    trigger = {
        type = 'research',
        technology = 'memory-unit'
    },
    indent = 0,
    starting_status = 'locked',
    image = '__deep-storage-unit__/graphics/entity/hr-memory-unit.png',
    is_title = true,
    order="a"
},{
    name = 'moduling',
    tag = '[item=beacon]',
    type = 'tips-and-tricks-item',
    category = 'memory-unit',
    dependencies = {"main"},
    indent = 1,
    starting_status = 'locked',
    order='b'
},{
    name = 'containment',
    tag = '[item=energy-shield-equipment]',
    type = 'tips-and-tricks-item',
    category = 'memory-unit',
    dependencies = {"main"},
    indent = 1,
    starting_status = 'locked',
    order='c'
},{
    name = 'logic',
    tag = '[item=red-wire]',
    type = 'tips-and-tricks-item',
    category = 'memory-unit',
    dependencies = {"main"},
    indent = 1,
    starting_status = 'locked',
    order='d'
}}