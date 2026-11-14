local Work <const> = require 'client.work'
local play <const> = require 'client.cues'
local showMarker <const> = require 'client.marker'

local INTERACT_KEY <const> = 38
local PROP_DISTANCE <const> = 50.0
local MARK_DISTANCE <const> = 60.0
local ENTRANCE_RADIUS <const> = 1.5
local GUIDE_INTERVAL_MS <const> = 1500
local GUIDE_COLOUR <const> = 3

---@class GatherNode
---@field group integer
---@field index integer
---@field spec GatherGroup
---@field point GatherPoint
---@field cpoint CPoint
---@field prop? integer
---@field readyAt integer
---@field markPoint? CPoint
---@field hideMarker? fun()

---@type table<string, GatherNode>
local nodes <const> = {}
---@type CPoint[]
local extraPoints <const> = {}
---@type integer[]
local blips <const> = {}
---@type integer?
local guideBlip
---@type GatherNode?
local guided
---@type unknown?
local guideTicker

---@param group integer
---@param index integer
---@return string
local function key(group, index)
    return ('%d:%d'):format(group, index)
end

---@param node GatherNode
---@return string
local function propModel(node)
    if node.spec.prop then return node.spec.prop end

    return node.spec.props[node.index % #node.spec.props + 1]
end

---@param node GatherNode
---@return boolean
local function isReady(node)
    return GetGameTimer() >= node.readyAt
end

---@param node GatherNode
local function mark(node)
    if node.hideMarker or not isReady(node) then return end

    node.hideMarker = showMarker(node.point.coords)
end

---@param node GatherNode
local function unmark(node)
    if node.hideMarker then node.hideMarker() end

    node.hideMarker = nil
end

---@param node GatherNode
---@return CPoint
local function markPoint(node)
    return lib.points.new({
        coords = node.point.coords,
        distance = MARK_DISTANCE,
        onEnter = function() mark(node) end,
        onExit = function() unmark(node) end,
    })
end

local function removeGuide()
    Work.removeBlip(guideBlip)
    guideBlip, guided = nil, nil
end

---@param node GatherNode
local function setGuide(node)
    removeGuide()

    local coords <const> = node.point.coords

    guided = node
    guideBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipColour(guideBlip, GUIDE_COLOUR)
    SetBlipScale(guideBlip, 0.7)
    SetBlipRoute(guideBlip, true)
    SetBlipRouteColour(guideBlip, GUIDE_COLOUR)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(node.point.label or node.spec.label)
    EndTextCommandSetBlipName(guideBlip)
end

local function updateGuide()
    local from <const> = GetEntityCoords(cache.ped)
    local nearest, best = nil, math.huge

    for _, node in pairs(nodes) do
        if node.spec.guide and isReady(node) then
            local distance <const> = #(from - node.point.coords)

            if distance < best then nearest, best = node, distance end
        end
    end

    if nearest == guided then return end
    if not nearest then return removeGuide() end

    setGuide(nearest)
end

---@param node GatherNode
local function runNode(node)
    local zone <const> = node.spec.zone
    local facing <const> = not zone and node.point.coords or nil

    CreateThread(function()
        if zone and node.point.heading then SetEntityHeading(cache.ped, node.point.heading) end

        if Work.run({ group = node.group, index = node.index }, node.spec.action, facing) then play('checkpoint') end
    end)
end

---@param node GatherNode
local function spawnProp(node)
    if node.spec.zone or node.prop or GetGameTimer() < node.readyAt then return end

    node.prop = Work.spawnProp(propModel(node), node.point.coords, node.point.heading)

    if not node.prop then return end

    exports.ox_target:addLocalEntity(node.prop, {
        {
            name = 'cobalt_cityhall:gather',
            label = node.spec.action.prompt,
            icon = 'fa-solid fa-hand',
            distance = (node.spec.radius or 2.0) + 1.0,
            onSelect = function() runNode(node) end,
        },
    })
end

---@param node GatherNode
local function removeProp(node)
    Work.delete(node.prop)
    node.prop = nil
end

---@param node GatherNode
---@return CPoint
local function propPoint(node)
    return lib.points.new({
        coords = node.point.coords,
        distance = PROP_DISTANCE,
        onEnter = function() spawnProp(node) end,
        onExit = function() removeProp(node) end,
    })
end

---@param node GatherNode
---@return CPoint
local function zonePoint(node)
    local prompt <const> = ('[E] %s'):format(node.spec.action.prompt)

    return lib.points.new({
        coords = node.point.coords,
        distance = node.point.radius or node.spec.radius or 2.0,
        onEnter = function() exports.cobalt_core:ShowTextUI(prompt) end,
        onExit = function() exports.cobalt_core:HideTextUI() end,
        nearby = function()
            if cache.vehicle or not IsControlJustReleased(0, INTERACT_KEY) then return end

            runNode(node)
        end,
    })
end

---@param from vector4
---@param to vector4
---@param prompt string
local function door(from, to, prompt)
    extraPoints[#extraPoints + 1] = lib.points.new({
        coords = from.xyz,
        distance = ENTRANCE_RADIUS,
        onEnter = function() exports.cobalt_core:ShowTextUI(('[E] %s'):format(prompt)) end,
        onExit = function() exports.cobalt_core:HideTextUI() end,
        nearby = function()
            if not IsControlJustReleased(0, INTERACT_KEY) then return end

            CreateThread(function()
                DoScreenFadeOut(300)
                Wait(300)
                SetEntityCoords(cache.ped, to.x, to.y, to.z, false, false, false, false)
                SetEntityHeading(cache.ped, to.w)
                Wait(300)
                DoScreenFadeIn(300)
            end)
        end,
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and (IsScreenFadedOut() or IsScreenFadingOut()) then DoScreenFadeIn(0) end
end)

local Gather <const> = {}

---@param def JobDefinition
function Gather.enter(def)
    for groupIndex, spec in ipairs(def.groups) do
        for index, point in ipairs(spec.points) do
            local node <const> = { group = groupIndex, index = index, spec = spec, point = point, readyAt = 0 }

            node.cpoint = spec.zone and zonePoint(node) or propPoint(node)
            node.markPoint = spec.marker and markPoint(node) or nil
            nodes[key(groupIndex, index)] = node

            if spec.guide then guideTicker = guideTicker or SetInterval(updateGuide, GUIDE_INTERVAL_MS) end

            if spec.blip then
                blips[#blips + 1] = Work.blip(point.coords, spec.blip, point.label or spec.label, 0.7)
            end
        end
    end

    if def.entrance then
        door(def.entrance.outside, def.entrance.inside, locale('gather.go_inside'))
        door(def.entrance.inside, def.entrance.outside, locale('gather.go_outside'))
    end
end

function Gather.update() end

function Gather.leave()
    for _, node in pairs(nodes) do
        node.cpoint:remove()
        removeProp(node)
        unmark(node)

        if node.markPoint then node.markPoint:remove() end
    end

    if guideTicker then ClearInterval(guideTicker) end

    guideTicker = nil
    removeGuide()

    for _, cpoint in ipairs(extraPoints) do cpoint:remove() end
    for _, blip in ipairs(blips) do Work.removeBlip(blip) end

    exports.cobalt_core:HideTextUI()
    table.wipe(nodes)
    table.wipe(extraPoints)
    table.wipe(blips)
end

---@param group integer
---@param index integer
---@param ms integer
local function rest(group, index, ms)
    local node <const> = nodes[key(group, index)]

    if not node then return end

    node.readyAt = GetGameTimer() + ms
    removeProp(node)
    unmark(node)

    if guided == node then updateGuide() end

    SetTimeout(ms, function()
        if nodes[key(group, index)] ~= node then return end
        if node.cpoint.currentDistance then spawnProp(node) end
        if node.markPoint?.currentDistance then mark(node) end
    end)
end

RegisterNetEvent('cobalt_cityhall:rest', rest)

RegisterNetEvent('cobalt_cityhall:resting', function(list)
    for _, entry in ipairs(list) do rest(entry.group, entry.index, entry.ms) end
end)

return Gather
