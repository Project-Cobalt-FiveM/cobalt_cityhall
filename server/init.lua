if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

local Registry <const> = require 'server.registry'
local Shifts <const> = require 'server.shifts'

require 'server.center'
require 'server.work'
require 'server.admin'
require 'server.watch'
require 'server.cards'
require 'server.dmv'
require 'server.hotdog'

exports('GetShift', function(src)
    local shift <const> = Registry.get(src)

    return shift and Shifts.view(shift)
end)

exports('EndShift', function(src, reason)
    if not Registry.get(src) then return false end

    Shifts.stop(src, reason)

    return true
end)
