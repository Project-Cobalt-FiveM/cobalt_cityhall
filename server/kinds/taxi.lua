local Registry <const> = require 'server.registry'
local Payout <const> = require 'server.payout'
local Vehicles <const> = require 'server.vehicles'

local STOP_RADIUS <const> = 10.0
local REACH_SLACK <const> = 8.0
local FASTEST_METERS_PER_SECOND <const> = 70.0

---@class TaxiTask
---@field stage 'pickup' | 'dropoff'
---@field pickup integer
---@field dropoff integer
---@field pickedAt? integer

---@param taxi TaxiConfig
---@param pickup integer
---@return integer
local function pickDropoff(taxi, pickup)
    local from <const> = taxi.stops[pickup].coords.xyz
    local options <const> = {}

    for index, stop in ipairs(taxi.stops) do
        if #(stop.coords.xyz - from) >= taxi.minTrip then options[#options + 1] = index end
    end

    return options[math.random(1, #options)]
end

---@param task TaxiTask
---@param taxi TaxiConfig
---@return TaxiStop
local function currentStop(task, taxi)
    return taxi.stops[task.stage == 'pickup' and task.pickup or task.dropoff]
end

local Taxi <const> = {}

---@param shift Shift
function Taxi.assign(shift)
    local task <const> = shift.task --[[@as TaxiTask]]
    local taxi <const> = shift.def.taxi --[[@as TaxiConfig]]
    local pickup

    repeat
        pickup = math.random(1, #taxi.stops)
    until pickup ~= task.dropoff

    task.stage = 'pickup'
    task.pickup = pickup
    task.dropoff = pickDropoff(taxi, pickup)
    task.pickedAt = nil
end

---@param shift Shift
---@return TaskView
function Taxi.view(shift)
    local task <const> = shift.task --[[@as TaxiTask]]
    local stop <const> = currentStop(task, shift.def.taxi)

    return {
        title = ('%s %s'):format(task.stage == 'pickup' and 'Pick up at' or 'Drop off at', stop.label),
        label = stop.label,
        coords = stop.coords.xyz,
        radius = STOP_RADIUS,
        step = task.stage == 'pickup' and 'Pick up the fare' or 'Drop off the fare',
        stage = task.stage,
        passenger = task.stage == 'pickup' and stop.passenger or nil,
    }
end

---@param shift Shift
---@param stage 'pickup' | 'dropoff'
---@return integer? vehicle
local function atStop(shift, stage)
    local task <const> = shift.task --[[@as TaxiTask]]

    if task.stage ~= stage then return end
    if not Registry.near(shift.src, currentStop(task, shift.def.taxi).coords, STOP_RADIUS + REACH_SLACK) then return end

    return Vehicles.crewVehicleOf(shift)
end

---@param shift Shift
---@param vehicle integer
---@return Shift[]
local function riders(shift, vehicle)
    local list <const> = {}

    for _, member in ipairs(Registry.crewShifts(shift)) do
        if member == shift or GetVehiclePedIsIn(GetPlayerPed(member.src), false) == vehicle then
            list[#list + 1] = member
        end
    end

    return list
end

---@param shift Shift
---@param target { stage: 'pickup' | 'dropoff' }
---@return boolean
function Taxi.finish(shift, target)
    local task <const> = shift.task --[[@as TaxiTask]]
    local taxi <const> = shift.def.taxi --[[@as TaxiConfig]]
    local vehicle <const> = atStop(shift, target.stage)

    if not vehicle then return false end

    if target.stage == 'pickup' then
        task.stage = 'dropoff'
        task.pickedAt = GetGameTimer()

        local text <const> = ('Fare on board. Drive them to %s.'):format(taxi.stops[task.dropoff].label)

        Registry.notifyCrew(shift, text, 'success')

        return true
    end

    local from <const> = taxi.stops[task.pickup].coords.xyz
    local to <const> = taxi.stops[task.dropoff].coords.xyz
    local meters <const> = #(to - from)

    if GetGameTimer() - task.pickedAt < meters / FASTEST_METERS_PER_SECOND * 1000 then return false end

    local crew <const> = riders(shift, vehicle)

    Payout.split(crew, taxi.base + taxi.perMeter * meters, taxi.stops[task.dropoff].label)

    for _, rider in ipairs(crew) do
        rider.done += 1
    end

    Taxi.assign(shift)
    Registry.notifyCrew(shift, ('Next fare is waiting at %s.'):format(taxi.stops[task.pickup].label))

    return true
end

---@param shift Shift
---@return string? lost what the crew lost, as a sentence
function Taxi.reset(shift)
    local task <const> = shift.task --[[@as TaxiTask]]

    if task.stage ~= 'dropoff' then return end

    Taxi.assign(shift)

    return ('Your fare got out and left. Next fare is at %s.'):format(shift.def.taxi.stops[task.pickup].label)
end

return Taxi
