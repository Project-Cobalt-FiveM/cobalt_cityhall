---@type JobData
return {
    label = 'Trucking',
    description = 'Load cargo at the Elysian Island depot and deliver it across the state.',
    icon = 'truck',
    kind = 'route',
    doneLabel = 'Boxes delivered',
    crewSize = 2,
    site = {
        label = 'Elysian Island Depot',
        coords = vec4(152.21, -3212.94, 5.88, 19.25),
        ped = 's_m_m_dockwork_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 477, color = 5 },
    },
    vehicle = {
        label = 'box truck',
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
        unit = 'box', -- word used for one action in the job's text
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
            label = 'Loading a box',
            prompt = 'Load a box',
            duration = 3000,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            prop = { model = 'prop_cs_cardbox_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        },
        action = {
            label = 'Unloading a box',
            prompt = 'Unload a box',
            duration = 2500,
            anim = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
            prop = { model = 'prop_cs_cardbox_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        },
        -- Drop-offs: each is a truck-wide kerb on a through road (checked against GTA's vehicle nodes), with the heading the truck parks at
        stops = {
            { label = 'Cholla Springs Avenue, Sandy Shores', coords = vec4(1678.98, 3799.55, 34.03, 126.6) },
            { label = 'Pyrite Avenue, Paleto Bay', coords = vec4(-132.81, 6323.19, 30.56, 45.0) },
            { label = 'Labor Place, La Mesa', coords = vec4(1013.83, -1882.45, 27.56, 92.5) },
            { label = 'Eastbourne Way, Rockford Hills', coords = vec4(-570.29, -154.52, 37.06, 113.8) },
            { label = 'Buccaneer Way, Port of Los Santos', coords = vec4(1169.80, -3138.00, 4.78, 0.0) },
            { label = 'Greenwich Parkway, La Puerta', coords = vec4(-1073.53, -1937.16, 12.16, 315.6) },
            { label = 'Grapeseed Main Street', coords = vec4(1701.00, 4643.14, 42.63, 9.7) },
            { label = 'Capital Boulevard, La Mesa', coords = vec4(752.00, -1427.20, 28.03, 90.0) },
        },
    },
}
