local STATE_KEY <const> = 'cobalt_cityhall:prop'
local HOLD_EVENT <const> = 'cobalt_cityhall:holdProp'

local Props <const> = {}

---@type table<integer, integer> the local prop drawn in each player's hand, by server id
local drawn <const> = {}
---@type table<integer, integer> changes per player, so a slow model load never attaches an outdated prop
local changes <const> = {}

---@param serverId integer
local function remove(serverId)
    local prop <const> = drawn[serverId]

    drawn[serverId] = nil

    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
end

---@param ped integer
---@param spec JobProp
---@return integer?
local function attach(ped, spec)
    local hash <const> = joaat(spec.model)

    if not IsModelInCdimage(hash) then
        lib.print.warn(('%s is not a model in the game files'):format(spec.model))
        return
    end

    lib.requestModel(hash)

    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local coords <const> = GetEntityCoords(ped)
    local prop <const> = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, spec.bone),
        spec.pos.x, spec.pos.y, spec.pos.z,
        spec.rot.x, spec.rot.y, spec.rot.z,
        true, true, false, true, spec.rotOrder or 0, true
    )

    return prop
end

---@param serverId integer
---@param spec JobProp?
local function draw(serverId, spec)
    local change <const> = (changes[serverId] or 0) + 1

    changes[serverId] = change
    remove(serverId)

    if not spec then return end

    local player <const> = GetPlayerFromServerId(serverId)

    if player == -1 then return end

    CreateThread(function()
        local prop <const> = attach(GetPlayerPed(player), spec)

        if not prop then return end

        if changes[serverId] ~= change then
            DeleteEntity(prop)
            return
        end

        drawn[serverId] = prop
    end)
end

---Puts the prop in the local player's hand; every client draws its own local copy.
---@param spec JobProp
function Props.hold(spec)
    TriggerServerEvent(HOLD_EVENT, spec.model)
end

function Props.release()
    TriggerServerEvent(HOLD_EVENT)
end

AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _, spec)
    local serverId <const> = tonumber(bagName:match('^player:(%d+)$'))

    if serverId then draw(serverId, spec) end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
    changes[serverId] = nil
    remove(serverId)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for serverId in pairs(drawn) do remove(serverId) end
end)

return Props
