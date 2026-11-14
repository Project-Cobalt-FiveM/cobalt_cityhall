---@type JobData
return {
    label = 'Taxi',
    description = 'Pick up fares around the city and drive them to their stop.',
    icon = 'taxi',
    kind = 'taxi',
    doneLabel = 'Fares done',
    crewSize = 2,
    site = {
        label = 'Downtown Cab Co.',
        coords = vec4(909.5, -177.4, 73.9, 107.0),
        ped = 's_m_y_dealer_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 198, color = 5 },
    },
    vehicle = {
        label = 'cab',
        model = 'taxi',
        plate = 'CAB',
        spawns = {
            vec4(899.40, -180.42, 73.9, 238.6),
            vec4(897.56, -183.21, 73.9, 239.6),
            vec4(903.43, -191.78, 73.9, 60.4),
            vec4(905.75, -188.35, 73.9, 59.6),
        },
    },
    -- Fares
    taxi = {
        base = 30, -- dollars paid per fare before distance
        perMeter = 0.02, -- dollars per meter between pickup and drop-off, straight line
        minTrip = 600.0, -- meters a drop-off must be from its pickup
        passengers = { 's_m_m_cntrybar_01', 'u_f_y_comjane', 'a_f_y_hipster_04', 's_m_m_highsec_02', 'a_m_y_hipster_03' }, -- ped models a fare can spawn as
        -- Kerbside stops, each a road lane next to the pavement (checked against GTA's vehicle nodes):
        -- coords is where the cab pulls up, heading along traffic; passenger is where the fare waits on the pavement, facing the road
        stops = {
            { label = 'Mirror Park Boulevard', coords = vec4(1190.39, -436.18, 66.09, 166.8), passenger = vec4(1188.05, -435.63, 66.09, 256.8) },
            { label = 'Pillbox Hill Medical Center', coords = vec4(271.05, -586.34, 42.34, 337.8), passenger = vec4(273.27, -587.25, 42.34, 67.8) },
            { label = 'Legion Square', coords = vec4(171.41, -870.78, 29.72, 340.4), passenger = vec4(173.67, -871.58, 29.72, 70.4) },
            { label = 'Textile City', coords = vec4(439.25, -860.65, 30.28, 270.0), passenger = vec4(439.25, -863.05, 30.28, 0.0) },
            { label = 'Strawberry Avenue', coords = vec4(79.44, -1480.59, 28.34, 139.4), passenger = vec4(77.61, -1479.03, 28.34, 229.4) },
            { label = 'Carson Avenue, Davis', coords = vec4(77.08, -1711.06, 27.91, 229.1), passenger = vec4(75.51, -1712.87, 27.91, 319.1) },
            { label = 'Maze Bank Arena', coords = vec4(-230.37, -1867.40, 27.75, 242.9), passenger = vec4(-231.46, -1869.54, 27.75, 332.9) },
            { label = 'LSIA Departures', coords = vec4(-1037.09, -2727.53, 19.19, 239.4), passenger = vec4(-1038.31, -2729.60, 19.19, 329.4) },
            { label = 'Vespucci Beach', coords = vec4(-1171.62, -1466.33, 3.44, 214.7), passenger = vec4(-1173.59, -1467.70, 3.44, 304.7) },
            { label = 'Del Perro Beach', coords = vec4(-1504.59, -866.25, 9.34, 66.2), passenger = vec4(-1503.62, -864.05, 9.34, 156.2) },
            { label = 'Little Seoul', coords = vec4(-628.66, -914.49, 23.13, 356.6), passenger = vec4(-626.26, -914.63, 23.13, 86.6) },
            { label = 'Portola Drive, Rockford Hills', coords = vec4(-721.19, -166.72, 36.09, 29.7), passenger = vec4(-719.11, -165.53, 36.09, 119.7) },
            { label = 'Carcer Way, Burton', coords = vec4(-519.63, -289.53, 34.41, 292.4), passenger = vec4(-518.72, -291.75, 34.41, 22.4) },
            { label = 'Vinewood Boulevard', coords = vec4(305.95, 167.70, 103.00, 70.3), passenger = vec4(306.75, 169.96, 103.00, 160.3) },
            { label = 'Capital Boulevard, Alta', coords = vec4(151.11, -314.38, 43.66, 70.6), passenger = vec4(151.91, -312.12, 43.66, 160.6) },
            { label = 'West Eclipse Boulevard, Richman', coords = vec4(-1417.49, 31.12, 51.50, 12.3), passenger = vec4(-1415.15, 31.63, 51.50, 102.3) },
            { label = 'Diamond Casino', coords = vec4(898.09, 72.12, 78.00, 140.4), passenger = vec4(896.24, 73.65, 78.00, 230.4) },
            { label = 'Galileo Observatory', coords = vec4(-373.53, 1177.83, 324.75, 69.0), passenger = vec4(-372.68, 1180.07, 324.75, 159.0) },
            { label = 'El Burro Heights', coords = vec4(1219.32, -1450.14, 33.81, 262.6), passenger = vec4(1219.01, -1452.52, 33.81, 352.6) },
            { label = 'Sandy Shores', coords = vec4(1678.80, 3799.79, 34.03, 126.6), passenger = vec4(1677.37, 3801.72, 34.03, 216.6) },
            { label = 'Paleto Bay', coords = vec4(-262.20, 6385.07, 29.91, 296.0), passenger = vec4(-261.15, 6382.91, 29.91, 26.0) },
        },
    },
}
