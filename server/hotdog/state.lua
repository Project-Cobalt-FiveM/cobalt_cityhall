local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local REP_KEY <const> = 'hotdog'

---@class HotdogCustomer
---@field id integer
---@field order HotdogOrder
---@field expiresAt integer

---@class HotdogBuild
---@field sausage? 'grill' | 'done'
---@field cookMs integer
---@field sides { [1]: integer, [2]: integer } milliseconds each side spent face down in the oil
---@field side 1 | 2
---@field sideAt integer
---@field grillAt integer
---@field bun? 'grill' | 'done'
---@field bunMs integer
---@field bunAt integer
---@field assembled boolean
---@field sauces table<SauceId, boolean>
---@field squeeze? { id: SauceId, at: integer }

---@class HotdogStand
---@field src integer
---@field entity integer
---@field coords vector3
---@field open boolean
---@field cooking boolean
---@field customers table<integer, HotdogCustomer>
---@field queue integer[]
---@field nextId integer
---@field lastRecruit integer
---@field lastServe integer
---@field lastStep integer
---@field dog HotdogBuild

local State <const> = {
    ---@type table<integer, HotdogStand>
    stands = {},
}

---@return HotdogBuild
function State.freshDog()
    return { cookMs = 0, sides = { 0, 0 }, side = 1, sideAt = 0, grillAt = 0, bunMs = 0, bunAt = 0, assembled = false, sauces = {} }
end

---@param src integer
---@return integer
function State.rep(src)
    local player <const> = Cobalt.Functions.GetPlayer(src)
    local rep <const> = player and player.Functions.GetMetaData('rep')

    return rep?[REP_KEY] or 0
end

---@param src integer
---@param delta integer
---@param max integer
---@return integer rep after the change
function State.addRep(src, delta, max)
    local player <const> = Cobalt.Functions.GetPlayer(src)

    if not player then return 0 end

    local rep <const> = table.clone(player.Functions.GetMetaData('rep') or {})

    rep[REP_KEY] = math.max(0, math.min(max, (rep[REP_KEY] or 0) + delta))
    player.Functions.SetMetaData('rep', rep)

    return rep[REP_KEY]
end

---@param src integer
---@return boolean removed
function State.remove(src)
    local stand <const> = State.stands[src]

    if not stand then return false end

    State.stands[src] = nil

    if DoesEntityExist(stand.entity) then DeleteEntity(stand.entity) end
    if GetPlayerPed(src) ~= 0 then TriggerClientEvent('cobalt_cityhall:hotdog:gone', src) end

    return true
end

return State
