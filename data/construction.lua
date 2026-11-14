---@alias ConstructionSpot { [1]: string, [2]: string, [3]: vector4 } task, part of the site, coords

---@type JobStop[]
local stops <const> = {}

---@param site string
---@param label string
---@param list ConstructionSpot[]
local function spots(site, label, list)
    for _, spot in ipairs(list) do
        stops[#stops + 1] = {
            site = site,
            task = spot[1],
            label = ('%s site, %s'):format(label, spot[2]),
            coords = spot[3],
        }
    end
end

spots('mission_row', 'Mission Row', {
    { 'drill', 'pit footings', vec4(-142.58, -1072.10, 20.69, 96.1) },
    { 'hammer', 'pit formwork', vec4(-131.76, -1093.95, 20.69, 321.8) },
    { 'weld', 'rebar cage', vec4(-137.36, -1085.43, 20.64, 333.8) },
    { 'hammer', 'shoring boards', vec4(-117.83, -1085.14, 21.66, 199.0) },
    { 'drill', 'old slab', vec4(-108.06, -1063.99, 26.27, 344.1) },
    { 'drill', 'kerb line', vec4(-107.44, -1029.45, 26.27, 153.6) },
    { 'weld', 'fence posts', vec4(-150.30, -1033.28, 26.27, 158.9) },
    { 'hammer', 'hoarding', vec4(-132.40, -1038.27, 26.28, 180.5) },
})

spots('little_seoul', 'Little Seoul', {
    { 'hammer', 'timber frame', vec4(-820.21, -801.85, 18.53, 356.8) },
    { 'weld', 'steel column', vec4(-812.22, -788.79, 18.57, 269.0) },
    { 'weld', 'steel beam', vec4(-812.26, -797.70, 18.57, 269.0) },
    { 'drill', 'cracked slab', vec4(-834.24, -803.60, 18.16, 49.5) },
    { 'hammer', 'stud wall', vec4(-847.10, -805.84, 18.22, 87.8) },
    { 'drill', 'footpath', vec4(-841.21, -800.50, 18.17, 128.4) },
    { 'weld', 'gate frame', vec4(-823.40, -808.37, 18.53, 144.4) },
    { 'hammer', 'door frame', vec4(-835.20, -795.26, 18.57, 130.6) },
})

spots('murrieta', 'Murrieta Heights', {
    { 'hammer', 'roof trusses', vec4(532.16, -619.07, 23.74, 261.8) },
    { 'weld', 'steel frame', vec4(547.87, -619.67, 23.74, 263.6) },
    { 'weld', 'handrail', vec4(549.90, -602.74, 23.73, 271.2) },
    { 'drill', 'old footing', vec4(507.05, -656.47, 23.75, 354.6) },
    { 'hammer', 'formwork', vec4(500.42, -649.55, 23.75, 334.4) },
    { 'drill', 'drain trench', vec4(546.78, -627.81, 23.74, 320.8) },
    { 'hammer', 'wall panels', vec4(536.10, -597.81, 23.76, 252.4) },
    { 'drill', 'loading bay', vec4(496.85, -579.64, 23.75, 252.3) },
})

---@type table<string, JobAction>
local tasks <const> = {
    drill = {
        label = 'Breaking up the concrete',
        prompt = 'Use the jackhammer',
        duration = { 9000, 12000 },
        anim = { dict = 'amb@world_human_const_drill@male@drill@base', clip = 'base', flag = 1 },
        prop = { model = 'prop_tool_jackham', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
    },
    hammer = {
        label = 'Hammering the formwork',
        prompt = 'Hammer the formwork',
        duration = { 9000, 12000 },
        anim = { dict = 'amb@world_human_hammering@male@base', clip = 'base', flag = 1 },
        prop = { model = 'prop_tool_hammer', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
    },
    weld = {
        label = 'Welding the steel',
        prompt = 'Weld the steel',
        duration = { 10000, 13000 },
        anim = { dict = 'amb@world_human_welding@male@base', clip = 'base', flag = 1 },
        prop = { model = 'prop_weld_torch', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
    },
}

---@type JobData
return {
    label = 'Construction',
    description = 'Work a real building site: break concrete, hammer formwork and weld steel, one marked spot at a time.',
    icon = 'hardHat',
    kind = 'route',
    doneLabel = 'Tasks done',
    crewSize = 4,
    site = {
        label = 'Construction Office',
        coords = vec4(-97.06, -1013.83, 27.28, 160.0),
        ped = 's_m_y_construct_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 566, color = 47 },
    },
    route = {
        length = 1,
        bySite = true,
        actions = 1,
        radius = 1.5,
        marker = true,
        unit = 'task',
        pay = { perAction = 25, routeBonus = 150, bonusText = 'when the site is done', bonusLabel = 'Finished site' },
        action = tasks.hammer,
        tasks = tasks,
        stops = stops,
    },
}
