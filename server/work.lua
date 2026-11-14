local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Shifts <const> = require 'server.shifts'
local Vehicles <const> = require 'server.vehicles'
local Gather <const> = require 'server.kinds.gather'

local SITE_SLACK <const> = 3.0

lib.callback.register('cobalt_cityhall:begin', function(src, target)
    local shift <const> = Registry.get(src)
    local begin <const> = shift and Shifts.kind(shift).begin

    if not shift or not begin or type(target) ~= 'table' then return end
    if Registry.isDown(src) then return end

    local duration, reason = begin(shift, target)

    if not duration and reason then Registry.notify(src, reason, 'error') end

    return duration
end)

lib.callback.register('cobalt_cityhall:finish', function(src, target)
    local shift <const> = Registry.get(src)

    if not shift or type(target) ~= 'table' then return false end

    local ok <const> = Shifts.kind(shift).finish(shift, target)

    Vehicles.closeDoors(shift)

    if not ok then return false end

    Shifts.sync(shift)

    return true
end)

lib.callback.register('cobalt_cityhall:cancel', function(src)
    local shift <const> = Registry.get(src)

    if not shift then return end

    shift.pending = nil

    Vehicles.closeDoors(shift)
end)

lib.callback.register('cobalt_cityhall:sell', function(src)
    local shift <const> = Registry.get(src)

    if not shift or shift.def.kind ~= 'gather' then return false end
    if not Gather.sell(shift) then return false end

    Shifts.sync(shift)

    return true
end)

lib.callback.register('cobalt_cityhall:buyGear', function(src, index)
    local shift <const> = Registry.get(src)

    if not shift or shift.def.kind ~= 'gather' then return false end

    return Gather.buyGear(shift, index)
end)

lib.callback.register('cobalt_cityhall:vehicle', function(src, take)
    local shift <const> = Registry.get(src)

    if not shift or not shift.def.vehicle then return false end
    if not Registry.near(src, shift.def.site.coords, config.interactRange + SITE_SLACK) then return false end

    local label <const> = shift.def.vehicle.label

    if not take then
        if not Vehicles.has(shift) then return false end

        Shifts.loseVehicle(shift, ('You returned the %s.'):format(label))

        return true
    end

    local ok, reason = Vehicles.take(shift)

    if not ok then
        Registry.notify(src, reason --[[@as string]], 'error')
        return false
    end

    Shifts.sync(shift)

    local task <const> = Shifts.kind(shift).view(shift)
    local next <const> = task and (' Next: %s.'):format(task.title) or ''

    Registry.notify(src, ('Your %s is waiting in the bay.%s'):format(label, next), 'success')

    return true
end)
