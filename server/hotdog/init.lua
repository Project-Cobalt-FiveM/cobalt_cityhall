local Registry <const> = require 'server.registry'
local Shifts <const> = require 'server.shifts'
local Payout <const> = require 'server.payout'
local State <const> = require 'server.hotdog.state'
local Hotdog <const> = require 'shared.hotdog'

local PLACE_SLACK <const> = 2.0
local STAND_REACH <const> = 3.5
local SPAWN_TIMEOUT_MS <const> = 2000
local EXPIRE_SWEEP_MS <const> = 5000

---@type table<integer, { coords: vector3, heading: number }>
local pendingPlace <const> = {}

---@param src integer
---@return Shift?
---@return StandConfig?
local function standShift(src)
    local shift <const> = Registry.get(src)
    local stand <const> = shift?.def.stand

    if not stand then return end

    return shift, stand
end

---@param src integer
---@param range? number
---@return HotdogStand?
---@return Shift?
---@return StandConfig?
local function ownStand(src, range)
    local shift, config = standShift(src)
    local stand <const> = State.stands[src]

    if not shift or not stand then return end
    if not Registry.near(src, stand.coords, range or STAND_REACH) then return end

    return stand, shift, config
end

---@param value unknown
---@return boolean
local function isVector3(value)
    return type(value) == 'vector3'
end

lib.callback.register('cobalt_cityhall:hotdog:placeStart', function(src, coords, heading)
    local shift, config = standShift(src)

    if not shift or not config then return end
    if not isVector3(coords) or type(heading) ~= 'number' then return end

    if State.stands[src] then
        Registry.notify(src, 'Your cart is already out. Fold it up before moving it', 'error')
        return
    end

    if (exports.cobalt_inventory:GetItemCount(src, config.item) or 0) < 1 then return end
    if not Registry.near(src, coords, config.place.range + PLACE_SLACK) then return end

    pendingPlace[src] = { coords = coords, heading = heading % 360.0 }
    Registry.startAction(shift, 'hotdog:place', config.place.duration)

    return config.place.duration
end)

---@param src integer
---@param config StandConfig
---@param spot { coords: vector3, heading: number }
---@return integer?
local function spawnCart(src, config, spot)
    local at <const> = spot.coords
    local entity <const> = CreateObjectNoOffset(joaat(config.model), at.x, at.y, at.z, true, true, false)
    local deadline <const> = GetGameTimer() + SPAWN_TIMEOUT_MS

    while not DoesEntityExist(entity) do
        if GetGameTimer() > deadline then
            if entity ~= 0 then DeleteEntity(entity) end

            return
        end

        Wait(0)
    end

    SetEntityHeading(entity, spot.heading)
    FreezeEntityPosition(entity, true)
    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(tostring(src)))
    Entity(entity).state:set('hotdogOwner', src, true)

    return entity
end

lib.callback.register('cobalt_cityhall:hotdog:placeFinish', function(src, finished)
    local shift, config = standShift(src)
    local spot <const> = pendingPlace[src]

    pendingPlace[src] = nil

    if not shift or not config or not spot then return end
    if not Registry.endAction(shift, 'hotdog:place') or not finished then return end
    if State.stands[src] then return end

    if not exports.cobalt_inventory:RemoveItem(src, config.item, 1, nil, 'cobalt_cityhall:hotdog') then return end

    local entity <const> = spawnCart(src, config, spot)

    if not entity then
        exports.cobalt_inventory:AddItem(src, config.item, 1, nil, nil, 'cobalt_cityhall:hotdog')
        return
    end

    State.stands[src] = {
        src = src,
        entity = entity,
        coords = spot.coords,
        open = false,
        cooking = false,
        customers = {},
        queue = {},
        nextId = 0,
        lastRecruit = 0,
        lastServe = 0,
        lastStep = 0,
        dog = State.freshDog(),
    }

    return NetworkGetNetworkIdFromEntity(entity)
end)

lib.callback.register('cobalt_cityhall:hotdog:packStart', function(src)
    local stand, shift, config = ownStand(src)

    if not stand or not shift or not config then return end

    Registry.startAction(shift, 'hotdog:pack', config.pack.duration)

    return config.pack.duration
end)

lib.callback.register('cobalt_cityhall:hotdog:packFinish', function(src, finished)
    local stand, shift, config = ownStand(src)

    if not stand or not shift or not config then return false end
    if not Registry.endAction(shift, 'hotdog:pack') or not finished then return false end

    State.remove(src)
    exports.cobalt_inventory:AddItem(src, config.item, 1, nil, nil, 'cobalt_cityhall:hotdog')

    return true
end)

lib.callback.register('cobalt_cityhall:hotdog:setOpen', function(src, open)
    local stand <const> = ownStand(src)

    if not stand or type(open) ~= 'boolean' then return end

    stand.open = open

    if not open then
        table.wipe(stand.customers)
        table.wipe(stand.queue)
    end

    return { open = open, rep = State.rep(src) }
end)

---@param config StandConfig
---@return HotdogOrder
local function rollOrder(config)
    local customers <const> = config.customers
    local sauces <const> = {}
    local any = false

    for _, sauce in ipairs(config.sauces) do
        sauces[sauce.id] = math.random() < customers.sauceChance
        any = any or sauces[sauce.id]
    end

    if not any then sauces[config.sauces[math.random(1, #config.sauces)].id] = true end

    return { toasted = math.random() < customers.toastChance, sauces = sauces }
end

lib.callback.register('cobalt_cityhall:hotdog:recruit', function(src)
    local _, config = standShift(src)
    local stand <const> = config and ownStand(src, config.customers.ownerRange)

    if not stand or not config or not stand.open then return end

    local now <const> = GetGameTimer()
    local customers <const> = config.customers

    if #stand.queue >= customers.maxQueue then return end
    if now - stand.lastRecruit < customers.recruitGapMs then return end

    stand.lastRecruit = now
    stand.nextId += 1

    local patience <const> = math.random(customers.patience[1], customers.patience[2])

    ---@type HotdogCustomer
    local customer <const> = {
        id = stand.nextId,
        order = rollOrder(config),
        expiresAt = now + patience + customers.walkMs,
    }

    stand.customers[customer.id] = customer
    stand.queue[#stand.queue + 1] = customer.id

    return { id = customer.id, order = customer.order, patience = patience }
end)

---@param stand HotdogStand
---@param id integer
---@return HotdogCustomer?
local function dropCustomer(stand, id)
    local customer <const> = stand.customers[id]

    if not customer then return end

    stand.customers[id] = nil

    for i, queued in ipairs(stand.queue) do
        if queued == id then
            table.remove(stand.queue, i)
            break
        end
    end

    return customer
end

lib.callback.register('cobalt_cityhall:hotdog:leave', function(src, id, reason)
    local stand <const> = State.stands[src]
    local _, config = standShift(src)

    if not stand or not config or math.type(id) ~= 'integer' then return end

    local customer <const> = dropCustomer(stand, id)

    if not customer then return end

    if reason == 'killed' then return State.addRep(src, config.rep.killed, config.rep.max) end

    local now <const> = GetGameTimer()
    local waitedOut <const> = reason == 'walkout' and now >= customer.expiresAt - config.customers.walkMs

    if not waitedOut and now < customer.expiresAt then return end

    return State.addRep(src, config.rep.walkout, config.rep.max)
end)

---@param stand HotdogStand
---@param config StandConfig
---@param now integer
local function expire(stand, config, now)
    for i = #stand.queue, 1, -1 do
        local id <const> = stand.queue[i]
        local customer <const> = stand.customers[id]

        if customer and now >= customer.expiresAt then
            dropCustomer(stand, id)

            local rep <const> = State.addRep(stand.src, config.rep.walkout, config.rep.max)

            TriggerClientEvent('cobalt_cityhall:hotdog:walkedOff', stand.src, id, rep)
        end
    end
end

CreateThread(function()
    while true do
        Wait(EXPIRE_SWEEP_MS)

        local now <const> = GetGameTimer()

        for src, stand in pairs(State.stands) do
            local _, config = standShift(src)

            if config and stand.open then expire(stand, config, now) end
        end
    end
end)

---@alias HotdogStep fun(dog: HotdogBuild, now: integer, config: StandConfig, ...: unknown): boolean, unknown?, unknown?

---@type table<string, HotdogStep>
local steps <const> = {
    grillOn = function(dog, now)
        if dog.sausage then return false end

        dog.sausage, dog.cookMs, dog.grillAt = 'grill', 0, now
        dog.sides, dog.side, dog.sideAt = { 0, 0 }, 1, now

        return true
    end,
    turn = function(dog, now)
        if dog.sausage ~= 'grill' then return false end

        dog.sides[dog.side] += now - dog.sideAt
        dog.side, dog.sideAt = dog.side == 1 and 2 or 1, now

        return true
    end,
    grillOff = function(dog, now, config)
        if dog.sausage ~= 'grill' then return false end

        dog.cookMs = now - dog.grillAt
        dog.sides[dog.side] += now - dog.sideAt
        dog.sausage = 'done'

        return true, Hotdog.cookLevel(config, dog.cookMs, config.kitchen.graceMs), Hotdog.evenlyBrowned(config, dog.sides)
    end,
    bunOn = function(dog, now)
        if dog.bun then return false end

        dog.bun, dog.bunAt, dog.bunMs = 'grill', now, 0

        return true
    end,
    bunOff = function(dog, now, config)
        if dog.bun ~= 'grill' then return false end

        dog.bunMs += now - dog.bunAt
        dog.bun = 'done'

        return true, Hotdog.bunLevel(config, dog.bunMs, config.kitchen.graceMs)
    end,
    bunPlain = function(dog)
        if dog.bun then return false end

        dog.bun, dog.bunMs = 'done', 0

        return true, 'plain'
    end,
    assemble = function(dog)
        if dog.sausage ~= 'done' or dog.bun ~= 'done' or dog.assembled then return false end

        dog.assembled = true

        return true
    end,
    sauceStart = function(dog, now, config, id)
        if not dog.assembled or dog.squeeze or type(id) ~= 'string' then return false end
        if not Hotdog.sauce(config, id) or dog.sauces[id] then return false end

        dog.squeeze = { id = id, at = now }

        return true
    end,
    sauceEnd = function(dog, now, config, id, coverage)
        local squeeze <const> = dog.squeeze

        if not squeeze or squeeze.id ~= id then return false end
        if type(coverage) ~= 'number' or coverage ~= coverage then return false end

        dog.squeeze = nil

        local held <const> = now - squeeze.at >= config.squeeze.minMs
        local covered <const> = math.max(0.0, math.min(1.0, coverage)) >= config.squeeze.coverage

        if held and covered then dog.sauces[id] = true end

        return true, dog.sauces[id] == true
    end,
}

---@param stand HotdogStand
---@param lids? table<LidName, boolean>
local function setLids(stand, lids)
    if DoesEntityExist(stand.entity) then Entity(stand.entity).state:set('hotdogLids', lids or {}, true) end
end

lib.callback.register('cobalt_cityhall:hotdog:cook', function(src, cooking)
    local stand <const> = ownStand(src)

    if not stand or type(cooking) ~= 'boolean' then return false end

    stand.cooking = cooking

    if not cooking then setLids(stand) end

    return true
end)

---@type table<string, { lid: LidName, open: boolean }>
local LID_STEPS <const> = {
    grillOn = { lid = 'fryer', open = true },
    grillOff = { lid = 'fryer', open = false },
    bunOn = { lid = 'griddle', open = true },
    bunOff = { lid = 'griddle', open = false },
}

lib.callback.register('cobalt_cityhall:hotdog:step', function(src, action, ...)
    local stand, _, config = ownStand(src)
    local step <const> = steps[action]

    if not stand or not config or not step or not stand.cooking then return false end

    local now <const> = GetGameTimer()

    if now - stand.lastStep < config.limits.stepGapMs then return false end

    stand.lastStep = now

    local ok <const>, detail <const>, extra <const> = step(stand.dog, now, config, ...)
    local change <const> = ok and LID_STEPS[action]

    if change then
        local lids <const> = table.clone(Entity(stand.entity).state.hotdogLids or {})

        lids[change.lid] = change.open
        setLids(stand, lids)
    end

    return ok, detail, extra
end)

lib.callback.register('cobalt_cityhall:hotdog:discard', function(src)
    local stand <const> = ownStand(src)

    if not stand then return false end

    stand.dog = State.freshDog()
    setLids(stand)

    return true
end)

---@param config StandConfig
---@param dog HotdogBuild
---@param order HotdogOrder
---@return string[] misses
---@return boolean inedible
local function inspect(config, dog, order)
    local misses <const> = {}
    local cook <const> = Hotdog.cookLevel(config, dog.cookMs, config.kitchen.graceMs)
    local bun <const> = Hotdog.bunLevel(config, dog.bunMs, config.kitchen.graceMs)

    if cook ~= 'cooked' then
        misses[#misses + 1] = cook == 'raw' and 'The sausage is raw' or 'The sausage is burnt'
    elseif not Hotdog.evenlyBrowned(config, dog.sides) then
        misses[#misses + 1] = 'One side is still pale'
    end

    if bun == 'burnt' then
        misses[#misses + 1] = 'The bun is burnt'
    elseif order.toasted and bun ~= 'toasted' then
        misses[#misses + 1] = 'They wanted the bun toasted'
    elseif not order.toasted and bun ~= 'plain' then
        misses[#misses + 1] = 'They wanted a plain bun'
    end

    for _, sauce in ipairs(config.sauces) do
        local wanted <const> = order.sauces[sauce.id] == true
        local added <const> = dog.sauces[sauce.id] == true

        if wanted and not added then
            misses[#misses + 1] = ('No %s'):format(sauce.label:lower())
        elseif added and not wanted then
            misses[#misses + 1] = ('They never asked for %s'):format(sauce.label:lower())
        end
    end

    return misses, cook ~= 'cooked' or bun == 'burnt'
end

lib.callback.register('cobalt_cityhall:hotdog:serve', function(src)
    local stand, shift, config = ownStand(src)

    if not stand or not shift or not config or not stand.cooking then return end
    if not stand.dog.assembled or stand.dog.squeeze then return end

    local now <const> = GetGameTimer()

    if now - stand.lastServe < config.limits.serveGapMs then return end

    local id <const> = stand.queue[1]
    local customer <const> = id and stand.customers[id]

    if not customer or now > customer.expiresAt then return end

    stand.lastServe = now
    dropCustomer(stand, id)

    local misses, inedible = inspect(config, stand.dog, customer.order)
    local rep <const> = State.rep(src)
    local ok <const> = #misses == 0
    local price <const> = Hotdog.price(config, rep)
    local paid <const> = inedible and 0 or ok and price or math.floor(price / 2)
    local tip <const> = ok and Hotdog.tip(config, rep) or 0

    stand.dog = State.freshDog()

    if paid + tip > 0 then
        local label <const> = tip > 0 and ('a hot dog and a $%d tip'):format(tip) or 'a hot dog'

        Payout.pay(shift, paid + tip, label, 'cash')
    end

    shift.done += 1

    local delta <const> = ok and config.rep.correct or config.rep.wrong
    local after <const> = State.addRep(src, delta, config.rep.max)

    Shifts.sync(shift)

    ---@type HotdogServeResult
    return { ok = ok, paid = paid, tip = tip, rep = after, misses = misses }
end)

AddEventHandler('playerDropped', function()
    pendingPlace[source] = nil
end)
