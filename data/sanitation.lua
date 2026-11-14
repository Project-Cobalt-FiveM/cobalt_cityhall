---@type JobData
return {
    label = 'Sanitation',
    description = 'Clear the bins in three neighbourhoods into the garbage truck.',
    icon = 'trash',
    kind = 'collect',
    doneLabel = 'Bags collected',
    crewSize = 4,
    site = {
        label = 'Cypress Flats Sanitation Yard',
        coords = vec4(-322.25, -1545.87, 30.0, 267.96),
        ped = 's_m_y_garbage',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 318, color = 25 },
    },
    vehicle = {
        label = 'garbage truck',
        model = 'trash',
        plate = 'CLEAN',
        spawns = {
            vec4(-326.95, -1524.44, 27.75, 268.4),
            vec4(-327.12, -1530.44, 27.75, 268.4),
            vec4(-326.78, -1518.44, 27.75, 268.4),
        },
    },
    -- Bin route
    collect = {
        length = 3, -- areas per route
        bins = 6, -- bins to empty in each area
        truckWithin = 40.0, -- meters the garbage truck must be from a bin to empty it
        pay = { perBin = 45, routeBonus = 200 }, -- dollars per bin in a cleared area (a zone's own pay replaces it), plus dollars per finished route
        models = { -- bin and dumpster models that can be emptied
            'prop_dumpster_01a',
            'prop_dumpster_02a',
            'prop_dumpster_02b',
            'prop_dumpster_3a',
            'prop_dumpster_4a',
            'prop_dumpster_4b',
            'prop_bin_01a',
            'prop_bin_05a',
            'prop_bin_07a',
            'prop_bin_07b',
            'prop_bin_07c',
            'prop_bin_08a',
            'prop_bin_08open',
            'prop_cs_bin_01',
            'prop_cs_bin_02',
            'prop_cs_bin_03',
            'prop_recyclebin_01a',
            'prop_recyclebin_02_c',
            'prop_recyclebin_03_a',
        },
        -- Emptying a bin into a bag
        empty = {
            label = 'Bagging the trash', -- progress bar text
            prompt = 'Empty the bin', -- target option text
            duration = 4000, -- milliseconds
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
        },
        -- Opening the back of the truck
        open = {
            label = 'Opening the back', -- progress bar text
            prompt = 'Open the back', -- target option text
            duration = 1500, -- milliseconds
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
        },
        -- Throwing the bag into the truck
        throw = {
            label = 'Throwing the bag in', -- progress bar text
            prompt = 'Throw the bag in', -- target option text
            duration = 1500, -- milliseconds
            anim = { dict = 'missfbi4prepp1', clip = '_bag_throw_garbage_man', flag = 48 },
        },
        -- Trash bag prop held in the hand: model, ped bone, and position and rotation on the bone
        bag = {
            model = 'prop_cs_rub_binbag_01',
            bone = 57005,
            pos = vec3(0.12, 0.0, -0.05),
            rot = vec3(220.0, 120.0, 0.0),
        },
        -- Areas a route picks from: name, centre and radius in meters
        zones = {
            { label = 'Little Seoul', coords = vec3(-668.0, -884.0, 24.0), radius = 90.0 },
            { label = 'Mission Row', coords = vec3(415.0, -1037.0, 29.0), radius = 90.0 },
            { label = 'Strawberry', coords = vec3(170.0, -1290.0, 29.0), radius = 90.0 },
            { label = 'Davis', coords = vec3(100.0, -1908.0, 21.0), radius = 90.0 },
            { label = 'Rancho', coords = vec3(400.0, -1830.0, 28.0), radius = 90.0 },
            { label = 'La Mesa', coords = vec3(780.0, -1040.0, 26.0), radius = 90.0 },
            { label = 'Legion Square', coords = vec3(180.0, -930.0, 30.0), radius = 90.0 },
            { label = 'La Puerta', coords = vec3(-1100.0, -1500.0, 4.5), radius = 90.0 },
            { label = 'Del Perro', coords = vec3(-1360.0, -700.0, 24.0), radius = 90.0 },
            { label = 'Rockford Hills', coords = vec3(-555.0, -195.0, 38.0), radius = 90.0 },
            { label = 'Downtown Vinewood', coords = vec3(285.0, 188.0, 104.0), radius = 90.0 },
            { label = 'Mirror Park', coords = vec3(1150.0, -500.0, 65.0), radius = 90.0 },
        },
    },
}
