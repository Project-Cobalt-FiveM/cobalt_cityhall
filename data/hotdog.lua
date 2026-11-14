---@type JobData
return {
    label = 'Hot Dog Stand',
    description = 'Set up a cart where people walk past, grill to order and build a name on the street.',
    icon = 'hotdog',
    kind = 'stand',
    doneLabel = 'Hot dogs sold',
    crewSize = 1,
    site = {
        label = 'Vespucci Beach',
        coords = vec4(-1224.6, -1489.9, 4.37, 125.0),
        blip = { sprite = 93, color = 3 },
    },
    -- The cart: placement, cooking, customers and pay
    stand = {
        item = 'hotdog_stand', -- item the player places the cart from
        model = 'cobalt_hotdogstand', -- cart prop model
        -- Placing the cart
        place = {
            range = 7.0, -- meters from the player the cart can be placed
            maxSlope = 10.0, -- steepest ground in degrees the cart can stand on
            maxStep = 0.25, -- meters the ground under each corner may rise or drop from the centre
            footprint = vec2(0.95, 0.6), -- half width and half depth in meters checked for ground
            duration = 6500, -- milliseconds to unfold the cart
            label = 'Unfolding the cart', -- progress bar text
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 }, -- animation while unfolding
        },
        -- Packing the cart away
        pack = {
            duration = 5000, -- milliseconds to fold the cart
            label = 'Folding up the cart', -- progress bar text
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 }, -- animation while folding
        },
        -- Where people stand, as offsets in meters from the cart
        spots = {
            vendor = vec3(-0.15, 0.85, 0.0), -- where the player cooks
            vendorHeading = 180.0, -- degrees added to the cart heading for the player
            counter = vec3(-1.75, 0.0, 0.0), -- where the first customer waits
            customerHeading = -90.0, -- degrees added to the cart heading for customers
            queueStep = vec3(-1.1, 0.0, 0.0), -- offset from one customer in line to the next
        },
        -- Cooking station; positions are offsets in meters from the cart
        kitchen = {
            fryer = vec3(-0.3385, 0.1695, 0.905), -- centre of the sausage well
            griddle = vec3(-0.145, 0.1695, 0.905), -- centre of the bun well
            lids = { fryer = vec3(-0.3385, 0.010, 0.927), griddle = vec3(-0.145, 0.010, 0.927) }, -- hinge of each lid
            ready = { sausage = vec3(-0.36, -0.195, 0.951), bun = vec3(-0.27, -0.195, 0.951) }, -- where cooked food rests
            supply = vec3(0.2, 0.17, 0.95), -- where raw food and the tongs come from
            board = vec3(-0.86, 0.0, 0.927), -- where the hot dog is built and dressed
            camera = { offset = vec3(-0.55, 0.78, 1.68), target = vec3(-0.5, 0.05, 0.93), fov = 55.0, easeMs = 900 }, -- cooking camera position, look-at point, field of view, and milliseconds to ease in and out
            motion = { carryMs = 650, lidMs = 400, lift = 0.12 }, -- milliseconds to carry food, milliseconds to swing a lid, meters food lifts while carried
            sausage = { cookedAt = 9000, burntAt = 19000, evenShare = 0.35 }, -- milliseconds on the grill until cooked and until burnt; share of the time from 0.0 to 1.0 each side must spend face down
            toast = { toastedAt = 5000, burntAt = 14000 }, -- milliseconds on the grill until the bun is toasted and until it burns
            graceMs = 400, -- milliseconds the cooked and toasted windows stretch in the player's favour
            -- Prop models for the food and the cart parts
            models = {
                rawSausage = 'cobalt_hotdog_sausage_raw',
                cookedSausage = 'cobalt_hotdog_sausage',
                halfDownSausage = 'cobalt_hotdog_sausage_half_down',
                halfUpSausage = 'cobalt_hotdog_sausage_half_up',
                burntSausage = 'cobalt_hotdog_sausage_burnt',
                bun = 'cobalt_hotdog_bun',
                toastedBun = 'cobalt_hotdog_bun_toasted',
                burntBun = 'cobalt_hotdog_bun_burnt',
                hotdog = 'prop_cs_hotdog_01',
                lids = { fryer = 'cobalt_hotdogstand_lid_fryer', griddle = 'cobalt_hotdogstand_lid_griddle' },
                tongs = 'cobalt_hotdog_tongs',
                bubble = 'cobalt_hotdog_bubble',
            },
            standIns = { food = 'prop_cs_hotdog_02', bottle = 'prop_food_mustard' }, -- stock GTA props used when a custom model is not streamed
            oil = { liquid = 'cobalt_hotdog_oil_liquid' }, -- oil surface prop in the sausage well
            steam = { asset = 'core', name = 'ent_amb_cluckb_steam', scale = 0.12, lift = 0.03 }, -- particle over a cooking well; lift is meters above it
            smoke = { asset = 'core', name = 'ent_anim_bbq', scale = 0.15, lift = 0.04 }, -- particle over burnt food; lift is meters above the well
            sizzle = { sound = 'grill_sizzle', volume = 0.55, distance = 14.0 }, -- cobalt_sound file, volume from 0.0 to 1.0, and meters it carries
            anim = { dict = 'amb@prop_human_bbq@male@base', clip = 'base', flag = 1 }, -- animation the player plays while cooking
            prop = { model = 'prop_fish_slice_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) }, -- spatula held while cooking: model, ped bone, and position and rotation on the bone
        },
        -- Sauces and toppings: bottle model, kind ('line' is squeezed along the hot dog, 'chunks' is sprinkled) and the piece model laid down
        sauces = {
            { id = 'mustard', label = 'Mustard', model = 'prop_food_mustard', kind = 'line', piece = 'cobalt_hotdog_line_mustard' },
            { id = 'ketchup', label = 'Ketchup', model = 'prop_food_ketchup', kind = 'line', piece = 'cobalt_hotdog_line_ketchup' },
            { id = 'mayo', label = 'Mayo', model = 'cobalt_hotdog_mayo', kind = 'line', piece = 'cobalt_hotdog_line_mayo' },
            { id = 'relish', label = 'Relish', model = 'cobalt_hotdog_relish', kind = 'chunks', piece = 'cobalt_hotdog_bit_relish' },
            { id = 'onions', label = 'Onions', model = 'cobalt_hotdog_onions', kind = 'chunks', piece = 'cobalt_hotdog_bit_onion' },
        },
        squeeze = { coverage = 0.6, minMs = 700, bins = 12 }, -- share of the hot dog from 0.0 to 1.0 a sauce must cover, least milliseconds of squeezing, and sections the hot dog is split into to measure coverage
        -- Customers
        customers = {
            radius = 70.0, -- meters around the cart where pedestrians are counted and recruited
            scanMs = 3000, -- milliseconds between looks for a new customer
            maxQueue = 4, -- most customers in line at once
            recruitGapMs = 8000, -- least milliseconds between two new customers
            perPed = 0.03, -- chance a scan brings a customer, per pedestrian nearby
            crowdCap = 30, -- most pedestrians counted toward that chance
            minChance = 0.15, -- lowest chance per scan, from 0.0 to 1.0, while anyone is nearby
            maxChance = 0.6, -- highest chance per scan, from 0.0 to 1.0
            repBoost = 1.0, -- extra chance at full street rep, as a fraction (1.0 doubles it)
            ownerRange = 12.0, -- meters the player must be from the cart for customers to come
            patience = { 75000, 120000 }, -- milliseconds a customer waits in line, picked between the two
            walkMs = 45000, -- milliseconds a customer has to walk up before giving up
            toastChance = 0.55, -- chance from 0.0 to 1.0 a customer wants a toasted bun
            sauceChance = 0.45, -- chance from 0.0 to 1.0 a customer wants each sauce
            idle = 'WORLD_HUMAN_STAND_IMPATIENT', -- scenario customers play while waiting
        },
        pay = { base = 14, repPrice = 0.6, tip = { 1, 6 }, repTip = 1.0 }, -- dollars in cash per hot dog; extra price at full rep as a fraction; tip range in dollars; extra tip at full rep as a fraction
        rep = { max = 100, correct = 2, wrong = -4, walkout = -1, killed = -10 }, -- highest street rep; rep for a correct order, a wrong order, a customer who walks off and a customer the vendor kills
        limits = { serveGapMs = 5000, stepGapMs = 200 }, -- least milliseconds between two served orders and between two cooking steps
    },
}
