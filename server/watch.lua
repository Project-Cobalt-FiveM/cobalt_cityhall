local Registry <const> = require 'server.registry'
local Shifts <const> = require 'server.shifts'
local Vehicles <const> = require 'server.vehicles'
local Props <const> = require 'server.props'

local CHECK_MS <const> = 5000
local ABANDON_RANGE <const> = 150.0
local ABANDON_SECONDS <const> = 180
---@type string
local ANY_BAG <const> = nil

---@param shift Shift
---@return boolean
local function crewNearVehicle(shift)
    local coords <const> = GetEntityCoords(shift.vehicle)

    for _, member in ipairs(Registry.crewShifts(shift)) do
        if Registry.near(member.src, coords, ABANDON_RANGE) then return true end
    end

    return false
end

---@param shift Shift
local function checkAbandoned(shift)
    if crewNearVehicle(shift) then
        shift.awaySince = nil
        return
    end

    local label <const> = shift.def.vehicle.label

    if not shift.awaySince then
        shift.awaySince = os.time()

        local minutes <const> = ABANDON_SECONDS // 60
        local text <const> = ('Get back to your %s within %d minutes or it goes back to the depot.'):format(label, minutes)

        return Registry.notify(shift.src, text, 'error')
    end

    if os.time() - shift.awaySince < ABANDON_SECONDS then return end

    Shifts.loseVehicle(shift, ('You left your %s too long, so it went back to the depot.'):format(label))
end

---@param shift Shift
local function checkVehicle(shift)
    if not shift.vehicle then return end

    if not DoesEntityExist(shift.vehicle) then
        return Shifts.loseVehicle(shift, ('Your %s is gone.'):format(shift.def.vehicle.label))
    end

    checkAbandoned(shift)
end

CreateThread(function()
    while true do
        Wait(CHECK_MS)

        for _, shift in pairs(Registry.shifts) do
            checkVehicle(shift)

            local tick <const> = Shifts.kind(shift).tick

            if tick and tick(shift) then Shifts.sync(shift) end
        end
    end
end)

lib.callback.register('cobalt_cityhall:vehicleWrecked', function(src)
    local shift <const> = Registry.get(src)

    if not shift or not Vehicles.has(shift) then return end

    Shifts.loseVehicle(shift, ('Your %s is wrecked.'):format(shift.def.vehicle.label))
end)

AddStateBagChangeHandler('revive', ANY_BAG, function(bagName, _, value)
    if not value or value.state == 'alive' or value.state == 'reviving' then return end

    local src <const> = GetPlayerFromStateBagName(bagName)
    local shift <const> = src ~= 0 and Registry.get(src)

    if not shift then return end

    shift.pending = nil

    Props.release(src)

    Vehicles.closeDoors(shift)

    local reset <const> = Shifts.kind(shift).reset
    local lost <const> = reset and reset(shift, 'down')

    if not lost then return end

    Registry.notify(src, lost, 'error')
    Shifts.sync(shift)
end)
