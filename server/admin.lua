local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Shifts <const> = require 'server.shifts'
local Center <const> = require 'server.center'
local Jobs <const> = require 'shared.jobs'

---@param src integer
---@return boolean
local function isAdmin(src)
    return exports.cobalt_core:HasPermission(src, config.adminRank)
end

---@class AdminWorkerView
---@field id integer
---@field name string
---@field citizenid string
---@field job string
---@field crew integer
---@field startedAt integer
---@field earned integer

---@class AdminView
---@field workers AdminWorkerView[]
---@field jobs { id: string, open: boolean, workers: integer, paidToday: integer }[]

---@return AdminView
local function dashboard()
    local workers, counts = {}, {}

    for src, shift in pairs(Registry.shifts) do
        workers[#workers + 1] = {
            id = src,
            name = shift.name,
            citizenid = shift.citizenid,
            job = shift.def.id,
            crew = #Registry.crewShifts(shift),
            startedAt = shift.startedAt,
            earned = shift.earned,
        }

        counts[shift.def.id] = (counts[shift.def.id] or 0) + 1
    end

    table.sort(workers, function(a, b) return a.startedAt < b.startedAt end)

    local status <const> = exports.cobalt_management:GetJobStatus(Jobs.order)
    local jobs <const> = {}

    for _, id in ipairs(Jobs.order) do
        jobs[#jobs + 1] = {
            id = id,
            open = not Center.closed[id],
            workers = counts[id] or 0,
            paidToday = status[id].paidToday,
        }
    end

    return { workers = workers, jobs = jobs }
end

lib.callback.register('cobalt_cityhall:admin', function(src)
    if not isAdmin(src) then return end

    return dashboard()
end)

lib.callback.register('cobalt_cityhall:adminEnd', function(src, target)
    local shift <const> = isAdmin(src) and Registry.get(target)

    if not shift then return end

    Shifts.stop(target, locale('admin.ended_shift', shift.def.label, shift.earned))
    lib.print.info(('%s ended the shift of player %d'):format(GetPlayerName(src), target))

    return dashboard()
end)

lib.callback.register('cobalt_cityhall:adminToggle', function(src, jobId, open)
    if not isAdmin(src) or not Jobs.byId[jobId] or type(open) ~= 'boolean' then return end

    Center.closed[jobId] = not open or nil
    exports.cobalt_management:SetJobOpen(jobId, open)
    lib.print.info(('%s set %s %s'):format(GetPlayerName(src), jobId, open and 'open' or 'closed'))

    return dashboard()
end)

lib.addCommand('jobsadmin', {
    help = locale('command.jobsadmin'),
    restricted = ('group.%s'):format(config.adminRank),
}, function(src)
    TriggerClientEvent('cobalt_cityhall:openAdmin', src)
end)
