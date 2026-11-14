---@type JobData
return {
    label = 'Vineyard',
    description = 'Pick grapes at Marlowe Vineyards, press them into juice and cask it as wine.',
    icon = 'plant',
    kind = 'gather',
    doneLabel = 'Tasks done',
    goods = 'Grapes and wine',
    crewSize = 4,
    site = {
        label = 'Marlowe Vineyards',
        coords = vec4(-1886.62, 2085.86, 140.0, 183.7),
        ped = 'a_m_m_farmer_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 93, color = 27 },
    },
    -- Dollars the site pays for each item
    prices = { grapes = 2, grape_juice = 8, wine = 11 },
    -- Steps from vine to cask
    groups = {
        {
            label = 'Vine row',
            zone = true, -- the player works an area at each point instead of a spawned prop
            marker = true, -- draws a marker on the ground at each point
            guide = true, -- puts a blip on the nearest ready point
            radius = 1.5, -- meters from a point the player can work it
            cooldown = 60000, -- milliseconds a worked point rests before it can be worked again; 0 never rests
            amount = { 2, 4 }, -- items per action, picked between the two
            action = {
                label = 'Picking grapes', -- progress bar text
                prompt = 'Pick grapes', -- target option text
                duration = { 4500, 6000 }, -- milliseconds, or { shortest, longest } picked between
                anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
                prop = { model = 'prop_grapes_01', bone = 18905, pos = vec3(0.12, 0.03, 0.0), rot = vec3(0.0, 0.0, 0.0) }, -- prop held in the hand: model, ped bone, and position and rotation on the bone
            },
            yields = { { name = 'grapes', weight = 1 } }, -- item each action gives
            points = {
                { coords = vec3(-1865.94, 2100.95, 136.73), heading = 55.4 },
                { coords = vec3(-1846.86, 2083.95, 138.20), heading = 30.0 },
                { coords = vec3(-1875.26, 2110.35, 134.86), heading = 49.5 },
                { coords = vec3(-1859.61, 2110.23, 133.61), heading = 55.4 },
                { coords = vec3(-1836.51, 2089.94, 136.72), heading = 30.0 },
                { coords = vec3(-1878.06, 2119.34, 131.66), heading = 49.0 },
                { coords = vec3(-1851.86, 2119.22, 129.65), heading = 49.2 },
                { coords = vec3(-1825.38, 2096.59, 135.71), heading = 30.9 },
                { coords = vec3(-1845.59, 2127.68, 126.76), heading = 53.5 },
                { coords = vec3(-1839.64, 2125.55, 126.31), heading = 24.3 },
                { coords = vec3(-1815.03, 2103.04, 135.00), heading = 31.9 },
                { coords = vec3(-1827.69, 2130.94, 124.62), heading = 24.3 },
                { coords = vec3(-1873.04, 2100.25, 138.74), heading = 100.5 },
                { coords = vec3(-1880.27, 2100.44, 139.08), heading = 104.79 },
                { coords = vec3(-1874.05, 2104.55, 137.53), heading = 120.65 },
                { coords = vec3(-1884.88, 2105.28, 137.15), heading = 91.16 },
                { coords = vec3(-1894.88, 2106.24, 135.51), heading = 106.17 },
                { coords = vec3(-1908.95, 2107.52, 131.23), heading = 94.0 },
                { coords = vec3(-1908.3, 2111.69, 129.58), heading = 238.25 },
                { coords = vec3(-1899.23, 2111.05, 132.5), heading = 248.71 },
                { coords = vec3(-1888.47, 2110.25, 135.17), heading = 266.98 },
                { coords = vec3(-1868.16, 2114.02, 133.96), heading = 82.9 },
                { coords = vec3(-1878.0, 2114.86, 134.31), heading = 84.49 },
                { coords = vec3(-1891.36, 2116.01, 132.42), heading = 85.6 },
                { coords = vec3(-1904.48, 2117.4, 128.55), heading = 83.16 },
                { coords = vec3(-1905.83, 2121.98, 126.23), heading = 256.02 },
                { coords = vec3(-1889.96, 2120.52, 130.92), heading = 263.78 },
            },
        },
        {
            label = 'Grape press',
            prop = 'prop_wooden_barrel', -- prop model spawned at each point
            marker = true, -- draws a marker on the ground at each point
            radius = 1.5, -- meters from a point the player can work it
            cooldown = 0, -- milliseconds a worked point rests before it can be worked again; 0 never rests
            amount = { 1, 1 }, -- items per action, picked between the two
            consumes = { name = 'grapes', amount = 3, label = 'grapes' }, -- item used up per action
            action = {
                label = 'Pressing grapes', -- progress bar text
                prompt = 'Press 3 grapes', -- target option text
                duration = { 6000, 8000 }, -- milliseconds, or { shortest, longest } picked between
                anim = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d', flag = 1 },
            },
            yields = { { name = 'grape_juice', weight = 1 } }, -- item each action gives
            points = {
                { coords = vec3(-1852.25, 2061.99, 140.03), heading = 266.0 },
            },
        },
        {
            label = 'Wine cask',
            prop = 'prop_wooden_barrel', -- prop model spawned at each point
            marker = true, -- draws a marker on the ground at each point
            radius = 1.5, -- meters from a point the player can work it
            cooldown = 0, -- milliseconds a worked point rests before it can be worked again; 0 never rests
            amount = { 1, 1 }, -- items per action, picked between the two
            consumes = { name = 'grape_juice', amount = 1, label = 'grape juice' }, -- item used up per action
            action = {
                label = 'Casking the wine', -- progress bar text
                prompt = 'Cask the juice', -- target option text
                duration = { 6000, 8000 }, -- milliseconds, or { shortest, longest } picked between
                anim = { dict = 'amb@prop_human_parking_meter@male@base', clip = 'base', flag = 1 },
            },
            yields = { { name = 'wine', weight = 1 } }, -- item each action gives
            points = {
                { coords = vec3(-1909.54, 2086.00, 139.38), heading = 308.3 },
            },
        },
    },
}
