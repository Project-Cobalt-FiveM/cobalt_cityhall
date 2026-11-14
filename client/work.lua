local startSwing <const> = require 'client.swing'

local GROUND_PROBE_HEIGHT <const> = 2.0
local GROUND_TIMEOUT_MS <const> = 1500
local TURN_MS <const> = 600

local Work <const> = {}

local busy = false

---@param action JobAction
---@param duration integer
---@return boolean
local function perform(action, duration)
    local stopSwing <const> = action.swing and startSwing(action.anim, action.swing)

    local done <const> = exports.cobalt_core:Progressbar({
        label = action.label,
        duration = duration,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = action.anim,
        prop = action.prop,
    })

    if stopSwing then stopSwing() end

    return done
end

---@param coords vector3
local function face(coords)
    TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, TURN_MS)
    Wait(TURN_MS)
end

---@param target table
---@param action JobAction
---@param facing? vector3 turns the player toward it before the work starts
---@return boolean
function Work.run(target, action, facing)
    if busy then return false end

    busy = true

    if facing then face(facing) end

    local duration <const> = lib.callback.await('cobalt_cityhall:begin', false, target)
    local ok = false

    if duration then
        if perform(action, duration) then
            ok = lib.callback.await('cobalt_cityhall:finish', false, target)
        else
            lib.callback.await('cobalt_cityhall:cancel', false)
        end
    end

    busy = false

    return ok
end

---@param target table
---@return boolean
function Work.finish(target)
    return lib.callback.await('cobalt_cityhall:finish', false, target)
end

---@param coords vector3 | vector4
---@return number
function Work.groundZ(coords)
    local deadline <const> = GetGameTimer() + GROUND_TIMEOUT_MS

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    while true do
        local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + GROUND_PROBE_HEIGHT, false)

        if found then return z end
        if GetGameTimer() > deadline then return coords.z end

        Wait(50)
    end
end

---@param model string
---@return integer? hash nil when the game has no such model
function Work.loadModel(model)
    local hash <const> = joaat(model)

    if not IsModelInCdimage(hash) then
        lib.print.warn(('%s is not a model in the game files'):format(model))
        return
    end

    return lib.requestModel(hash)
end

---@param model string
---@param coords vector4
---@param scenario? string
---@return integer?
function Work.spawnPed(model, coords, scenario)
    local hash <const> = Work.loadModel(model)

    if not hash then return end

    local ped <const> = CreatePed(4, hash, coords.x, coords.y, Work.groundZ(coords), coords.w, false, true)

    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end

    return ped
end

---@param model string
---@param coords vector3
---@param heading? number
---@return integer?
function Work.spawnProp(model, coords, heading)
    local hash <const> = Work.loadModel(model)

    if not hash then return end

    local prop <const> = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(prop, heading or 0.0)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)

    return prop
end

---@param coords vector3
---@param spec JobBlip
---@param label string
---@param scale? number
---@return integer
function Work.blip(coords, spec, label, scale)
    local blip <const> = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, spec.sprite)
    SetBlipColour(blip, spec.color)
    SetBlipScale(blip, scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)

    return blip
end

---@param entity integer?
function Work.delete(entity)
    if not entity or not DoesEntityExist(entity) then return end

    exports.ox_target:removeLocalEntity(entity)
    DeleteEntity(entity)
end

---@param blip integer?
function Work.removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

---@return boolean
function Work.isDown()
    local revive <const> = LocalPlayer.state.revive

    return IsEntityDead(cache.ped) or (revive ~= nil and revive.state ~= 'alive')
end

return Work
