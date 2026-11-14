local config <const> = require 'config'
local db <const> = require 'server.db'
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
    return Player(src).state['cobalt:name'] or ('Citizen %d'):format(src)
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
    if type(jobId) ~= 'string' or not Jobs.byId[jobId] then return false, 'That job does not exist' end
    if not atCenter(src) then return false, 'Sign up at the job center' end
    if Center.closed[jobId] then return false, 'Staff closed this job for now' end

    local ok, reason = Shifts.start(src, jobId)

    if ok then Registry.notify(src, ('You signed up for %s'):format(Jobs.byId[jobId].label), 'success') end

    return ok, reason
end)

lib.callback.register('cobalt_cityhall:quit', function(src)
    local shift <const> = Registry.get(src)

    if not shift then return false end

    Shifts.stop(src, ('You quit %s'):format(shift.def.label))

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

    if not shift then return false, 'You have no job' end

    if math.type(target) ~= 'integer' or target == src or not Player(target).state.LoggedIn then
        return false, 'That player is gone'
    end

    if crewFull(shift) then return false, 'Your crew is full' end

    if #(Registry.coords(target) - Registry.coords(src)) > config.crew.inviteRange then
        return false, 'They walked away'
    end

    local guest <const> = Registry.get(target)

    if guest and guest.def.id ~= shift.def.id then return false, ('They work as %s'):format(guest.def.label) end
    if guest?.crew then return false, 'They are already in a crew' end
    if not guest and exports.cobalt_core:GetTempJob(target) then return false, 'They are busy with other work' end

    invites[target] = { from = src, job = shift.def.id, expires = os.time() + config.crew.inviteSeconds }

    TriggerClientEvent('cobalt_cityhall:invited', target, {
        from = shift.name,
        job = shift.def.id,
        crew = #Registry.crewShifts(shift),
        seconds = config.crew.inviteSeconds,
    })

    Registry.notify(src, ('Invite sent to %s'):format(playerName(target)))

    return true
end)

lib.callback.register('cobalt_cityhall:respond', function(src, accept)
    local invite <const> = invites[src]

    invites[src] = nil

    if not invite or invite.expires < os.time() then return false end

    if not accept then
        Registry.notify(invite.from, ('%s declined your invite'):format(playerName(src)))
        return false
    end

    local host <const> = Registry.get(invite.from)

    if not host or host.def.id ~= invite.job then return false, 'The crew is gone' end
    if Center.closed[host.def.id] then return false, 'Staff closed this job for now' end
    if crewFull(host) then return false, 'The crew is full' end

    local guest = Registry.get(src)

    if guest and (guest.def.id ~= host.def.id or guest.crew) then return false, 'Quit your current job first' end

    if not guest then
        local ok, reason = Shifts.start(src, host.def.id)

        if not ok then return false, reason end

        guest = Registry.get(src) --[[@as Shift]]
    end

    Shifts.joinCrew(host, guest)
    Registry.notify(host.src, ('%s joined your crew'):format(guest.name), 'success')

    return true
end)

lib.addCommand('shift', { help = 'Open your current job' }, function(src)
    TriggerClientEvent('cobalt_cityhall:openShift', src)
end)

AddEventHandler('playerDropped', function()
    invites[source] = nil
end)

CreateThread(function()
    Center.closed = db.closedJobs()
end)

return Center
