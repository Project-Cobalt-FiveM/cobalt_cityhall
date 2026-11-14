local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Shifts <const> = require 'server.shifts'
local Jobs <const> = require 'shared.jobs'

local CENTER_SLACK <const> = 3.0

local Center <const> = {
    ---@type table<string, true>
    closed = {},
}

---@class Invite
---@field from integer
---@field job string
---@field expires integer

---@type table<integer, Invite>
local invites <const> = {}

---@param src integer
---@return boolean
local function atCenter(src)
    return Registry.near(src, config.center.coords, config.interactRange + CENTER_SLACK)
end

---@param src integer
---@return string
local function playerName(src)
    return Player(src).state['cobalt:name'] or locale('center.citizen', src)
end

---@return { id: string, open: boolean }[]
local function jobStates()
    local list <const> = {}

    for _, id in ipairs(Jobs.order) do
        list[#list + 1] = { id = id, open = not Center.closed[id] }
    end

    return list
end

lib.callback.register('cobalt_cityhall:jobs', function()
    return jobStates()
end)

lib.callback.register('cobalt_cityhall:signUp', function(src, jobId)
    if type(jobId) ~= 'string' or not Jobs.byId[jobId] then return false, locale('center.unknown_job') end
    if not atCenter(src) then return false, locale('center.sign_up_here') end
    if Center.closed[jobId] then return false, locale('center.closed') end

    local ok, reason = Shifts.start(src, jobId)

    if ok then Registry.notify(src, locale('center.signed_up', Jobs.byId[jobId].label), 'success') end

    return ok, reason
end)

lib.callback.register('cobalt_cityhall:quit', function(src)
    local shift <const> = Registry.get(src)

    if not shift then return false end

    Shifts.stop(src, locale('center.quit', shift.def.label))

    return true
end)

lib.callback.register('cobalt_cityhall:leaveCrew', function(src)
    local shift <const> = Registry.get(src)

    if not shift or not shift.crew then return false end

    Shifts.quitCrew(shift)

    return true
end)

lib.callback.register('cobalt_cityhall:nearby', function(src)
    local shift <const> = Registry.get(src)

    if not shift then return {} end

    local origin <const> = Registry.coords(src)
    local list <const> = {}

    for _, id in ipairs(GetPlayers()) do
        local target <const> = tonumber(id) --[[@as integer]]
        local state <const> = Player(target).state

        if target ~= src and state.LoggedIn then
            local distance <const> = #(Registry.coords(target) - origin)

            if distance <= config.crew.inviteRange then
                list[#list + 1] = { id = target, name = playerName(target), distance = math.floor(distance + 0.5) }
            end
        end
    end

    table.sort(list, function(a, b) return a.distance < b.distance end)

    return list
end)

---@param shift Shift
---@return boolean
local function crewFull(shift)
    return #Registry.crewShifts(shift) >= shift.def.crewSize
end

lib.callback.register('cobalt_cityhall:invite', function(src, target)
    local shift <const> = Registry.get(src)

    if not shift then return false, locale('center.no_job') end

    if math.type(target) ~= 'integer' or target == src or not Player(target).state.LoggedIn then
        return false, locale('center.player_gone')
    end

    if crewFull(shift) then return false, locale('center.your_crew_full') end

    if #(Registry.coords(target) - Registry.coords(src)) > config.crew.inviteRange then
        return false, locale('center.walked_away')
    end

    local guest <const> = Registry.get(target)

    if guest and guest.def.id ~= shift.def.id then return false, locale('center.works_as', guest.def.label) end
    if guest?.crew then return false, locale('center.in_crew') end
    if not guest and exports.cobalt_core:GetTempJob(target) then return false, locale('center.busy') end

    invites[target] = { from = src, job = shift.def.id, expires = os.time() + config.crew.inviteSeconds }

    TriggerClientEvent('cobalt_cityhall:invited', target, {
        from = shift.name,
        job = shift.def.id,
        crew = #Registry.crewShifts(shift),
        seconds = config.crew.inviteSeconds,
    })

    Registry.notify(src, locale('center.invite_sent', playerName(target)))

    return true
end)

lib.callback.register('cobalt_cityhall:respond', function(src, accept)
    local invite <const> = invites[src]

    invites[src] = nil

    if not invite or invite.expires < os.time() then return false end

    if not accept then
        Registry.notify(invite.from, locale('center.declined', playerName(src)))
        return false
    end

    local host <const> = Registry.get(invite.from)

    if not host or host.def.id ~= invite.job then return false, locale('center.crew_gone') end
    if Center.closed[host.def.id] then return false, locale('center.closed') end
    if crewFull(host) then return false, locale('center.crew_full') end

    local guest = Registry.get(src)

    if guest and (guest.def.id ~= host.def.id or guest.crew) then return false, locale('center.quit_first') end

    if not guest then
        local ok, reason = Shifts.start(src, host.def.id)

        if not ok then return false, reason end

        guest = Registry.get(src) --[[@as Shift]]
    end

    Shifts.joinCrew(host, guest)
    Registry.notify(host.src, locale('center.joined', guest.name), 'success')

    return true
end)

lib.addCommand('shift', { help = locale('command.shift') }, function(src)
    TriggerClientEvent('cobalt_cityhall:openShift', src)
end)

AddEventHandler('playerDropped', function()
    invites[source] = nil
end)

CreateThread(function()
    for id, status in pairs(exports.cobalt_management:GetJobStatus(Jobs.order)) do
        Center.closed[id] = not status.open or nil
    end
end)

return Center
