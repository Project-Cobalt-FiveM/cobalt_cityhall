local Jobs <const> = require 'shared.jobs'
local Work <const> = require 'client.work'

local REAR_DOORS <const> = { 2, 3, 5 }
local SWEEP_MS <const> = 2000
local STREAM_WAIT_MS <const> = 2000
---@type string
local ANY_BAG <const> = nil

---@param hash integer
---@return integer
local function modelKey(hash)
    return hash & 0xFFFFFFFF
end

---@type table<integer, RouteCargo>
local cargoByModel <const> = {}

for _, def in pairs(Jobs.byId) do
    if def.route?.cargo and def.vehicle then
        cargoByModel[modelKey(joaat(def.vehicle.model))] = def.route.cargo
    end
end

---@type table<integer, integer[]>
local loaded <const> = {}
---@type integer?
local sweep

---The first box goes in the front row, so the boxes nearest the doors come off first.
---@param spec RouteCargo
---@param index integer
---@return vector3
local function slot(spec, index)
    local size <const> = spec.size
    local place <const> = index - 1
    local column <const> = place % spec.columns
    local depth <const> = spec.rows - 1 - (place // spec.columns) % spec.rows
    local layer <const> = place // (spec.columns * spec.rows)
    local x <const> = (column - (spec.columns - 1) / 2) * (size.x + spec.gap)
    local y <const> = spec.doorLine + spec.fromDoors + size.y / 2 + depth * (size.y + spec.gap)
    local z <const> = spec.floor + size.z / 2 + layer * size.z

    return vec3(x, y, z)
end

---@param vehicle integer
local function unload(vehicle)
    for _, box in ipairs(loaded[vehicle] or {}) do Work.delete(box) end

    loaded[vehicle] = nil
end

local function startSweep()
    if sweep then return end

    sweep = SetInterval(function()
        for vehicle in pairs(loaded) do
            if not DoesEntityExist(vehicle) then unload(vehicle) end
        end

        if next(loaded) then return end

        ClearInterval(sweep --[[@as integer]])
        sweep = nil
    end, SWEEP_MS)
end

---@param spec RouteCargo
---@param vehicle integer
---@param boxes integer[]
---@param count integer
local function fill(spec, vehicle, boxes, count)
    local hash <const> = Work.loadModel(spec.model)

    if not hash then return end

    while #boxes < count and DoesEntityExist(vehicle) do
        local offset <const> = slot(spec, #boxes + 1)
        local coords <const> = GetEntityCoords(vehicle)
        local box <const> = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)

        SetEntityCollision(box, false, false)
        AttachEntityToEntity(
            box,
            vehicle,
            0,
            offset.x, offset.y, offset.z,
            0.0, 0.0, 0.0,
            false, false, false, false, 2, true
        )

        boxes[#boxes + 1] = box
    end

    SetModelAsNoLongerNeeded(hash)
end

---@param vehicle integer
---@param count integer
local function sync(vehicle, count)
    local spec <const> = cargoByModel[modelKey(GetEntityModel(vehicle))]

    if not spec then return end

    if count <= 0 then return unload(vehicle) end

    local boxes <const> = loaded[vehicle] or {}

    loaded[vehicle] = boxes

    while #boxes > count do Work.delete(table.remove(boxes)) end

    fill(spec, vehicle, boxes, count)
    startSweep()
end

AddStateBagChangeHandler('cobalt_cityhall:cargo', ANY_BAG, function(bagName, _, value)
    CreateThread(function()
        local deadline <const> = GetGameTimer() + STREAM_WAIT_MS
        local vehicle = GetEntityFromStateBagName(bagName)

        while vehicle == 0 and GetGameTimer() < deadline do
            Wait(100)
            vehicle = GetEntityFromStateBagName(bagName)
        end

        if vehicle ~= 0 then sync(vehicle, value or 0) end
    end)
end)

RegisterNetEvent('cobalt_cityhall:rearDoors', function(netId, open)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local vehicle <const> = NetToVeh(netId)

    for _, door in ipairs(REAR_DOORS) do
        if GetIsDoorValid(vehicle, door) then
            if open then
                SetVehicleDoorOpen(vehicle, door, false, false)
            else
                SetVehicleDoorShut(vehicle, door, false)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for vehicle in pairs(loaded) do unload(vehicle) end
end)
