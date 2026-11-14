local Station <const> = require 'client.hotdog.station'
local Jobs <const> = require 'shared.jobs'

local SCAN_MS <const> = 1500
local STREAM_WAIT_MS <const> = 2000
local RANGE <const> = 60.0
local SWING_MS <const> = 400
local LID_OPEN <const> = 100.0

---@class DressedCart
---@field lids table<LidName, integer>
---@field open table<LidName, boolean>

---@type StandConfig
local stand <const> = Jobs.byId.hotdog.stand
local cartModel <const> = joaat(stand.model)

---@type table<integer, DressedCart>
local dressed <const> = {}

---@type table<integer, true>
local carts <const> = {}

---@type integer?
local sweep

local Dressing <const> = {}

---@param cart integer
---@param name LidName
---@param open boolean
local function pose(cart, name, open)
    local lid <const> = dressed[cart]?.lids[name]

    if lid then Station.orient(lid, GetEntityHeading(cart), open and LID_OPEN or 0.0) end
end

---@param cart integer
local function dress(cart)
    local lids <const> = {}
    local state <const> = Entity(cart).state.hotdogLids or {}

    for name, hinge in pairs(stand.kitchen.lids) do
        lids[name] = Station.prop(stand.kitchen.models.lids[name], Station.at(cart, hinge), GetEntityHeading(cart))
    end

    dressed[cart] = { lids = lids, open = { fryer = state.fryer == true, griddle = state.griddle == true } }

    for name in pairs(lids) do pose(cart, name, dressed[cart].open[name]) end
end

---@param cart integer
local function undress(cart)
    local entry <const> = dressed[cart]

    dressed[cart] = nil

    if not entry then return end

    for _, lid in pairs(entry.lids) do Station.remove(lid) end
end

local function refresh()
    local origin <const> = GetEntityCoords(cache.ped)

    for cart in pairs(carts) do
        if not DoesEntityExist(cart) then
            carts[cart] = nil
            undress(cart)
        elseif #(GetEntityCoords(cart) - origin) > RANGE then
            undress(cart)
        elseif not dressed[cart] then
            dress(cart)
        end
    end

    if next(carts) then return end

    ClearInterval(sweep --[[@as integer]])
    sweep = nil
end

---@param cart integer
local function track(cart)
    carts[cart] = true

    if not sweep then sweep = SetInterval(refresh, SCAN_MS) end
end

---@param cart integer
---@param name LidName
---@param open boolean
---@param ms? integer
function Dressing.swing(cart, name, open, ms)
    local entry <const> = dressed[cart]

    if not entry or entry.open[name] == open then return end

    entry.open[name] = open
    Station.swing(entry.lids[name], GetEntityHeading(cart), open, ms or SWING_MS)
end

---@param cart integer
function Dressing.close(cart)
    local entry <const> = dressed[cart]

    if not entry then return end

    for name in pairs(entry.lids) do
        entry.open[name] = false
        pose(cart, name, false)
    end
end

---@param cart integer
function Dressing.ensure(cart)
    track(cart)

    if not dressed[cart] then dress(cart) end
end

AddStateBagChangeHandler('hotdogLids', '', function(bagName, _, value)
    local cart <const> = GetEntityFromStateBagName(bagName)

    if cart == 0 or not dressed[cart] or type(value) ~= 'table' then return end

    for name in pairs(stand.kitchen.lids) do
        CreateThread(function() Dressing.swing(cart, name, value[name] == true) end)
    end
end)

AddStateBagChangeHandler('hotdogOwner', '', function(bagName, _, owner)
    if not owner then return end

    CreateThread(function()
        local deadline <const> = GetGameTimer() + STREAM_WAIT_MS
        local cart = GetEntityFromStateBagName(bagName)

        while cart == 0 and GetGameTimer() < deadline do
            Wait(100)
            cart = GetEntityFromStateBagName(bagName)
        end

        if cart ~= 0 then track(cart) end
    end)
end)

for _, object in ipairs(GetGamePool('CObject')) do
    if GetEntityModel(object) == cartModel and Entity(object).state.hotdogOwner then track(object) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for cart in pairs(dressed) do undress(cart) end
end)

return Dressing
