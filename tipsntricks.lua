data:extend { {
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
    image = '__deep-storage-unit-se-fox__/graphics/entity/hr-memory-unit.png',
    is_title = true,
    order = "a"
} --[[@as data.TipsAndTricksItem]], {
    name = 'moduling',
    tag = '[item=beacon]',
    type = 'tips-and-tricks-item',
    category = 'memory-unit',
    dependencies = { "main" },
    indent = 1,
    starting_status = 'locked',
    order = 'b'
} --[[@as data.TipsAndTricksItem]], {
    name = 'containment',
    tag = '[item=energy-shield-equipment]',
    type = 'tips-and-tricks-item',
    category = 'memory-unit',
    dependencies = { "main" },
    indent = 1,
    starting_status = 'locked',
    order = 'c'
} --[[@as data.TipsAndTricksItem]], {
    name = 'logic',
    tag = '[item=red-wire]',
    type = 'tips-and-tricks-item',
    category = 'memory-unit',
    dependencies = { "main" },
    indent = 1,
    starting_status = 'locked',
    order = 'd'
} --[[@as data.TipsAndTricksItem]] }
