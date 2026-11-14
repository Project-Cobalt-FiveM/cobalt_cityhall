return {
    -- City Hall desk where players pick up jobs, ID cards and licences
    center = {
        label = 'City Hall', -- blip and prompt name
        coords = vec4(-262.79, -964.18, 31.22, 181.71), -- clerk position and heading
        ped = 'a_f_y_business_02', -- clerk model
        blip = { sprite = 487, color = 3 }, -- map blip sprite and colour ids
    },

    -- Civilian jobs offered at the desk, in menu order; each id is a file in data/
    jobs = { 'taxi', 'trucking', 'sanitation', 'construction', 'fishing', 'mining', 'farming', 'recycling', 'vineyard', 'hotdog' },
    -- General
    payAccount = 'bank', -- money account job pay goes into: 'bank' or 'cash'
    interactRange = 4.0, -- meters from the clerk to use the desk

    -- Crews: players who work a job together
    crew = {
        bonus = 0.15, -- extra pay on shared work (routes, bins, taxi fares) when two or more crew members did it, as a fraction (0.15 is 15 percent); the pay is split between them
        inviteRange = 10.0, -- meters within which a player can be invited
        inviteSeconds = 30, -- seconds an invite stays open
        shareRange = 50.0, -- meters from the work a crew member must be to share its progress
    },

    -- Rank that can use the admin commands: 'staff', 'admin' or 'owner'
    adminRank = 'admin',

    -- Cards sold at the desk; each item must exist in cobalt_inventory data/items.lua
    cards = {
        id = { label = 'ID card', item = 'id_card', price = 50 }, -- price in dollars
        licences = { -- keys match licences in cobalt_core config/shared.lua; sold only to holders of that licence
            driver = { item = 'driver_license', price = 150 },
            weapon = { item = 'weapon_license', price = 500 },
        },
    },

    -- Driving school: a theory quiz, then a practical road test
    dmv = {
        label = 'DMV', -- blip and prompt name
        coords = vec4(218.02, -1391.42, 30.59, 316.55), -- instructor position and heading
        ped = 'a_m_y_business_03', -- instructor model
        blip = { sprite = 225, color = 3 }, -- map blip sprite and colour ids
        returnPoint = vec4(219.05, -1390.33, 30.59, 136.55), -- where the player is put back after the road test
        theory = {
            fee = 250, -- dollars to sit the quiz
            passMark = 4, -- correct answers needed to pass
        },
        practical = {
            fee = 0, -- dollars for the first road test
            retakeFee = 100, -- dollars for each retake
            retakeCooldown = 600, -- seconds before a failed test can be retaken
            model = 'panto', -- test car model
            plate = 'DMV', -- test car plate
            spawn = vec4(249.41, -1407.23, 30.41, 318.0), -- where the test car spawns
            unit = 'mph', -- speed limit unit: 'mph' or 'kmh'
            tolerance = 3, -- speed over the limit allowed before a strike, in unit
            maxStrikes = 3, -- strikes that fail the test
            strikeCooldown = 5, -- seconds between two strikes of the same kind
            crashDamage = 25, -- body damage in one hit that counts as a crash strike
            leaveSeconds = 20, -- seconds the player may be out of the car before failing
            checkpointRadius = 7.0, -- meters from a checkpoint that count as reaching it
            route = { -- checkpoints in order; limit is the speed limit up to that checkpoint
                { coords = vec3(255.14, -1400.73, 29.54), limit = 25 },
                { coords = vec3(271.87, -1370.57, 30.93), limit = 30 },
                { coords = vec3(234.91, -1345.39, 29.54), limit = 30 },
                { coords = vec3(217.82, -1410.52, 28.29), limit = 30 },
                { coords = vec3(178.55, -1401.76, 27.73), limit = 30 },
                { coords = vec3(113.16, -1365.28, 27.73), limit = 40 },
                { coords = vec3(-73.54, -1364.34, 27.79), limit = 40 },
                { coords = vec3(113.16, -1365.28, 27.73), limit = 40 },
                { coords = vec3(178.55, -1401.76, 27.73), limit = 30 },
                { coords = vec3(235.28, -1398.33, 28.92), limit = 20 },
            },
        },
    },
}
