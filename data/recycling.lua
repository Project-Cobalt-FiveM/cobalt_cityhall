---@type JobData
return {
    label = locale('recycling.label'),
    description = locale('recycling.description'),
    icon = 'recycle',
    kind = 'gather',
    doneLabel = locale('recycling.done'),
    goods = locale('recycling.goods'),
    crewSize = 4,
    site = {
        label = locale('recycling.site'),
        coords = vec4(739.66, -1376.61, 12.5, 272.72),
        ped = 's_m_y_construct_02',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 365, color = 25, coords = vec3(750.18, -1401.9, 26.54) },
    },
    -- Warehouse door: where the player stands outside and inside, each with a heading
    entrance = {
        outside = vec4(746.82, -1398.93, 25.55, 181.16),
        inside = vec4(736.95, -1374.25, 12.63, 266.58),
    },
    -- Dollars the buyer pays for each material
    prices = { plastic = 9, aluminum = 12, cardboard = 6, glass_shards = 8, rubber_scrap = 10, iron = 14, copper = 18 },
    sell = locale('recycling.sell'), -- the laptop's option that sells every material in prices at once
    -- The laptop on the office desk where workers sell their materials, in place of the foreman
    sellPoint = {
        coords = vec3(739.55, -1376.5, 12.14), -- the laptop's position
        radius = 2.0, -- meters from the laptop the player can use it
        label = locale('recycling.selling'), -- progress bar text while the sale goes through
        duration = 3000, -- milliseconds at the laptop before the sale goes through
        anim = { dict = 'anim@heists@prison_heiststation@cop_reactions', clip = 'cop_b_idle', flag = 1 }, -- typing on the laptop
    },
    -- Things to work in the warehouse
    groups = {
        {
            label = locale('recycling.crate'),
            props = { 'prop_boxpile_01a', 'prop_boxpile_02b', 'prop_boxpile_04a', 'prop_boxpile_05a', 'prop_boxpile_06b' }, -- crate models spawned at the points, one per point in turn
            radius = 1.5, -- meters from a point the player can work it
            cooldown = 45000, -- milliseconds a worked point rests before it can be worked again; 0 never rests
            amount = { 1, 1 }, -- items per action, picked between the two
            action = {
                label = locale('recycling.searching'), -- progress bar text
                prompt = locale('recycling.search'), -- target option text
                duration = 5000, -- milliseconds, or { shortest, longest } picked between
                anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 }, -- kneeling loop played while searching
            },
            -- Chance of each material, as weights out of the total; amount is the count range for that material
            yields = {
                { name = 'plastic', weight = 22, amount = { 3, 6 } },
                { name = 'aluminum', weight = 20, amount = { 3, 6 } },
                { name = 'cardboard', weight = 18, amount = { 2, 5 } },
                { name = 'glass_shards', weight = 16, amount = { 2, 4 } },
                { name = 'rubber_scrap', weight = 10, amount = { 2, 4 } },
                { name = 'iron', weight = 8, amount = { 1, 3 } },
                { name = 'copper', weight = 6, amount = { 1, 3 } },
            },
            -- Where the crates sit, with the heading the crate faces
            points = {
                { coords = vec3(748.01, -1368.06, 13.80), heading = 0.0 },
                { coords = vec3(750.44, -1368.08, 13.80), heading = 0.0 },
                { coords = vec3(752.81, -1368.07, 13.80), heading = 0.0 },
                { coords = vec3(755.25, -1367.98, 13.80), heading = 0.0 },
                { coords = vec3(757.68, -1368.05, 13.80), heading = 0.0 },
                { coords = vec3(760.04, -1368.12, 13.80), heading = 0.0 },
                { coords = vec3(762.48, -1367.97, 13.80), heading = 0.0 },
                { coords = vec3(771.20, -1368.09, 13.80), heading = -90.0 },
                { coords = vec3(771.23, -1370.57, 13.80), heading = -90.0 },
                { coords = vec3(771.24, -1372.94, 13.80), heading = -90.0 },
                { coords = vec3(771.32, -1383.10, 13.80), heading = -90.0 },
                { coords = vec3(771.31, -1385.54, 13.80), heading = -90.0 },
                { coords = vec3(771.136, -1387.91, 13.80), heading = -90.0 },
                { coords = vec3(748.03, -1373.44, 13.80), heading = 90.0 },
                { coords = vec3(750.42, -1373.42, 13.80), heading = 90.0 },
                { coords = vec3(752.90, -1373.42, 13.80), heading = 90.0 },
                { coords = vec3(755.28, -1373.42, 13.80), heading = 90.0 },
                { coords = vec3(757.66, -1373.43, 13.80), heading = 90.0 },
                { coords = vec3(760.08, -1373.40, 13.80), heading = 90.0 },
                { coords = vec3(762.49, -1373.47, 13.80), heading = 90.0 },
                { coords = vec3(748.02, -1379.29, 13.80), heading = 90.0 },
                { coords = vec3(750.451, -1379.24, 13.80), heading = 0.0 },
                { coords = vec3(752.83, -1379.26, 13.80), heading = 0.0 },
                { coords = vec3(755.21, -1379.29, 13.80), heading = 0.0 },
                { coords = vec3(757.65, -1379.25, 13.80), heading = 0.0 },
                { coords = vec3(760.07, -1379.27, 13.80), heading = 0.0 },
                { coords = vec3(762.54, -1379.20, 13.80), heading = 0.0 },
                { coords = vec3(747.98, -1384.97, 13.80), heading = 0.0 },
                { coords = vec3(750.42, -1384.87, 13.80), heading = 0.0 },
                { coords = vec3(752.81, -1385.01, 13.80), heading = 0.0 },
                { coords = vec3(755.25, -1384.99, 13.80), heading = 0.0 },
                { coords = vec3(757.65, -1384.96, 13.80), heading = 0.0 },
                { coords = vec3(760.05, -1384.80, 13.80), heading = 0.0 },
                { coords = vec3(762.55, -1384.95, 13.80), heading = 0.0 },
                { coords = vec3(737.57, -1383.00, 13.80), heading = 90.0 },
                { coords = vec3(737.55, -1385.40, 13.80), heading = 90.0 },
                { coords = vec3(737.56, -1387.86, 13.80), heading = 90.0 },
            },
        },
    },
}
