local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Payout <const> = require 'server.payout'
local Vehicles <const> = require 'server.vehicles'
local Jobs <const> = require 'shared.jobs'

local ZONE_SLACK <const> = 10.0
local BIN_REACH <const> = 4.0
local BIN_SPACING <const> = 1.5
local AT_VEHICLE <const> = 7.0
local CHAIN_START_CHOICES <const> = 4
local HOPPER_RANGE <const> = 20.0

---@class CollectTask
---@field zones integer[]
---@field at integer
---@field bins integer
---@field used vector3[]
---@field hopper? integer the crew vehicle whose back is open

---@param collect CollectConfig
---@param from vector3
---@param skip? integer the zone just cleared
---@return integer[]
local function pickZones(collect, from, skip)
    local order <const> = {}

    for index in ipairs(collect.zones) do
        if index ~= skip then order[#order + 1] = index end
    end

    table.sort(order, function(a, b)
        return #(collect.zones[a].coords - from) < #(collect.zones[b].coords - from)
    end)

    local first <const> = table.remove(order, math.random(1, math.min(CHAIN_START_CHOICES, #order)))
    local picked <const> = { first }

    while #picked < collect.length and #order > 0 do
        local last <const> = collect.zones[picked[#picked]].coords

        table.sort(order, function(a, b)
            return #(collect.zones[a].coords - last) < #(collect.zones[b].coords - last)
        end)

        picked[#picked + 1] = table.remove(order, 1)
    end

    return picked
end

---@param shift Shift
---@return CollectZone
local function currentZone(shift)
    local task <const> = shift.task --[[@as CollectTask]]

    return shift.def.collect.zones[task.zones[task.at]]
end

---@param task CollectTask
---@param coords vector3
---@return boolean
local function binUsed(task, coords)
    for _, used in ipairs(task.used) do
        if #(used - coords) < BIN_SPACING then return true end
    end

    return false
end

---@param task CollectTask
---@return boolean closed
local function closeHopper(task)
    local vehicle <const> = task.hopper

    if not vehicle then return false end

    task.hopper = nil

    if DoesEntityExist(vehicle) then Vehicles.setRearDoors(vehicle, false) end

    return true
end

---@param task CollectTask
---@param vehicle integer?
---@return boolean
local function hopperOpen(task, vehicle)
    return vehicle ~= nil and task.hopper == vehicle and DoesEntityExist(vehicle)
end

---@param zone CollectZone
---@param collect CollectConfig
---@return integer
local function zonePay(zone, collect)
    return zone.pay or collect.pay.perBin * collect.bins
end

local Collect <const> = {}

---@param shift Shift
function Collect.assign(shift)
    local task <const> = shift.task --[[@as CollectTask]]

    closeHopper(task)

    local last <const> = task.zones and task.zones[#task.zones]
    local from <const> = last and shift.def.collect.zones[last].coords or shift.def.site.coords.xyz

    task.zones = pickZones(shift.def.collect, from, last)
    task.at = 1
    task.bins = 0
    task.used = {}
end

---@param shift Shift
---@return TaskView
function Collect.view(shift)
    local task <const> = shift.task --[[@as CollectTask]]
    local collect <const> = shift.def.collect --[[@as CollectConfig]]
    local zone <const> = currentZone(shift)

    return {
        title = ('Clear the bins in %s'):format(zone.label),
        label = zone.label,
        coords = zone.coords,
        radius = zone.radius,
        step = ('Area %d of %d, bin %d of %d'):format(task.at, #task.zones, task.bins + 1, collect.bins),
        stage = shift.bag and 'throw' or 'bin',
        progress = { done = task.bins, total = collect.bins },
        open = hopperOpen(task, task.hopper) or nil,
    }
end

---@param shift Shift
---@param coords unknown
---@return integer? duration
---@return string? reason
local function beginBin(shift, coords)
    local task <const> = shift.task --[[@as CollectTask]]
    local collect <const> = shift.def.collect --[[@as CollectConfig]]
    local zone <const> = currentZone(shift)

    if type(coords) ~= 'vector3' then return end
    if shift.bag then return nil, ('Throw your bag into the %s first'):format(shift.def.vehicle.label) end

    if #(coords.xy - zone.coords.xy) > zone.radius + ZONE_SLACK then
        return nil, ('This bin is outside %s. Use the bins inside the circle.'):format(zone.label)
    end

    if not Registry.near(shift.src, coords, BIN_REACH) then return nil, 'Get closer to the bin' end
    if binUsed(task, coords) then return nil, 'This bin is already empty' end

    if not Vehicles.crewHasVehicle(shift) then
        return nil, ('Take a %s from the clerk at %s first'):format(shift.def.vehicle.label, shift.def.site.label)
    end

    if not Vehicles.crewVehicleNear(shift, coords, collect.truckWithin) then
        return nil, ('Bring the %s closer to this bin'):format(shift.def.vehicle.label)
    end

    local duration <const> = Jobs.rollDuration(collect.empty.duration)

    shift.binAt = coords

    Registry.startAction(shift, 'bin', duration)

    return duration
end

---@param shift Shift
---@return integer? duration
---@return string? reason
local function beginThrow(shift)
    local collect <const> = shift.def.collect --[[@as CollectConfig]]

    local label <const> = shift.def.vehicle.label

    if not shift.bag then return nil, 'Empty a bin first' end

    local vehicle <const> = Vehicles.nearestCrewVehicle(shift, Registry.coords(shift.src), AT_VEHICLE)

    if not vehicle then return nil, ('Stand at the back of the %s'):format(label) end
    if not hopperOpen(shift.task, vehicle) then return nil, ('Open the back of the %s first'):format(label) end

    local duration <const> = Jobs.rollDuration(collect.throw.duration)

    Registry.startAction(shift, 'throw', duration)

    return duration
end

---@param shift Shift
---@return integer? duration
---@return string? reason
local function beginOpen(shift)
    local collect <const> = shift.def.collect --[[@as CollectConfig]]
    local label <const> = shift.def.vehicle.label
    local vehicle <const> = Vehicles.nearestCrewVehicle(shift, Registry.coords(shift.src), AT_VEHICLE)

    if not vehicle then return nil, ('Stand at the back of the %s'):format(label) end
    if hopperOpen(shift.task, vehicle) then return nil, ('The back of the %s is already open'):format(label) end

    local duration <const> = Jobs.rollDuration(collect.open.duration)

    shift.openAt = vehicle

    Registry.startAction(shift, 'open', duration)

    return duration
end

---@param shift Shift
---@param target { type: string, coords?: vector3 }
---@return integer? duration
---@return string? reason
function Collect.begin(shift, target)
    if target.type == 'bin' then return beginBin(shift, target.coords) end
    if target.type == 'throw' then return beginThrow(shift) end
    if target.type == 'open' then return beginOpen(shift) end
end

---@param shift Shift
---@return boolean
local function finishBin(shift)
    local task <const> = shift.task --[[@as CollectTask]]
    local coords <const> = shift.binAt

    shift.binAt = nil

    if not Registry.endAction(shift, 'bin') or not coords then return false end
    if shift.bag or binUsed(task, coords) then return false end
    if not Registry.near(shift.src, coords, BIN_REACH) then return false end

    task.used[#task.used + 1] = coords
    shift.bag = true

    local label <const> = shift.def.vehicle.label
    local text = ('Bag ready. Throw it into the back of the %s.'):format(label)

    if not task.hopper then text = ('Bag ready. Open the back of the %s, then throw it in.'):format(label) end

    Registry.notify(shift.src, text, 'success')

    return true
end

---@param shift Shift
---@return boolean
local function finishOpen(shift)
    local vehicle <const> = shift.openAt

    shift.openAt = nil

    if not Registry.endAction(shift, 'open') or not vehicle then return false end
    if not DoesEntityExist(vehicle) then return false end
    if Vehicles.nearestCrewVehicle(shift, Registry.coords(shift.src), AT_VEHICLE) ~= vehicle then return false end

    local task <const> = shift.task --[[@as CollectTask]]

    closeHopper(task)

    task.hopper = vehicle

    Vehicles.setRearDoors(vehicle, true)

    return true
end

---@param shift Shift
---@param zone CollectZone
local function finishZone(shift, zone)
    local task <const> = shift.task --[[@as CollectTask]]
    local collect <const> = shift.def.collect --[[@as CollectConfig]]

    if task.bins < collect.bins or #task.used < collect.bins then return end

    local amount <const> = zonePay(zone, collect)
    local paid <const> = {}

    for _, member in ipairs(Registry.crewShifts(shift)) do
        if Registry.nearFlat(member.src, zone.coords, zone.radius + config.crew.shareRange) then
            paid[#paid + 1] = member
        end
    end

    task.at += 1
    task.bins = 0
    task.used = {}

    closeHopper(task)

    Payout.split(paid, amount, ('%s cleared'):format(zone.label))

    if task.at <= #task.zones then
        local text <const> = ('%s is clear. Drive to %s next.'):format(zone.label, currentZone(shift).label)

        return Registry.notifyCrew(shift, text, 'success')
    end

    Payout.split(paid, collect.pay.routeBonus, 'route finished')

    Collect.assign(shift)

    local text <const> = ('Route finished. The next one starts in %s.'):format(currentZone(shift).label)

    Registry.notifyCrew(shift, text, 'success')
end

---@param shift Shift
---@return boolean
local function finishThrow(shift)
    local task <const> = shift.task --[[@as CollectTask]]
    local collect <const> = shift.def.collect --[[@as CollectConfig]]
    local zone <const> = currentZone(shift)

    if not Registry.endAction(shift, 'throw') then return false end
    if not shift.bag then return false end
    if not Vehicles.crewVehicleNear(shift, Registry.coords(shift.src), AT_VEHICLE) then return false end

    if not hopperOpen(task, Vehicles.nearestCrewVehicle(shift, Registry.coords(shift.src), AT_VEHICLE)) then
        return false
    end

    shift.bag = false
    task.bins += 1
    shift.done += 1

    if task.bins >= collect.bins then
        finishZone(shift, zone)

        return true
    end

    local left <const> = collect.bins - task.bins

    Registry.notifyCrew(shift, ('%d more %s in %s.'):format(left, left == 1 and 'bin' or 'bins', zone.label))

    return true
end

---@param shift Shift
---@param target { type: string }
---@return boolean
function Collect.finish(shift, target)
    if target.type == 'bin' then return finishBin(shift) end
    if target.type == 'throw' then return finishThrow(shift) end
    if target.type == 'open' then return finishOpen(shift) end

    return false
end

---@param shift Shift
---@return boolean changed
function Collect.tick(shift)
    local task <const> = shift.task --[[@as CollectTask]]
    local vehicle <const> = task.hopper

    if not vehicle then return false end

    if DoesEntityExist(vehicle) then
        local coords <const> = GetEntityCoords(vehicle)

        for _, member in ipairs(Registry.crewShifts(shift)) do
            if Registry.near(member.src, coords, HOPPER_RANGE) then return false end
        end
    end

    return closeHopper(task)
end

---@param shift Shift
---@param why LossReason
---@return string? lost what the player lost, as a sentence
function Collect.reset(shift, why)
    shift.binAt = nil
    shift.openAt = nil

    if why == 'vehicle' then closeHopper(shift.task) end

    if why ~= 'down' or not shift.bag then return end

    shift.bag = false

    return 'You dropped the trash bag.'
end

return Collect
