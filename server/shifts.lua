local Registry <const> = require 'server.registry'
local Vehicles <const> = require 'server.vehicles'
local Jobs <const> = require 'shared.jobs'

---@class JobKindHandler
---@field assign fun(shift: Shift)
---@field view fun(shift: Shift): TaskView?
---@field begin? fun(shift: Shift, target: table): integer?, string?
---@field finish fun(shift: Shift, target: table): boolean
---@field resting? fun(shift: Shift): table[]
---@field reset? fun(shift: Shift, why: LossReason): string?
---@field tick? fun(shift: Shift): boolean
---@field stop? fun(shift: Shift)

---@type table<JobKind, JobKindHandler>
local kinds <const> = {
    taxi = require 'server.kinds.taxi',
    route = require 'server.kinds.route',
    gather = require 'server.kinds.gather',
    collect = require 'server.kinds.collect',
    stand = require 'server.kinds.stand',
}

local Shifts <const> = {}

---@param shift Shift
---@return JobKindHandler
function Shifts.kind(shift)
    return kinds[shift.def.kind]
end

---@param shift Shift
---@return ShiftView
function Shifts.view(shift)
    local crew <const> = {}

    for _, member in ipairs(Registry.crewShifts(shift)) do
        crew[#crew + 1] = {
            id = member.src,
            name = member.name,
            leader = shift.crew?.leader == member.src,
            earned = member.earned,
        }
    end

    return {
        job = shift.def.id,
        startedAt = shift.startedAt,
        earned = shift.earned,
        done = shift.done,
        crew = crew,
        task = Shifts.kind(shift).view(shift),
        vehicle = Vehicles.has(shift) and NetworkGetNetworkIdFromEntity(shift.vehicle) or nil,
        carrying = shift.bag or nil,
    }
end

---@param shift Shift
function Shifts.sync(shift)
    for _, member in ipairs(Registry.crewShifts(shift)) do
        TriggerClientEvent('cobalt_cityhall:shift', member.src, Shifts.view(member))
    end
end

---@param src integer
---@param jobId string
---@return boolean ok
---@return string? reason
function Shifts.start(src, jobId)
    local def <const> = Jobs.byId[jobId]

    if not def then return false, 'That job does not exist' end
    if Registry.get(src) then return false, 'Quit your current job first' end
    if exports.cobalt_core:GetTempJob(src) then return false, 'Finish your other work first' end

    local citizenid <const> = Registry.citizenid(src)

    if not citizenid then return false, 'Load a character first' end

    ---@type Shift
    local shift <const> = {
        src = src,
        def = def,
        citizenid = citizenid,
        name = Player(src).state['cobalt:name'] or ('Citizen %d'):format(src),
        startedAt = os.time(),
        earned = 0,
        done = 0,
        task = {},
    }

    Registry.shifts[src] = shift
    exports.cobalt_core:SetTempJob(src, def.id, { label = def.label })

    local kind <const> = Shifts.kind(shift)

    kind.assign(shift)
    Shifts.sync(shift)

    if kind.resting then TriggerClientEvent('cobalt_cityhall:resting', src, kind.resting(shift)) end

    local hint = 'It is marked on your map.'

    if def.vehicle then hint = ('The clerk there hands out the %s.'):format(def.vehicle.label) end
    if def.stand then hint = 'The cart is in your pockets. Set it up anywhere people walk past.' end

    Registry.notify(src, ('Head to %s. %s'):format(def.site.label, hint))

    return true
end

---@param shift Shift
---@param why LossReason
---@param message? string sent to the whole crew before what each member lost
function Shifts.lose(shift, why, message)
    local reset <const> = Shifts.kind(shift).reset

    for _, member in ipairs(Registry.crewShifts(shift)) do
        local lost <const> = reset and reset(member, why)
        local text <const> = message and lost and ('%s %s'):format(message, lost) or message or lost

        member.pending = nil

        if text then Registry.notify(member.src, text, 'error') end
    end

    Shifts.sync(shift)
end

---@param shift Shift
---@param message string
function Shifts.loseVehicle(shift, message)
    local lost <const> = shift.vehicle

    Vehicles.release(shift)

    if Vehicles.crewHasVehicle(shift) and shift.task?.cargoVehicle ~= lost then
        Registry.notify(shift.src, message, 'error')

        return Shifts.sync(shift)
    end

    local spec <const> = shift.def.vehicle --[[@as JobVehicle]]
    local next <const> = ('Take a new %s from the clerk at %s.'):format(spec.label, shift.def.site.label)

    Shifts.lose(shift, 'vehicle', ('%s %s'):format(message, next))
end

---@param shift Shift
function Shifts.leaveCrew(shift)
    local crew <const> = shift.crew

    if not crew then return end

    shift.crew = nil

    for i, member in ipairs(crew.members) do
        if member == shift.src then
            table.remove(crew.members, i)
            break
        end
    end

    if #crew.members == 0 then return end

    if crew.leader == shift.src then crew.leader = crew.members[1] end

    local remaining <const> = Registry.get(crew.members[1])

    if #crew.members == 1 and remaining then remaining.crew = nil end
    if remaining then Shifts.sync(remaining) end
end

---@param shift Shift
---@return Shift?
local function crewmate(shift)
    for _, member in ipairs(Registry.crewShifts(shift)) do
        if member ~= shift then return member end
    end
end

---@param leaver Shift
---@param remaining Shift
---@param leaverVehicle? integer
local function crewLeft(leaver, remaining, leaverVehicle)
    local spec <const> = leaver.def.vehicle --[[@as JobVehicle]]

    if not leaverVehicle then
        return Registry.notifyCrew(remaining, ('%s left the crew.'):format(leaver.name))
    end

    Registry.notifyCrew(remaining, ('%s left the crew, and their %s went with them.'):format(leaver.name, spec.label))

    if Vehicles.crewHasVehicle(remaining) and remaining.task?.cargoVehicle ~= leaverVehicle then return end

    Shifts.lose(remaining, 'vehicle', ('Take a %s from the clerk at %s.'):format(spec.label, leaver.def.site.label))
end

---@param src integer
---@param reason? string
function Shifts.stop(src, reason)
    local shift <const> = Registry.get(src)

    if not shift then return end

    Registry.shifts[src] = nil

    local stop <const> = Shifts.kind(shift).stop

    if stop then stop(shift) end

    local remaining <const> = crewmate(shift)
    local leaverVehicle <const> = Vehicles.has(shift) and shift.vehicle or nil

    Shifts.leaveCrew(shift)
    Vehicles.release(shift)

    if remaining then crewLeft(shift, remaining, leaverVehicle) end

    exports.cobalt_core:ClearTempJob(src)

    if GetPlayerPed(src) ~= 0 then
        TriggerClientEvent('cobalt_cityhall:shift', src, nil)

        if reason then Registry.notify(src, reason) end
    end
end

---Leaves the crew but keeps the shift and its vehicle, working solo from a fresh task
---@param shift Shift
function Shifts.quitCrew(shift)
    if not shift.crew then return end

    local remaining <const> = crewmate(shift)
    local others <const> = {}

    for _, member in ipairs(Registry.crewShifts(shift)) do
        if member ~= shift then others[#others + 1] = member end
    end

    local leaverVehicle <const> = Vehicles.has(shift) and shift.vehicle or nil

    Shifts.leaveCrew(shift)
    Vehicles.splitKeys(shift, others)

    shift.task = {}
    Shifts.kind(shift).assign(shift)
    Shifts.sync(shift)

    if remaining then crewLeft(shift, remaining, leaverVehicle) end
end

---@param host Shift
---@param guest Shift
function Shifts.joinCrew(host, guest)
    host.crew = host.crew or { job = host.def.id, leader = host.src, members = { host.src } }

    local members <const> = host.crew.members

    members[#members + 1] = guest.src
    guest.crew = host.crew
    guest.task = host.task

    Vehicles.shareKeys(host, guest)
    Shifts.sync(host)
end

AddEventHandler('cobalt_core:server:tempJobChanged', function(src, job)
    local shift <const> = Registry.get(src)

    if shift and job?.name ~= shift.def.id then Shifts.stop(src) end
end)

AddEventHandler('playerDropped', function()
    Shifts.stop(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for src in pairs(Registry.shifts) do Shifts.stop(src) end
end)

return Shifts
