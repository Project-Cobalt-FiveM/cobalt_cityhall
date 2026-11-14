---@type JobData
return {
    label = locale('trucking.label'),
    description = locale('trucking.description'),
    icon = 'truck',
    kind = 'route',
    doneLabel = locale('trucking.done'),
    crewSize = 2,
    site = {
        label = locale('trucking.site'),
        coords = vec4(152.21, -3212.94, 5.88, 19.25),
        ped = 's_m_m_dockwork_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 477, color = 5 },
    },
    vehicle = {
        label = locale('trucking.vehicle'),
        model = 'mule',
        plate = 'HAUL',
        spawns = { vec4(141.12, -3204.31, 6.35, 267.5), vec4(141.12, -3196.31, 6.35, 267.5) },
    },
    -- Delivery route
    route = {
        length = 1, -- drop-offs per load
        actions = 6, -- boxes unloaded at each drop-off
        radius = 30.0, -- meters from a drop-off that count as arrived
        vehicleWithin = 30.0, -- meters the truck must be from the worker to load or unload
        atVehicle = true, -- boxes are loaded and unloaded at the back of the truck
        unit = locale('trucking.unit'), -- word used for one action in the job's text
        pay = { perAction = 10, perMeter = 0.025 }, -- dollars per box, plus dollars per meter driven from the depot or last stop
        -- Boxes drawn in the cargo bay, in the mule's own space (measured from mule.yft and prop_cs_cardbox_01.ydr)
        cargo = {
            boxes = 6, -- boxes a full load holds
            model = 'prop_cs_cardbox_01', -- box prop; its origin is its centre
            size = vec3(0.43, 0.345, 0.348), -- box width, depth and height in meters
            columns = 2, -- boxes side by side across the bay
            rows = 3, -- rows from the back doors inward; the first box loaded goes deepest
            gap = 0.06, -- meters between neighbouring boxes
            floor = -0.09, -- cargo floor height in vehicle space
            doorLine = -3.72, -- y of the closed back doors in vehicle space
            fromDoors = 0.30, -- meters left clear between the doors and the nearest row
        },
        load = {
            label = locale('trucking.loading'),
            prompt = locale('trucking.load'),
            duration = 3000,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            prop = { model = 'hei_prop_heist_box', bone = 60309, pos = vec3(0.025, 0.08, 0.255), rot = vec3(-145.0, 290.0, 0.0), rotOrder = 1 }, -- box carried in both hands: model, ped bone, position and rotation on the bone, and the order the rotation applies in
        },
        action = {
            label = locale('trucking.unloading'),
            prompt = locale('trucking.unload'),
            duration = 2500,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            prop = { model = 'hei_prop_heist_box', bone = 60309, pos = vec3(0.025, 0.08, 0.255), rot = vec3(-145.0, 290.0, 0.0), rotOrder = 1 },
        },
        -- Drop-offs: each is a loading yard, delivery bay or business car park off the road, with the heading the truck parks at
        stops = {
            { label = locale('trucking.stops.paleto_truck_stop'), coords = vec4(124.00, 6594.00, 31.20, 272.0) },
            { label = locale('trucking.stops.grapeseed_yard'), coords = vec4(1712.00, 4711.00, 42.00, 303.0) },
            { label = locale('trucking.stops.sandy_shores_247'), coords = vec4(1977.10, 3760.10, 31.50, 205.0) },
            { label = locale('trucking.stops.youtool'), coords = vec4(2769.10, 3473.80, 55.00, 247.0) },
            { label = locale('trucking.stops.harmony_yard'), coords = vec4(190.00, 2728.00, 42.50, 80.0) },
            { label = locale('trucking.stops.gopostal'), coords = vec4(75.20, 116.70, 79.30, 159.0) },
            { label = locale('trucking.stops.pacific_bluffs_gas'), coords = vec4(-2068.80, -305.30, 12.50, 85.0) },
            { label = locale('trucking.stops.mega_mall'), coords = vec4(115.70, -1757.60, 29.00, 238.0) },
            { label = locale('trucking.stops.orchardville_warehouse'), coords = vec4(937.00, -1810.50, 30.30, 270.0) },
            { label = locale('trucking.stops.port_warehouse'), coords = vec4(1209.00, -3240.00, 5.50, 0.0) },
        },
    },
}
