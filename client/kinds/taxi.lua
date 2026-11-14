local Work <const> = require 'client.work'

local SPAWN_DISTANCE <const> = 60.0
local STOPPED_SPEED <const> = 1.5
local STILL_MS <const> = 400
local RETRY_MS <const> = 2500
local FARE_SEATS <const> = { 2, 1, 0 }
local BOARD_SPEED <const> = 2.0
local BOARD_TIMEOUT_MS <const> = 15000
local LEAVE_TIMEOUT_MS <const> = 6000
local WARP_OUT <const> = 16
local WALK_TIMEOUT_MS <const> = 8000
local WALK_REACHED <const> = 1.0
local LEAVE_DESPAWN_MS <const> = 15000
local PAVEMENT_ONLY <const> = 16
local PAVEMENT_SNAP <const> = 3.0

---@type JobDefinition
local def
---@type integer?
local passenger
---@type CPoint?
local point
---@type string?
local watching
---@type integer? the cab held still while a fare gets in or out
local held
---@type integer? when the cab came to a stop at the current point
local stillSince
local retryAt = 0
local acting = false
---@type table<integer, true> fares walking away after their ride
local leaving <const> = {}

---@param vehicle integer
local function holdCab(vehicle)
    held = vehicle

    SetVehicleHandbrake(vehicle, true)
    FreezeEntityPosition(vehicle, true)
end

local function releaseCab()
    local vehicle <const> = held

    held = nil

    if not vehicle or not DoesEntityExist(vehicle) then return end

    FreezeEntityPosition(vehicle, false)
    SetVehicleHandbrake(vehicle, false)
end

---@return integer? vehicle the cab the player drives, once it has stood nearly still for a moment
local function stoppedCab()
    local vehicle <const> = cache.vehicle

    if not vehicle or cache.seat ~= -1 or GetEntitySpeed(vehicle) > STOPPED_SPEED then
        stillSince = nil
        return
    end

    local now <const> = GetGameTimer()

    stillSince = stillSince or now

    if now - stillSince < STILL_MS or now < retryAt then return end

    return vehicle
end

---Snaps a spot onto the nearest pavement the game knows, when one is close by.
---@param spot vector4
---@return vector4
local function pavementSpot(spot)
    local found <const>, safe <const> = GetSafeCoordForPed(spot.x, spot.y, spot.z, true, PAVEMENT_ONLY)

    if found and #(safe - spot.xyz) <= PAVEMENT_SNAP then
        return vec4(safe.x, safe.y, safe.z, spot.w)
    end

    return spot
end

---@param task TaskView
---@return vector4
local function waitingSpot(task)
    return pavementSpot(task.passenger or vec4(task.coords.x, task.coords.y, task.coords.z, 0.0))
end

---@param ped integer
---@param vehicle integer
local function stepOut(ped, vehicle)
    local deadline <const> = GetGameTimer() + LEAVE_TIMEOUT_MS

    TaskLeaveVehicle(ped, vehicle, 0)

    while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do Wait(100) end

    if IsPedInVehicle(ped, vehicle, false) then TaskLeaveVehicle(ped, vehicle, WARP_OUT) end
end

---@param ped integer
---@param spot vector4
local function walkTo(ped, spot)
    local deadline <const> = GetGameTimer() + WALK_TIMEOUT_MS

    TaskGoStraightToCoord(ped, spot.x, spot.y, spot.z, 1.0, WALK_TIMEOUT_MS, spot.w, 0.5)

    while DoesEntityExist(ped) and #(GetEntityCoords(ped) - spot.xyz) > WALK_REACHED and GetGameTimer() < deadline do
        Wait(250)
    end
end

---@param ped integer
---@param spot? vector4 the pavement the fare walks to before wandering off
local function walkAway(ped, spot)
    if spot then walkTo(ped, spot) end
    if DoesEntityExist(ped) then TaskWanderStandard(ped, 10.0, 10) end

    Wait(LEAVE_DESPAWN_MS)

    leaving[ped] = nil
    Work.delete(ped)
end

local function dismissPassenger()
    local ped <const> = passenger

    passenger = nil

    if not ped or not DoesEntityExist(ped) then return end

    leaving[ped] = true

    CreateThread(function()
        local vehicle <const> = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 then stepOut(ped, vehicle) end

        walkAway(ped)
    end)
end

local function clearPoint()
    if point then point:remove() end

    point, watching, stillSince = nil, nil, nil
end

---@param task TaskView
local function spawnPassenger(task)
    local models <const> = def.taxi.passengers

    passenger = Work.spawnPed(models[math.random(1, #models)], waitingSpot(task))

    if not passenger then return end

    FreezeEntityPosition(passenger, false)
    TaskStartScenarioInPlace(passenger, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
end

---@param vehicle integer
---@return integer seat the first free rear seat, then the front passenger seat
local function fareSeat(vehicle)
    for _, seat in ipairs(FARE_SEATS) do
        if IsVehicleSeatFree(vehicle, seat) then return seat end
    end

    return FARE_SEATS[1]
end

---@param ped integer
---@param vehicle integer
---@return boolean
local function boarding(ped, vehicle)
    return DoesEntityExist(ped) and cache.vehicle == vehicle and not IsPedInVehicle(ped, vehicle, false)
end

---@param ped integer
---@param vehicle integer
local function getIn(ped, vehicle)
    local deadline <const> = GetGameTimer() + BOARD_TIMEOUT_MS

    ClearPedTasks(ped)
    TaskEnterVehicle(ped, vehicle, BOARD_TIMEOUT_MS, fareSeat(vehicle), BOARD_SPEED, 1, 0)

    while boarding(ped, vehicle) and GetGameTimer() < deadline do Wait(100) end

    if boarding(ped, vehicle) then SetPedIntoVehicle(ped, vehicle, fareSeat(vehicle)) end
end

---@param vehicle integer
local function board(vehicle)
    acting = true

    CreateThread(function()
        local ped <const> = passenger --[[@as integer]]

        holdCab(vehicle)

        if not IsPedInVehicle(ped, vehicle, false) then getIn(ped, vehicle) end

        releaseCab()

        if not IsPedInVehicle(ped, vehicle, false) or not Work.finish({ stage = 'pickup' }) then
            retryAt = GetGameTimer() + RETRY_MS
        end

        acting = false
    end)
end

---@param vehicle integer
---@param task TaskView
---@param warn fun()
local function alight(vehicle, task, warn)
    local stop <const> = watching
    local ped <const> = passenger

    acting = true
    passenger = nil

    CreateThread(function()
        holdCab(vehicle)

        local paid <const> = Work.finish({ stage = 'dropoff' })
        local riding <const> = ped ~= nil and DoesEntityExist(ped)

        if paid and riding then
            leaving[ped] = true

            stepOut(ped, vehicle)
        end

        releaseCab()
        acting = false

        if not paid then
            passenger = ped

            if watching ~= stop then
                dismissPassenger()
                return
            end

            retryAt = GetGameTimer() + RETRY_MS

            return warn()
        end

        if riding then walkAway(ped, waitingSpot(task)) end
    end)
end

---@param task TaskView
local function watchPickup(task)
    point = lib.points.new({
        coords = task.coords,
        distance = SPAWN_DISTANCE,
        nearby = function(self)
            if acting or cache.seat ~= -1 then return end

            if not passenger then
                acting = true

                CreateThread(function()
                    spawnPassenger(task)

                    if passenger then exports.cobalt_core:Notify(locale('taxi.fare_waiting'), 'inform') end

                    acting = false
                end)

                return
            end

            if self.currentDistance > task.radius then return end

            local vehicle <const> = stoppedCab()

            if vehicle then board(vehicle) end
        end,
    })
end

---@param task TaskView
local function watchDropoff(task)
    local warned = false

    local function warn()
        if warned then return end

        warned = true
        exports.cobalt_core:Notify(locale('taxi.not_out'), 'error')
    end

    point = lib.points.new({
        coords = task.coords,
        distance = task.radius,
        onEnter = function()
            exports.cobalt_core:Notify(locale('taxi.stop_here'), 'inform')
        end,
        nearby = function()
            if acting then return end

            local vehicle <const> = stoppedCab()

            if vehicle then alight(vehicle, task, warn) end
        end,
    })
end

local Taxi <const> = {}

---@param job JobDefinition
function Taxi.enter(job)
    def = job
end

---@param _ JobDefinition
---@param view ShiftView
function Taxi.update(_, view)
    local task <const> = view.task

    if not task then return clearPoint() end

    local id <const> = ('%s:%s'):format(task.stage, task.label)

    if watching == id then return end

    clearPoint()
    watching = id
    retryAt = 0

    if task.stage == 'pickup' then
        dismissPassenger()
        watchPickup(task)
    else
        watchDropoff(task)
    end
end

function Taxi.leave()
    clearPoint()
    releaseCab()
    dismissPassenger()

    for ped in pairs(leaving) do Work.delete(ped) end

    table.wipe(leaving)
end

return Taxi
