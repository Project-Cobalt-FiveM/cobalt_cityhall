local Dui <const> = require 'client.hotdog.dui'
local Work <const> = require 'client.work'
local Hotdog <const> = require 'shared.hotdog'

local core <const> = exports.cobalt_core

local HEAD_BONE <const> = 31086
local ABOVE_HEAD <const> = 0.42
local ARRIVE_RANGE <const> = 0.8
local SETTLE_RANGE <const> = 1.5
local STOPPED_SPEED <const> = 0.15
local THINK_MS <const> = 500
local WALK_SPEED <const> = 1.0
local WANDER_RELEASE_MS <const> = 30000
local DUI_WIDTH <const>, DUI_HEIGHT <const> = 360, 340
local AMBIENT_POPULATION <const> = { [4] = true, [5] = true }
local SKIPPED_PED_TYPES <const> = { [6] = true, [27] = true, [28] = true, [29] = true }

local HANDOVER <const> = { dict = 'mp_common', clip = 'givetake1_b' }
local EAT <const> = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 }
local GRUMBLE <const> = { dict = 'gestures@m@standing@casual', clip = 'gesture_damn' }
local HOTDOG_IN_HAND <const> = { bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) }

---@alias PatronState 'walking' | 'waiting'

---@class HotdogPatron
---@field id integer
---@field ped integer
---@field order HotdogOrder
---@field patience integer
---@field state PatronState
---@field since integer
---@field slot integer
---@field dui HotdogDui

---@class CustomerContext
---@field config StandConfig
---@field cart integer
---@field rep integer

local Customers <const> = {}

---@type HotdogPatron[]
local line <const> = {}
---@type table<integer, true>
local recruited <const> = {}

---@type CustomerContext?
local context

---@type table<integer, integer | false> peds walking off, with the hot dog they carry
local leaving <const> = {}

---@param slot integer
---@return vector3 coords
---@return number heading
local function slotSpot(slot)
    local active <const> = context --[[@as CustomerContext]]
    local spots <const> = active.config.spots
    local spot <const> = spots.counter + spots.queueStep * (slot - 1)
    local coords <const> = GetOffsetFromEntityInWorldCoords(active.cart, spot.x, spot.y, spot.z)

    return coords, (GetEntityHeading(active.cart) + spots.customerHeading) % 360.0
end

---@param patron HotdogPatron
local function walkToSlot(patron)
    local coords <const>, heading <const> = slotSpot(patron.slot)

    patron.state, patron.since = 'walking', GetGameTimer()

    ClearPedTasks(patron.ped)
    TaskFollowNavMeshToCoord(patron.ped, coords.x, coords.y, coords.z, WALK_SPEED, -1, 0.3, 0, heading)
end

---@param ped integer
---@param anim { dict: string, clip: string, flag?: integer }
local function playAnim(ped, anim)
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, -4.0, -1, anim.flag or 48, 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
end

---@param ped integer
---@param model string
---@return integer?
local function handHotdog(ped, model)
    local hash <const> = Work.loadModel(model)

    if not hash then return end

    local prop <const> = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    local spot <const> = HOTDOG_IN_HAND

    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, spot.bone),
        spot.pos.x, spot.pos.y, spot.pos.z,
        spot.rot.x, spot.rot.y, spot.rot.z,
        true, true, false, true, 1, true
    )

    return prop
end

---@param ped integer
local function letGo(ped)
    local prop <const> = leaving[ped]

    leaving[ped] = nil

    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    if not DoesEntityExist(ped) then return end

    StopAnimTask(ped, EAT.dict, EAT.clip, 1.0)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedAsNoLongerNeeded(ped)
end

---@param ped integer
---@param mood 'happy' | 'angry' | 'lost'
---@param model string
local function sendOff(ped, mood, model)
    leaving[ped] = false

    CreateThread(function()
        if not DoesEntityExist(ped) then return letGo(ped) end

        ClearPedTasks(ped)

        if mood == 'happy' then
            playAnim(ped, HANDOVER)
            Wait(1200)
            leaving[ped] = handHotdog(ped, model) or false
            playAnim(ped, EAT)
        elseif mood == 'angry' then
            playAnim(ped, GRUMBLE)
            Wait(1500)
        end

        TaskWanderStandard(ped, 10.0, 10)
        Wait(WANDER_RELEASE_MS)
        letGo(ped)
    end)
end

local function reslot()
    for index, patron in ipairs(line) do
        if patron.slot ~= index then
            patron.slot = index
            walkToSlot(patron)
        end

        Dui.send(patron.dui, { type = 'order', next = index == 1 })
    end
end

---@param patron HotdogPatron
---@param mood 'happy' | 'angry' | 'lost'
local function release(patron, mood)
    for index, queued in ipairs(line) do
        if queued == patron then
            table.remove(line, index)
            break
        end
    end

    Dui.destroy(patron.dui)
    sendOff(patron.ped, mood, context and context.config.kitchen.models.hotdog or 'prop_cs_hotdog_01')
    reslot()
end

---@param ped integer
---@return boolean
local function pedestrian(ped)
    if IsPedAPlayer(ped) or not IsPedHuman(ped) then return false end
    if IsPedDeadOrDying(ped, true) or not IsPedOnFoot(ped) then return false end
    if not AMBIENT_POPULATION[GetEntityPopulationType(ped)] then return false end

    return not SKIPPED_PED_TYPES[GetPedType(ped)]
end

---@param origin vector3
---@param radius number
---@return integer count
---@return integer[] candidates peds this client controls that can be called over
local function survey(origin, radius)
    local count, candidates = 0, {}

    for _, ped in ipairs(GetGamePool('CPed')) do
        if pedestrian(ped) and #(GetEntityCoords(ped) - origin) <= radius then
            count += 1

            if not recruited[ped] and NetworkHasControlOfEntity(ped) and not IsEntityAMissionEntity(ped) then
                candidates[#candidates + 1] = ped
            end
        end
    end

    return count, candidates
end

---@param ped integer
---@param customer HotdogCustomerView
local function welcome(ped, customer)
    recruited[ped] = true

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)

    ---@type HotdogPatron
    local patron <const> = {
        id = customer.id,
        ped = ped,
        order = customer.order,
        patience = customer.patience,
        state = 'walking',
        since = GetGameTimer(),
        slot = #line + 1,
        dui = Dui.create('order', DUI_WIDTH, DUI_HEIGHT, { order = customer.order, next = #line == 0, patience = 1 }),
    }

    line[#line + 1] = patron
    walkToSlot(patron)
    PlaySoundFrontend(-1, 'Paper_Shuffle', 'DLC_HEIST_PLANNING_BOARD_SOUNDS', true)
end

local function scan()
    local active <const> = context --[[@as CustomerContext]]
    local config <const> = active.config
    local spec <const> = config.customers

    if #line >= spec.maxQueue then return end

    local origin <const> = GetEntityCoords(active.cart)

    if #(GetEntityCoords(cache.ped) - origin) > spec.ownerRange then return end

    local count <const>, candidates <const> = survey(origin, spec.radius)

    if #candidates == 0 or math.random() >= Hotdog.customerChance(config, count, active.rep) then return end

    local ped <const> = candidates[math.random(1, #candidates)]
    local customer <const> = lib.callback.await('cobalt_cityhall:hotdog:recruit', false) --[[@as HotdogCustomerView?]]

    if customer and context and DoesEntityExist(ped) then
        welcome(ped, customer)
    elseif customer then
        lib.callback.await('cobalt_cityhall:hotdog:leave', false, customer.id, false)
    end
end

---@param ped integer
---@return boolean
local function killedByMe(ped)
    if not DoesEntityExist(ped) then return false end

    local killer <const> = GetPedSourceOfDeath(ped)

    return killer ~= 0 and (killer == cache.ped or killer == cache.vehicle)
end

---@param patron HotdogPatron
---@param now integer
local function think(patron, now)
    if not DoesEntityExist(patron.ped) or IsPedDeadOrDying(patron.ped, true) then
        local rep <const> = lib.callback.await('cobalt_cityhall:hotdog:leave', false, patron.id, killedByMe(patron.ped) and 'killed' or nil)

        if rep and context then
            context.rep = rep
            core:Notify(('Word gets around that you killed a customer. Street rep %d'):format(rep), 'error')
        end

        return release(patron, 'lost')
    end

    local spec <const> = (context --[[@as CustomerContext]]).config.customers

    if patron.state == 'walking' then
        local coords <const>, heading <const> = slotSpot(patron.slot)

        local gap <const> = #(GetEntityCoords(patron.ped).xy - coords.xy)
        local stopped <const> = gap <= SETTLE_RANGE and GetEntitySpeed(patron.ped) < STOPPED_SPEED

        if gap <= ARRIVE_RANGE or stopped then
            patron.state, patron.since = 'waiting', now

            SetEntityHeading(patron.ped, heading)
            TaskStartScenarioInPlace(patron.ped, spec.idle, 0, true)
        elseif now - patron.since > spec.walkMs then
            lib.callback.await('cobalt_cityhall:hotdog:leave', false, patron.id, false)
            release(patron, 'lost')
        end

        return
    end

    local waited <const> = now - patron.since

    Dui.send(patron.dui, { type = 'patience', patience = math.max(0, 1 - waited / patron.patience) })

    if waited < patron.patience then return end

    local rep <const> = lib.callback.await('cobalt_cityhall:hotdog:leave', false, patron.id, 'walkout')

    if rep then
        context.rep = rep
        core:Notify(('A customer got tired of waiting and walked off. Street rep %d'):format(rep), 'error')
    end

    release(patron, 'angry')
end

local function draw()
    while context and #line > 0 do
        for _, patron in ipairs(line) do
            if DoesEntityExist(patron.ped) then
                local head <const> = GetPedBoneCoords(patron.ped, HEAD_BONE, 0.0, 0.0, 0.0)

                Dui.draw(patron.dui, head + vec3(0.0, 0.0, ABOVE_HEAD))
            end
        end

        Wait(0)
    end
end

local function run()
    local drawing = false
    local nextScan = 0

    while context do
        local now <const> = GetGameTimer()

        if now >= nextScan then
            nextScan = now + context.config.customers.scanMs
            scan()
        end

        for i = #line, 1, -1 do
            if context and line[i] then think(line[i], now) end
        end

        if not drawing and #line > 0 then
            drawing = true
            CreateThread(function()
                draw()
                drawing = false
            end)
        end

        Wait(THINK_MS)
    end
end

---@param config StandConfig
---@param cart integer
---@param rep integer
function Customers.start(config, cart, rep)
    if context then return end

    context = { config = config, cart = cart, rep = rep }
    CreateThread(run)
end

---@param mood? 'angry' | 'lost'
function Customers.stop(mood)
    context = nil

    for i = #line, 1, -1 do
        local patron <const> = line[i]

        line[i] = nil
        Dui.destroy(patron.dui)
        sendOff(patron.ped, mood or 'lost', 'prop_cs_hotdog_01')
    end
end

---@param rep integer
function Customers.setRep(rep)
    if context then context.rep = rep end
end

---@return HotdogPatron?
function Customers.front()
    local patron <const> = line[1]

    if patron and patron.state == 'waiting' then return patron end
end

---@param result HotdogServeResult
function Customers.served(result)
    local patron <const> = line[1]

    if context then context.rep = result.rep end
    if patron then release(patron, result.paid > 0 and 'happy' or 'angry') end
end

---@return boolean
function Customers.active()
    return context ~= nil
end

RegisterNetEvent('cobalt_cityhall:hotdog:walkedOff', function(id, rep)
    for _, patron in ipairs(line) do
        if patron.id == id then
            if context then context.rep = rep end

            core:Notify(('A customer got tired of waiting and walked off. Street rep %d'):format(rep), 'error')

            return release(patron, 'angry')
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, patron in ipairs(line) do
        Dui.destroy(patron.dui)
        leaving[patron.ped] = leaving[patron.ped] or false
    end

    for ped in pairs(leaving) do letGo(ped) end
end)

return Customers
