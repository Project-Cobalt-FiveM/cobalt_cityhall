local config <const> = require 'config'
local Jobs <const> = require 'shared.jobs'
local Shift <const> = require 'client.shift'
local play <const> = require 'client.cues'

---@alias NuiView 'center' | 'shift' | 'admin' | 'dmv'

---@class JobCard
---@field id string
---@field label string
---@field description string
---@field icon string
---@field pay string
---@field site string
---@field vehicle? string
---@field crewSize integer
---@field payRows PayRow[]
---@field doneLabel string

---@type JobCard[]
local catalogue <const> = {}

for _, id in ipairs(Jobs.order) do
    local def <const> = Jobs.byId[id]

    catalogue[#catalogue + 1] = {
        id = id,
        label = def.label,
        description = def.description,
        icon = def.icon,
        pay = Jobs.payLine(def),
        site = def.site.label,
        vehicle = def.vehicle?.label,
        crewSize = def.crewSize,
        payRows = Jobs.payRows(def),
        doneLabel = def.doneLabel,
    }
end

---@param view ShiftView?
---@return ShiftView?
local function withDistance(view)
    local task <const> = view?.task

    if task then task.distance = math.floor(#(GetEntityCoords(cache.ped) - task.coords)) end

    return view
end

local Nui <const> = {}

local isOpen = false

---@param view NuiView
---@param result? DriveTestResult
function Nui.open(view, result)
    local admin <const> = view == 'admin' and lib.callback.await('cobalt_cityhall:admin', false) or nil
    local dmv <const> = view == 'dmv' and lib.callback.await('cobalt_cityhall:dmv', false) or nil

    if view == 'admin' and not admin then return end
    if view == 'shift' and not Shift.current then
        return exports.cobalt_core:Notify('You have no job. Sign up at City Hall.', 'error')
    end

    if view == 'dmv' then
        if not dmv then return end

        if dmv.practical.active then
            return exports.cobalt_core:Notify('Finish your driving test first', 'error')
        end

        if dmv.practical.licensed and not result then
            return exports.cobalt_core:Notify('You already have a driver licence', 'inform')
        end
    end

    isOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        view = view,
        me = cache.serverId,
        payAccount = config.payAccount,
        catalogue = catalogue,
        states = lib.callback.await('cobalt_cityhall:jobs', false),
        shift = withDistance(Shift.current),
        admin = admin,
        cards = view == 'center' and lib.callback.await('cobalt_cityhall:cards', false) or nil,
        dmv = dmv,
        result = result,
    })
end

local function close()
    isOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@param name string
---@param handler fun(data: table): any
local function nuiCallback(name, handler)
    RegisterNUICallback(name, function(data, reply)
        reply(handler(data) or {})
    end)
end

nuiCallback('close', close)

nuiCallback('signUp', function(data)
    local ok, reason = lib.callback.await('cobalt_cityhall:signUp', false, data.job)

    return { ok = ok, reason = reason }
end)

nuiCallback('quit', function()
    lib.callback.await('cobalt_cityhall:quit', false)
end)

---@param coords vector3|vector4
---@param label string
---@return { ok: boolean }
local function setGps(coords, label)
    SetNewWaypoint(coords.x, coords.y)
    play('gps')
    exports.cobalt_core:Notify(('GPS set to %s'):format(label), 'success')

    return { ok = true }
end

---@alias GpsPlace 'dmv' | 'cityhall'

---@type table<GpsPlace, { coords: vector4, label: string }>
local places <const> = {
    dmv = { coords = config.dmv.coords, label = 'the DMV' },
    cityhall = { coords = config.center.coords, label = config.center.label },
}

nuiCallback('gps', function(data)
    local def <const> = Jobs.byId[data.job]

    if not def then return { ok = false } end

    return setGps(def.site.coords, def.site.label)
end)

nuiCallback('gpsPlace', function(data)
    local place <const> = places[data.place]

    if not place then return { ok = false } end

    return setGps(place.coords, place.label)
end)

nuiCallback('gpsTask', function()
    local task <const> = Shift.current?.task

    if not task then return { ok = false } end

    return setGps(task.coords, task.title)
end)

nuiCallback('nearby', function()
    return { players = lib.callback.await('cobalt_cityhall:nearby', false) }
end)

nuiCallback('invite', function(data)
    local ok, reason = lib.callback.await('cobalt_cityhall:invite', false, data.id)

    return { ok = ok, reason = reason }
end)

nuiCallback('leaveCrew', function()
    lib.callback.await('cobalt_cityhall:leaveCrew', false)
end)

nuiCallback('buyCard', function(data)
    local ok <const>, reason <const>, cards <const> = lib.callback.await('cobalt_cityhall:buyCard', false, data.key)

    if ok then play('purchase') end

    return { ok = ok, reason = reason, cards = cards }
end)

nuiCallback('startTheory', function()
    local ok <const>, reason <const>, questions <const> = lib.callback.await('cobalt_cityhall:startTheory', false)

    return { ok = ok, reason = reason, questions = questions }
end)

nuiCallback('submitTheory', function(data)
    local ok <const>, reason <const>, result <const> = lib.callback.await('cobalt_cityhall:submitTheory', false, data.answers)

    if result then play(result.passed and 'theoryPassed' or 'failed') end

    return { ok = ok, reason = reason, result = result }
end)

nuiCallback('startPractical', function()
    local ok <const>, reason <const> = lib.callback.await('cobalt_cityhall:startPractical', false)

    if ok then close() end

    return { ok = ok, reason = reason }
end)

nuiCallback('adminEnd', function(data)
    return { admin = lib.callback.await('cobalt_cityhall:adminEnd', false, data.id) }
end)

nuiCallback('adminToggle', function(data)
    return { admin = lib.callback.await('cobalt_cityhall:adminToggle', false, data.job, data.open) }
end)

RegisterNetEvent('cobalt_cityhall:shift', function(view)
    SendNUIMessage({ action = 'shift', shift = withDistance(view) })
end)

RegisterNetEvent('cobalt_cityhall:openShift', function()
    Nui.open('shift')
end)

RegisterNetEvent('cobalt_cityhall:openAdmin', function()
    Nui.open('admin')
end)

---@type { expires: integer }?
local pendingInvite

---@param accept boolean
local function respond(accept)
    if not pendingInvite then return end

    pendingInvite = nil
    SendNUIMessage({ action = 'invite', invite = false })

    local ok, reason = lib.callback.await('cobalt_cityhall:respond', false, accept)

    if accept and not ok and reason then exports.cobalt_core:Notify(reason, 'error') end
end

nuiCallback('respond', function(data)
    respond(data.accept == true)
end)

local acceptKey <const> = lib.addKeybind({
    name = 'cobalt_cityhall_accept',
    description = 'Accept a crew invite',
    defaultKey = 'Y',
    disabled = true,
    onReleased = function() respond(true) end,
})

local declineKey <const> = lib.addKeybind({
    name = 'cobalt_cityhall_decline',
    description = 'Decline a crew invite',
    defaultKey = 'N',
    disabled = true,
    onReleased = function() respond(false) end,
})

---@param disabled boolean
local function setInviteKeys(disabled)
    acceptKey:disable(disabled)
    declineKey:disable(disabled)
end

RegisterNetEvent('cobalt_cityhall:invited', function(invite)
    local expires <const> = GetGameTimer() + invite.seconds * 1000

    pendingInvite = { expires = expires }
    invite.acceptKey = acceptKey:getCurrentKey()
    invite.declineKey = declineKey:getCurrentKey()

    setInviteKeys(false)
    SendNUIMessage({ action = 'invite', invite = invite })

    SetTimeout(invite.seconds * 1000, function()
        if pendingInvite?.expires == expires then respond(false) end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and isOpen then SetNuiFocus(false, false) end
end)

return Nui
