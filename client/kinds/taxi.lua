local Work <const> = require 'client.work'

local SPAWN_DISTANCE <const> = 60.0
local BOARD_DISTANCE <const> = 12.0
local STOPPED_SPEED <const> = 1.0
local REAR_RIGHT_SEAT <const> = 2
local BOARD_TIMEOUT_MS <const> = 20000
local LEAVE_DESPAWN_MS <const> = 15000
local LEAVE_TIMEOUT_MS <const> = 5000
local PAVEMENT_ONLY <const> = 16
local PAVEMENT_SNAP <const> = 3.0
local FARE_WAITING <const> = 'Your fare is waiting. Stop next to them and they will get in.'

---@type JobDefinition
local def
---@type integer?
local passenger
---@type CPoint?
local point
---@type string?
local watching
local acting = false

---@return integer? vehicle the cab the player drives, when it is stopped
local function stoppedCab()
    local vehicle <const> = cache.vehicle

    if not vehicle or cache.seat ~= -1 then return end
    if GetEntitySpeed(vehicle) > STOPPED_SPEED then return end

    return vehicle
end

local function dismissPassenger()
    local ped <const> = passenger

    passenger = nil

    if not ped or not DoesEntityExist(ped) then return end

    CreateThread(function()
        local vehicle <const> = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 then
            local deadline <const> = GetGameTimer() + LEAVE_TIMEOUT_MS

            TaskLeaveVehicle(ped, vehicle, 0)

            while IsPedInAnyVehicle(ped, false) and GetGameTimer() < deadline do Wait(250) end
        end

        TaskWanderStandard(ped, 10.0, 10)
        Wait(LEAVE_DESPAWN_MS)
        Work.delete(ped)
    end)
end

local function clearPoint()
    if point then point:remove() end
    point, watching = nil, nil
end

---Snaps the waiting spot onto the nearest pavement the game knows, when one is close by.
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
local function spawnPassenger(task)
    local models <const> = def.taxi.passengers

    passenger = Work.spawnPed(models[math.random(1, #models)], pavementSpot(task.passenger or vec4(task.coords.x, task.coords.y, task.coords.z, 0.0)))

    if not passenger then return end

    FreezeEntityPosition(passenger, false)
    TaskStartScenarioInPlace(passenger, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
end

---@param vehicle integer
local function board(vehicle)
    acting = true

    CreateThread(function()
        local ped <const> = passenger --[[@as integer]]
        local deadline <const> = GetGameTimer() + BOARD_TIMEOUT_MS

        ClearPedTasks(ped)
        TaskEnterVehicle(ped, vehicle, BOARD_TIMEOUT_MS, REAR_RIGHT_SEAT, 1.0, 1, 0)

        while not IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do Wait(250) end

        if IsPedInVehicle(ped, vehicle, false) then Work.finish({ stage = 'pickup' }) end

        acting = false
    end)
end

local function alight()
    acting = true

    CreateThread(function()
        if Work.finish({ stage = 'dropoff' }) then
            dismissPassenger()
        else
            exports.cobalt_core:Notify("Your fare isn't getting out yet. Pull up in your cab and stop again.", 'error')
        end

        acting = false
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

                    if passenger then exports.cobalt_core:Notify(FARE_WAITING, 'inform') end

                    acting = false
                end)

                return
            end

            if self.currentDistance > BOARD_DISTANCE then return end

            local vehicle <const> = stoppedCab()

            if vehicle then board(vehicle) end
        end,
    })
end

---@param task TaskView
local function watchDropoff(task)
    local armed = true

    point = lib.points.new({
        coords = task.coords,
        distance = task.radius,
        onEnter = function()
            exports.cobalt_core:Notify('Stop the cab here to let your fare out.', 'inform')
        end,
        nearby = function()
            if acting then return end

            if not stoppedCab() then
                armed = true

                return
            end

            if not armed then return end

            armed = false
            alight()
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

    if task.stage == 'pickup' then
        dismissPassenger()
        watchPickup(task)
    else
        watchDropoff(task)
    end
end

function Taxi.leave()
    clearPoint()
    dismissPassenger()
end

return Taxi
