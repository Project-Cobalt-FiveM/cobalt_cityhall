---@type JobData
return {
    label = 'Fishing',
    description = 'Fish off Del Perro Pier and sell your catch at the fish market.',
    icon = 'fish',
    kind = 'gather',
    doneLabel = 'Catches',
    goods = 'Fish',
    crewSize = 4,
    -- The fish market at the end of the pier: the chef sells gear and buys fish
    site = {
        label = 'Fish market',
        coords = vec4(-1845.0, -1215.0, 12.02, 304.0),
        ped = 's_m_y_chef_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 68, color = 3 },
    },
    -- Dollars the chef pays for each fish
    prices = { mackerel = 12, bass = 20, salmon = 35 },
    -- What the chef sells: item, how many come in one purchase, and the price in dollars (cash, then bank)
    gear = {
        { name = 'fishingrod', label = 'Fishing rod', amount = 1, price = 150 },
        { name = 'fish_bait', label = 'Fish bait', amount = 10, price = 25 },
    },
    groups = {
        {
            label = 'Fishing spot',
            zone = true,
            cooldown = 0,
            amount = { 1, 1 },
            requires = { name = 'fishingrod', amount = 1, label = 'fishing rod' }, -- kept, never used up
            consumes = { name = 'fish_bait', amount = 1, label = 'fish bait' }, -- one bait per cast
            action = {
                label = 'Fishing',
                prompt = 'Cast a line',
                duration = { 8000, 15000 },
                anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_a', flag = 1 },
                prop = { model = 'prop_fishing_rod_01', bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
            },
            -- Chance of each fish, as weights out of the total
            yields = {
                { name = 'mackerel', weight = 50 },
                { name = 'bass', weight = 35 },
                { name = 'salmon', weight = 15 },
            },
            points = {
                { label = 'End of Del Perro Pier', coords = vec3(-1828.0, -1245.0, 13.0), radius = 8.0 },
            },
        },
    },
}
