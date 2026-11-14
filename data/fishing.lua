---@type JobData
return {
    label = locale('fishing.label'),
    description = locale('fishing.description'),
    icon = 'fish',
    kind = 'gather',
    doneLabel = locale('fishing.done'),
    goods = locale('fishing.goods'),
    crewSize = 4,
    -- The fish market at the end of the pier: the chef sells gear and buys fish
    site = {
        label = locale('fishing.site'),
        coords = vec4(-1845.0, -1215.0, 12.02, 304.0),
        ped = 's_m_y_chef_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 68, color = 3 },
    },
    -- Dollars the chef pays for each fish
    prices = { mackerel = 12, bass = 20, salmon = 35 },
    -- What the chef sells: item, how many come in one purchase, and the price in dollars (cash, then bank)
    gear = {
        { name = 'fishingrod', label = locale('fishing.rod'), amount = 1, price = 150 },
        { name = 'fish_bait', label = locale('fishing.bait'), amount = 10, price = 25 },
    },
    groups = {
        {
            label = locale('fishing.spot'),
            zone = true,
            cooldown = 0,
            amount = { 1, 1 },
            requires = { name = 'fishingrod', amount = 1, label = locale('fishing.rod_needed') }, -- kept, never used up
            consumes = { name = 'fish_bait', amount = 1, label = locale('fishing.bait_needed') }, -- one bait per fish landed; a fish that gets away keeps the bait on the hook
            action = {
                label = locale('fishing.reeling'), -- progress bar text
                prompt = locale('fishing.cast'), -- prompt text
                duration = { 5000, 8000 }, -- milliseconds the reel takes, picked between the two
                skillCheck = { difficulty = { 'easy', 'medium' }, failed = locale('fishing.got_away') }, -- hooking the fish: one round per difficulty ('easy', 'medium' or 'hard'), and the text shown on a miss
                anim = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_a', flag = 1 }, -- animation held from the cast until the fish is in
                prop = { model = 'prop_fishing_rod_01', bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) }, -- rod held in the hand: model, ped bone, and position and rotation on the bone
            },
            -- Chance of each fish, as weights out of the total
            yields = {
                { name = 'mackerel', weight = 50 },
                { name = 'bass', weight = 35 },
                { name = 'salmon', weight = 15 },
            },
            points = {
                { label = locale('fishing.pier_end'), coords = vec3(-1828.0, -1245.0, 13.0), radius = 8.0 },
            },
        },
    },
}
