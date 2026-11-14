local Registry <const> = require 'server.registry'

local SPAWN_CLEARANCE <const> = 3.0
local OWNER_WAIT_MS <const> = 3000

local Vehicles <const> = {}

---@param coords vector4
---@return boolean
local function spawnClear(coords)
    for _, vehicle in ipairs(GetAllVehicles() --[[@as integer[] ]]) do
        if #(GetEntityCoords(vehicle) - coords.xyz) < SPAWN_CLEARANCE then return false end
    end

    return true
end

---@param shift Shift
---@param holders Shift[]
local function grantKeys(shift, holders)
    for _, holder in ipairs(holders) do
        exports.cobalt_vehiclekeys:GiveKey(holder.src, shift.plate, shift.vehicle)
    end
end

---@param vehicle integer
local function settle(vehicle)
    CreateThread(function()
        local deadline <const> = GetGameTimer() + OWNER_WAIT_MS

        while DoesEntityExist(vehicle) and NetworkGetEntityOwner(vehicle) == -1 and GetGameTimer() < deadline do
            Wait(100)
        end

        if not DoesEntityExist(vehicle) then return end

        local owner <const> = NetworkGetEntityOwner(vehicle)

        if owner == -1 then return end

        TriggerClientEvent('cobalt_cityhall:settle', owner, NetworkGetNetworkIdFromEntity(vehicle))
    end)
end

---@param shift Shift
---@return boolean
function Vehicles.has(shift)
    return shift.vehicle ~= nil and DoesEntityExist(shift.vehicle)
end

---@param shift Shift
---@return boolean ok
---@return string? reason
function Vehicles.take(shift)
    local spec <const> = shift.def.vehicle

    if not spec then return false, 'This job has no vehicle' end
    if Vehicles.has(shift) then return false, ('Your %s is already out'):format(spec.label) end

    local spawn

    for _, coords in ipairs(spec.spawns) do
        if spawnClear(coords) then
            spawn = coords
            break
        end
    end

    if not spawn then return false, 'Every bay is blocked. Move the vehicles out of the way.' end

    local vehicle <const> = exports.cobalt_core:SpawnVehicle(shift.src, spec.model, spawn, false, 'automobile')

    if not vehicle then return false, 'The vehicle failed to spawn. Try again.' end

    shift.vehicle = vehicle
    shift.plate = ('%s%03d'):format(spec.plate, math.random(0, 999))
    shift.awaySince = nil

    SetVehicleNumberPlateText(vehicle, shift.plate)
    Entity(vehicle).state:set('cobalt_cityhall:owner', shift.src, true)
    grantKeys(shift, Registry.crewShifts(shift))
    settle(vehicle)

    return true
end

---@param shift Shift
function Vehicles.release(shift)
    if shift.plate then exports.cobalt_vehiclekeys:RemoveKeys(shift.plate) end
    if Vehicles.has(shift) then DeleteEntity(shift.vehicle) end

    shift.vehicle = nil
    shift.plate = nil
    shift.awaySince = nil
end

---@param shift Shift
---@param member Shift
function Vehicles.shareKeys(shift, member)
    for _, holder in ipairs(Registry.crewShifts(shift)) do
        if holder.plate and Vehicles.has(holder) then
            exports.cobalt_vehiclekeys:GiveKey(member.src, holder.plate, holder.vehicle)
        end
    end
end

---@param leaver Shift
---@param others Shift[]
function Vehicles.splitKeys(leaver, others)
    for _, member in ipairs(others) do
        if leaver.plate then exports.cobalt_vehiclekeys:TakeKey(member.src, leaver.plate) end
        if member.plate then exports.cobalt_vehiclekeys:TakeKey(leaver.src, member.plate) end
    end
end

---@param shift Shift
---@return boolean
function Vehicles.crewHasVehicle(shift)
    for _, holder in ipairs(Registry.crewShifts(shift)) do
        if Vehicles.has(holder) then return true end
    end

    return false
end

---@param shift Shift
---@param coords vector3
---@param range number
---@return integer? vehicle the closest crew vehicle within range, measured on the ground plane
function Vehicles.nearestCrewVehicle(shift, coords, range)
    local nearest, best = nil, range

    for _, holder in ipairs(Registry.crewShifts(shift)) do
        if Vehicles.has(holder) then
            local distance <const> = #(GetEntityCoords(holder.vehicle).xy - coords.xy)

            if distance <= best then
                nearest, best = holder.vehicle, distance
            end
        end
    end

    return nearest
end

---@param shift Shift
---@param coords vector3
---@param range number
---@return boolean
function Vehicles.crewVehicleNear(shift, coords, range)
    return Vehicles.nearestCrewVehicle(shift, coords, range) ~= nil
end

---@param vehicle integer
---@param open boolean
function Vehicles.setRearDoors(vehicle, open)
    local owner <const> = NetworkGetEntityOwner(vehicle)

    if owner == -1 then return end

    TriggerClientEvent('cobalt_cityhall:rearDoors', owner, NetworkGetNetworkIdFromEntity(vehicle), open)
end

---@param shift Shift
---@param vehicle integer
function Vehicles.openDoors(shift, vehicle)
    shift.doorsOpen = vehicle

    Vehicles.setRearDoors(vehicle, true)
end

---@param shift Shift
function Vehicles.closeDoors(shift)
    local vehicle <const> = shift.doorsOpen

    shift.doorsOpen = nil

    if vehicle and DoesEntityExist(vehicle) then Vehicles.setRearDoors(vehicle, false) end
end

---@param shift Shift
---@return integer? vehicle the crew vehicle the player sits in
function Vehicles.crewVehicleOf(shift)
    local current <const> = GetVehiclePedIsIn(GetPlayerPed(shift.src), false)

    if current == 0 then return end

    for _, holder in ipairs(Registry.crewShifts(shift)) do
        if holder.vehicle == current then return current end
    end
end

return Vehicles
