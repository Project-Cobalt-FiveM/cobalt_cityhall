local config <const> = require 'config'
local Jobs <const> = require 'shared.jobs'
local Work <const> = require 'client.work'
local play <const> = require 'client.cues'
local CrewVehicle <const> = require 'client.crewvehicle'

local WRECK_CHECK_MS <const> = 2000
local SETTLE_TIMEOUT_MS <const> = 3000
local SELL_ZONE_RADIUS <const> = 0.4

---@class ClientJobKind
---@field enter fun(def: JobDefinition)
---@field update fun(def: JobDefinition, view: ShiftView)
---@field leave fun()

---@type table<JobKind, ClientJobKind>
local kinds <const> = {
    taxi = require 'client.kinds.taxi',
    route = require 'client.kinds.route',
    gather = require 'client.kinds.gather',
    collect = require 'client.kinds.collect',
    stand = require 'client.kinds.stand',
}

local Shift <const> = {
    ---@type ShiftView?
    current = nil,
}

---@type JobDefinition?
local def
local siteBlip, taskBlip, sitePed, sitePoint
---@type integer?
local sellZone

---@return boolean
local function hasVehicle()
    return Shift.current?.vehicle ~= nil
end

---@param job JobDefinition
---@return boolean
local function carriesGoods(job)
    for item in pairs(job.prices) do
        if (exports.cobalt_inventory:GetItemCount(item) or 0) > 0 then return true end
    end

    return false
end

---@param job JobDefinition
local function sellAtPoint(job)
    local point <const> = job.sellPoint --[[@as JobSellPoint]]

    if not carriesGoods(job) then
        local goods <const> = job.goods or locale('gather.goods')

        return exports.cobalt_core:Notify(locale('gather.nothing_to_sell', goods:lower()), 'error')
    end

    Work.face(point.coords)

    local done <const> = exports.cobalt_core:Progressbar({
        label = point.label,
        duration = point.duration,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = point.anim,
    })

    if done and lib.callback.await('cobalt_cityhall:sell', false) then play('purchase') end
end

---@param job JobDefinition
---@param distance number
---@param onSelect fun()
---@return table
local function sellOption(job, distance, onSelect)
    return {
        name = 'cobalt_cityhall:sell',
        label = job.sell or locale('site.sell'),
        icon = 'fa-solid fa-sack-dollar',
        distance = distance,
        onSelect = onSelect,
    }
end

---@param job JobDefinition
---@return table[]
local function siteOptions(job)
    local options <const> = {}

    if job.vehicle then
        options[#options + 1] = {
            name = 'cobalt_cityhall:takeVehicle',
            label = locale('site.take_vehicle', job.vehicle.label),
            icon = 'fa-solid fa-key',
            distance = config.interactRange,
            canInteract = function() return not hasVehicle() end,
            onSelect = function() lib.callback.await('cobalt_cityhall:vehicle', false, true) end,
        }

        options[#options + 1] = {
            name = 'cobalt_cityhall:returnVehicle',
            label = locale('site.return_vehicle', job.vehicle.label),
            icon = 'fa-solid fa-rotate-left',
            distance = config.interactRange,
            canInteract = hasVehicle,
            onSelect = function() lib.callback.await('cobalt_cityhall:vehicle', false, false) end,
        }
    end

    if job.shop then
        options[#options + 1] = {
            name = 'cobalt_cityhall:shop',
            label = job.shop.prompt,
            icon = 'fa-solid fa-basket-shopping',
            distance = config.interactRange,
            onSelect = function() lib.callback.await('cobalt_cityhall:shop', false) end,
        }
    end

    if job.prices and not job.sellPoint then
        options[#options + 1] = sellOption(job, config.interactRange, function()
            lib.callback.await('cobalt_cityhall:sell', false)
        end)
    end

    return options
end

---@param job JobDefinition
local function openSite(job)
    local site <const> = job.site

    siteBlip = Work.blip(site.blip.coords or site.coords.xyz, site.blip, site.label, 0.9)
    SetBlipAsShortRange(siteBlip, false)

    local point <const> = job.prices and job.sellPoint

    if point then
        sellZone = exports.ox_target:addSphereZone({
            coords = point.coords,
            radius = SELL_ZONE_RADIUS,
            options = { sellOption(job, point.radius, function() CreateThread(function() sellAtPoint(job) end) end) },
        })
    end

    if not site.ped then return end

    sitePoint = lib.points.new({
        coords = site.coords.xyz,
        distance = 60.0,
        onEnter = function()
            sitePed = Work.spawnPed(site.ped, site.coords, site.scenario)

            local options <const> = siteOptions(job)

            if sitePed and #options > 0 then exports.ox_target:addLocalEntity(sitePed, options) end
        end,
        onExit = function()
            Work.delete(sitePed)
            sitePed = nil
        end,
    })
end

local function closeSite()
    Work.removeBlip(siteBlip)
    Work.removeBlip(taskBlip)
    Work.delete(sitePed)
    if sitePoint then sitePoint:remove() end
    if sellZone then exports.ox_target:removeZone(sellZone) end

    siteBlip, taskBlip, sitePed, sitePoint, sellZone = nil, nil, nil, nil, nil
end

---@param task TaskView?
local function updateTaskBlip(task)
    if not task then
        Work.removeBlip(taskBlip)
        taskBlip = nil
        return
    end

    if taskBlip and #(GetBlipCoords(taskBlip) - task.coords) < 1.0 then return end

    Work.removeBlip(taskBlip)

    taskBlip = AddBlipForCoord(task.coords.x, task.coords.y, task.coords.z)

    SetBlipSprite(taskBlip, 1)
    SetBlipColour(taskBlip, 3)
    SetBlipRoute(taskBlip, true)
    SetBlipRouteColour(taskBlip, 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(task.label)
    EndTextCommandSetBlipName(taskBlip)
end

---@param view ShiftView?
local function apply(view)
    local previous <const> = Shift.current

    Shift.current = view

    CrewVehicle.track(view)

    if previous and (not view or previous.job ~= view.job) then
        kinds[(def --[[@as JobDefinition]]).kind].leave()
        closeSite()
        def = nil
    end

    if not view then return end

    if not def then
        def = Jobs.byId[view.job]
        openSite(def)
        kinds[def.kind].enter(def)
        SetNewWaypoint(def.site.coords.x, def.site.coords.y)
    end

    updateTaskBlip(view.task)
    kinds[def.kind].update(def, view)
end

---@type integer?
local wreckWatch

local function watchVehicle()
    if wreckWatch then return end

    wreckWatch = SetInterval(function()
        local netId <const> = Shift.current?.vehicle

        if not netId then
            ClearInterval(wreckWatch --[[@as integer]])
            wreckWatch = nil
            return
        end

        if not NetworkDoesEntityExistWithNetworkId(netId) then return end

        local vehicle <const> = NetToVeh(netId)

        if IsEntityDead(vehicle) or not IsVehicleDriveable(vehicle, false) then
            lib.callback.await('cobalt_cityhall:vehicleWrecked', false)
        end
    end, WRECK_CHECK_MS)
end

RegisterNetEvent('cobalt_cityhall:shift', function(view)
    apply(view)

    if view?.vehicle then watchVehicle() end
end)

RegisterNetEvent('cobalt_cityhall:settle', function(netId)
    local deadline <const> = GetGameTimer() + SETTLE_TIMEOUT_MS

    while not NetworkDoesEntityExistWithNetworkId(netId) do
        if GetGameTimer() > deadline then return end

        Wait(100)
    end

    local vehicle <const> = NetToVeh(netId)

    if NetworkHasControlOfEntity(vehicle) then SetVehicleOnGroundProperly(vehicle) end
end)

AddEventHandler('cobalt_core:Client:OnPlayerUnload', function()
    apply(nil)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then apply(nil) end
end)

return Shift
