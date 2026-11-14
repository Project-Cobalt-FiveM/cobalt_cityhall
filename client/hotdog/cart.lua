local Placement <const> = require 'client.hotdog.placement'
local Customers <const> = require 'client.hotdog.customers'
local Kitchen <const> = require 'client.hotdog.kitchen'

local core <const> = exports.cobalt_core

local Cart <const> = {}

---@type StandConfig?
local config
---@type integer?
local cartNet
local open = false
local busy = false

---@return integer?
local function cartEntity()
    if not cartNet or not NetworkDoesEntityExistWithNetworkId(cartNet) then return end

    return NetToObj(cartNet)
end

---@param entity integer
---@return boolean
local function isMine(entity)
    return cartNet ~= nil and Entity(entity).state.hotdogOwner == cache.serverId
end

---@param spec StandPlace | StandPack
---@param duration integer
---@return boolean
local function work(spec, duration)
    return core:Progressbar({
        label = spec.label,
        duration = duration,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = spec.anim,
    })
end

---@param coords vector3
local function face(coords)
    TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, 600)
    Wait(600)
end

local function place()
    if not config then return core:Notify('Sign up for the hot dog stand at City Hall first', 'error') end
    if cartNet then return core:Notify('Your cart is already out. Fold it up before moving it', 'error') end
    if cache.vehicle then return core:Notify('Get out of the vehicle first', 'error') end

    local coords <const>, heading <const> = Placement.run(config)

    if not coords or not heading or not config then return end

    local duration <const> = lib.callback.await('cobalt_cityhall:hotdog:placeStart', false, coords, heading)

    if not duration then return end

    face(coords)

    local done <const> = work(config.place, duration)
    local netId <const> = lib.callback.await('cobalt_cityhall:hotdog:placeFinish', false, done)

    if not netId then return end

    cartNet = netId
    PlaySoundFrontend(-1, 'Prop_Drop_Land', 'DLC_Dmod_Prop_Editor_Sounds', true)
    core:Notify('Cart set up. Open for business when you are ready to cook.', 'success')
end

local function setOpen(state)
    local entity <const> = cartEntity()
    local result <const> = lib.callback.await('cobalt_cityhall:hotdog:setOpen', false, state)

    if not result or not entity or not config then return end

    open = result.open

    if not open then
        Customers.stop('lost')
        return core:Notify('Closed up. People walk on past.', 'inform')
    end

    Customers.start(config, entity, result.rep)
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
    core:Notify(('Open for business. Street rep %d. Busy sidewalks bring more customers.'):format(result.rep), 'success')
end

local function pack()
    local entity <const> = cartEntity()

    if not entity or not config then return end
    if open then setOpen(false) end

    face(GetEntityCoords(entity))

    local duration <const> = lib.callback.await('cobalt_cityhall:hotdog:packStart', false)

    if not duration then return end

    local done <const> = work(config.pack, duration)

    if lib.callback.await('cobalt_cityhall:hotdog:packFinish', false, done) then
        core:Notify('Cart folded up and back in your pockets.', 'success')
    end
end

local function cook()
    local entity <const> = cartEntity()

    if not entity or not config then return end
    if not open then setOpen(true) end

    Kitchen.run(config, entity)
end

---@param action fun()
---@return fun()
local function guarded(action)
    return function()
        if busy then return end

        busy = true
        action()
        busy = false
    end
end

---@type table[]
local options <const> = {
    {
        name = 'cobalt_cityhall:hotdog:cook',
        label = 'Work the grill',
        icon = 'fa-solid fa-fire-burner',
        distance = 2.0,
        canInteract = function(entity) return isMine(entity) and not Kitchen.active() end,
        onSelect = guarded(cook),
    },
    {
        name = 'cobalt_cityhall:hotdog:open',
        label = 'Open for business',
        icon = 'fa-solid fa-store',
        distance = 2.5,
        canInteract = function(entity) return isMine(entity) and not open end,
        onSelect = guarded(function() setOpen(true) end),
    },
    {
        name = 'cobalt_cityhall:hotdog:close',
        label = 'Close up',
        icon = 'fa-solid fa-store-slash',
        distance = 2.5,
        canInteract = function(entity) return isMine(entity) and open and not Kitchen.active() end,
        onSelect = guarded(function() setOpen(false) end),
    },
    {
        name = 'cobalt_cityhall:hotdog:pack',
        label = 'Fold up the cart',
        icon = 'fa-solid fa-box',
        distance = 2.5,
        canInteract = function(entity) return isMine(entity) and not Kitchen.active() end,
        onSelect = guarded(pack),
    },
}

local function reset()
    Kitchen.leave()
    Customers.stop('lost')
    cartNet, open = nil, false
end

---@param stand StandConfig
function Cart.enter(stand)
    config = stand
    exports.ox_target:addModel(stand.model, options)
end

function Cart.leave()
    if config then exports.ox_target:removeModel(config.model, options) end

    reset()
    config = nil
end

exports('UseHotdogStand', function(event)
    if event ~= 'usedItem' or busy then return end

    CreateThread(guarded(place))
end)

RegisterNetEvent('cobalt_cityhall:hotdog:gone', reset)

return Cart
