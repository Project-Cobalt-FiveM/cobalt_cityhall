---@type JobSwing
local swing <const> = {
    hitPhase = 0.42,
    reach = vec3(0.0, 0.9, -0.6),
    particles = {
        { asset = 'core', name = 'mel_concrete', scale = 1.0 },
        { asset = 'core', name = 'ent_dst_rocks_small', scale = 0.8 },
    },
    sounds = { 'pickaxe_1', 'pickaxe_2', 'pickaxe_3' },
    volume = 0.6,
    distance = 20.0,
}

---@param shortest integer milliseconds
---@param longest integer milliseconds
---@return JobAction
local function pickaxe(shortest, longest)
    return {
        label = 'Breaking the rock',
        prompt = 'Mine',
        duration = { shortest, longest },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot', flag = 1 },
        prop = {
            model = 'prop_tool_pickaxe',
            bone = 57005,
            pos = vec3(0.08, -0.1, -0.04),
            rot = vec3(78.0, -20.0, 175.0),
        },
        swing = swing,
    }
end

---@type JobData
return {
    label = 'Mining',
    description = 'Break ore at Davis Quarry and sell it to the foreman.',
    icon = 'mountains',
    kind = 'gather',
    doneLabel = 'Ore mined',
    goods = 'Ore',
    crewSize = 4,
    site = {
        label = 'Davis Quarry',
        coords = vec4(2943.1362, 2747.832, 43.3318, 252.1999),
        ped = 'a_m_m_farmer_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 618, color = 5 },
    },
    prices = { coal = 2, copper_ore = 3, iron_ore = 5, silver_ore = 10, gold_ore = 20 },
    groups = {
        {
            label = 'Coal seam',
            prop = 'prop_rock_3_b',
            radius = 2.0,
            cooldown = 25000,
            amount = { 1, 2 },
            action = pickaxe(4500, 6000),
            yields = { { name = 'coal', weight = 1 } },
            points = {
                { coords = vec3(2938.3345, 2808.9683, 42.1674) },
                { coords = vec3(2930.3652, 2811.0193, 43.4722) },
                { coords = vec3(2925.0359, 2807.3450, 42.9333) },
                { coords = vec3(2927.2339, 2799.7976, 41.3330) },
                { coords = vec3(2930.2278, 2794.4519, 40.6447) },
                { coords = vec3(2935.8081, 2795.5881, 40.6888) },
                { coords = vec3(2940.8623, 2800.0393, 40.9543) },
                { coords = vec3(2935.3396, 2802.2466, 41.2976) },
                { coords = vec3(2932.2173, 2806.7004, 42.2299) },
                { coords = vec3(2941.5352, 2805.1804, 41.1859) },
            },
        },
        {
            label = 'Copper vein',
            prop = 'prop_rock_3_d',
            radius = 2.0,
            cooldown = 25000,
            amount = { 1, 2 },
            action = pickaxe(4500, 6000),
            yields = { { name = 'copper_ore', weight = 1 } },
            points = {
                { coords = vec3(2949.8770, 2851.0256, 48.3509) },
                { coords = vec3(2955.0566, 2850.1597, 47.6026) },
                { coords = vec3(2959.4751, 2848.0740, 46.8103) },
                { coords = vec3(2952.2109, 2847.9136, 47.2530) },
                { coords = vec3(2956.3149, 2845.9241, 46.5613) },
                { coords = vec3(2947.4197, 2848.0171, 47.7500) },
                { coords = vec3(2961.4399, 2844.1255, 46.0608) },
            },
        },
        {
            label = 'Iron deposit',
            prop = 'prop_rock_3_f',
            radius = 2.0,
            cooldown = 45000,
            amount = { 1, 2 },
            action = pickaxe(5000, 7500),
            yields = { { name = 'iron_ore', weight = 1 } },
            points = {
                { coords = vec3(3027.8311, 2772.1812, 55.4793) },
                { coords = vec3(3030.8904, 2767.5234, 56.4680) },
                { coords = vec3(3028.2546, 2764.4390, 56.0667) },
                { coords = vec3(3030.5837, 2760.3337, 57.4613) },
                { coords = vec3(3025.9062, 2756.8679, 56.0076) },
                { coords = vec3(3026.0994, 2751.2605, 57.2785) },
                { coords = vec3(3020.6831, 2748.7808, 55.5372) },
            },
        },
        {
            label = 'Silver vein',
            prop = 'prop_rock_3_d',
            radius = 2.0,
            cooldown = 75000,
            amount = { 1, 2 },
            action = pickaxe(6000, 8500),
            yields = { { name = 'silver_ore', weight = 1 } },
            points = {
                { coords = vec3(2969.4246, 2697.7976, 54.5088) },
                { coords = vec3(2966.6487, 2694.4221, 54.6609) },
                { coords = vec3(2962.9324, 2697.2637, 54.6642) },
                { coords = vec3(2953.2451, 2697.2317, 55.1387) },
                { coords = vec3(2950.2148, 2700.9580, 54.8590) },
            },
        },
        {
            label = 'Gold lode',
            prop = 'prop_rock_3_f',
            radius = 2.0,
            cooldown = 120000,
            amount = { 1, 2 },
            action = pickaxe(8000, 11000),
            yields = { { name = 'gold_ore', weight = 1 } },
            points = {
                { coords = vec3(3041.3960, 2719.4390, 63.1831) },
                { coords = vec3(3047.6887, 2717.8809, 62.7571) },
                { coords = vec3(3045.9670, 2722.4072, 63.1737) },
                { coords = vec3(3052.4326, 2721.9761, 63.1375) },
                { coords = vec3(3052.2554, 2728.0950, 63.6344) },
                { coords = vec3(3058.0610, 2731.1460, 64.6821) },
                { coords = vec3(3055.9949, 2737.5295, 64.3239) },
                { coords = vec3(3060.6294, 2741.4951, 64.5270) },
                { coords = vec3(3058.5295, 2746.5312, 64.3540) },
                { coords = vec3(3060.2603, 2750.5828, 64.3339) },
            },
        },
    },
}
