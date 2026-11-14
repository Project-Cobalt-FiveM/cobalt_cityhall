local Work <const> = require 'client.work'

local TONGS_PITCH <const> = 25.0
local TONGS_REACH <const> = vec3(0.0, -0.24, 0.0)
local LID_OPEN <const> = 100.0

local Station <const> = {}

---@param name string
---@param set string
function Station.cue(name, set)
    PlaySoundFrontend(-1, name, set, true)
end

---@param name string
---@param set string
---@return integer id stop it with `Station.stopSound`
function Station.loopSound(name, set)
    local id <const> = GetSoundId()

    PlaySoundFrontend(id, name, set, true)

    return id
end

---@param id integer?
function Station.stopSound(id)
    if not id then return end

    StopSound(id)
    ReleaseSoundId(id)
end

---@param cart integer
---@param offset vector3
---@return vector3
function Station.at(cart, offset)
    return GetOffsetFromEntityInWorldCoords(cart, offset.x, offset.y, offset.z)
end

---@param yaw number degrees around the world's up axis
---@param pitch number degrees around the entity's own X axis
---@param offset vector3 in the entity's space
---@return vector3
local function turn(yaw, pitch, offset)
    local p <const>, y <const> = math.rad(pitch), math.rad(yaw)
    local tilted <const> = vec3(offset.x, offset.y * math.cos(p) - offset.z * math.sin(p), offset.y * math.sin(p) + offset.z * math.cos(p))

    return vec3(tilted.x * math.cos(y) - tilted.y * math.sin(y), tilted.x * math.sin(y) + tilted.y * math.cos(y), tilted.z)
end

---@param entity integer
---@param yaw number
---@param pitch number
function Station.orient(entity, yaw, pitch)
    local hy <const>, hp <const> = math.rad(yaw) / 2, math.rad(pitch) / 2
    local sz <const>, cz <const> = math.sin(hy), math.cos(hy)
    local sx <const>, cx <const> = math.sin(hp), math.cos(hp)

    SetEntityQuaternion(entity, cz * sx, sz * sx, sz * cx, cz * cx)
end

---@class StationPose
---@field base vector3 where the bottom of the prop would sit unturned
---@field yaw number
---@field pitch? number turns the prop around its own X axis, through its centre
---@field radius? number height of the prop's centre above its origin

---@param entity integer
---@param pose StationPose
function Station.place(entity, pose)
    local pitch <const> = pose.pitch or 0.0
    local centre <const> = vec3(0.0, 0.0, pose.radius or 0.0)
    local origin <const> = pose.base + centre - turn(pose.yaw, pitch, centre)

    SetEntityCoordsNoOffset(entity, origin.x, origin.y, origin.z, false, false, false)
    Station.orient(entity, pose.yaw, pitch)
end

---@param model string
---@param coords vector3
---@param yaw number
---@param standIn? string used when the game has no `model`
---@return integer?
function Station.prop(model, coords, yaw, standIn)
    local hash <const> = Work.loadModel(standIn and not IsModelInCdimage(joaat(model)) and standIn or model)

    if not hash then return end

    local entity <const> = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)

    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    Station.orient(entity, yaw, 0.0)

    return entity
end

---@param entity integer?
function Station.remove(entity)
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

---@param entity integer
---@param model string
---@param standIn? string
---@return integer entity the replacement, or the original when the model is missing
function Station.swap(entity, model, standIn)
    local replacement <const> = Station.prop(model, GetEntityCoords(entity), 0.0, standIn)

    if not replacement then return entity end

    local x <const>, y <const>, z <const>, w <const> = GetEntityQuaternion(entity)

    SetEntityQuaternion(replacement, x, y, z, w)
    DeleteEntity(entity)

    return replacement
end

---@param model string
---@return number radius half the model's height
function Station.radius(model)
    local low <const>, high <const> = GetModelDimensions(joaat(model))

    return (high.z - low.z) / 2
end

---@param fx StandFx
---@param coords vector3
---@return integer
function Station.startFx(fx, coords)
    lib.requestNamedPtfxAsset(fx.asset)
    UseParticleFxAssetNextCall(fx.asset)

    local handle <const> = StartParticleFxLoopedAtCoord(
        fx.name,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        fx.scale,
        false, false, false, false
    )

    RemoveNamedPtfxAsset(fx.asset)

    return handle
end

---@param handle integer?
function Station.stopFx(handle)
    if handle then StopParticleFxLooped(handle, false) end
end

---@param t number
---@return number
local function ease(t)
    return 1 - (1 - t) ^ 3
end

---@param tongs integer?
---@param tip vector3 where the jaws close
---@param yaw number the cart's heading; the jaws point along its -Y, away from the vendor
function Station.grip(tongs, tip, yaw)
    if not tongs then return end

    local hinge <const> = tip - turn(yaw, TONGS_PITCH, TONGS_REACH)

    SetEntityCoordsNoOffset(tongs, hinge.x, hinge.y, hinge.z, false, false, false)
    Station.orient(tongs, yaw, TONGS_PITCH)
end

---@class StationMove : StationPose
---@field ms integer
---@field lift number meters the arc rises at its middle
---@field tongs? integer carried along, gripping the food
---@field cartYaw? number the cart's heading, needed with tongs

---@param entity integer
---@param move StationMove
function Station.move(entity, move)
    local from <const> = GetEntityCoords(entity) - (vec3(0.0, 0.0, move.radius or 0.0) - turn(move.yaw, move.pitch or 0.0, vec3(0.0, 0.0, move.radius or 0.0)))
    local began <const> = GetGameTimer()

    while DoesEntityExist(entity) do
        local t <const> = math.min(1.0, (GetGameTimer() - began) / move.ms)
        local base <const> = from + (move.base - from) * ease(t) + vec3(0.0, 0.0, move.lift * math.sin(math.pi * t))

        Station.place(entity, { base = base, yaw = move.yaw, pitch = move.pitch, radius = move.radius })

        if move.tongs then Station.grip(move.tongs, base + vec3(0.0, 0.0, move.radius or 0.0), move.cartYaw or move.yaw) end
        if t >= 1.0 then return end

        Wait(0)
    end
end

---@param lid integer?
---@param yaw number the cart's heading
---@param open boolean
---@param ms integer
function Station.swing(lid, yaw, open, ms)
    if not lid then return end

    local from <const> = open and 0.0 or LID_OPEN
    local to <const> = open and LID_OPEN or 0.0
    local began <const> = GetGameTimer()

    while DoesEntityExist(lid) do
        local t <const> = math.min(1.0, (GetGameTimer() - began) / ms)

        Station.orient(lid, yaw, from + (to - from) * ease(t))

        if t >= 1.0 then return end

        Wait(0)
    end
end

return Station
