local Work <const> = require 'client.work'
local CrewVehicle <const> = require 'client.crewvehicle'

local BIN_REACH <const> = 2.5
local VEHICLE_REACH <const> = 3.0
local ZONE_COLOUR <const> = 25
local ZONE_ALPHA <const> = 90

---@type JobDefinition?
local def
---@type TaskView?
local current
local carrying = false
local loadingBag = false
---@type integer?
local zoneBlip
---@type integer?
local bag
---@type CPoint?
local point
---@type table<integer, true>
local emptied <const> = {}

local BIN_OPTION <const> = 'cobalt_cityhall:emptyBin'
local THROW_OPTION <const> = 'cobalt_cityhall:throwBag'
local OPEN_OPTION <const> = 'cobalt_cityhall:openBack'

---@return boolean
local function inZone()
    if not current then return false end

    return #(GetEntityCoords(cache.ped).xy - current.coords.xy) <= current.radius
end

local function dropBag()
    Work.delete(bag)
    bag = nil
end

local function holdBag()
    if bag or loadingBag then return end

    local spec <const> = ((def --[[@as JobDefinition]]).collect --[[@as CollectConfig]]).bag

    loadingBag = true

    CreateThread(function()
        local hash <const> = Work.loadModel(spec.model)

        loadingBag = false

        if not hash or not carrying then return end

        local coords <const> = GetEntityCoords(cache.ped)

        bag = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)

        SetModelAsNoLongerNeeded(hash)
        AttachEntityToEntity(
            bag,
            cache.ped,
            GetPedBoneIndex(cache.ped, spec.bone),
            spec.pos.x, spec.pos.y, spec.pos.z,
            spec.rot.x, spec.rot.y, spec.rot.z,
            true, true, false, true, 1, true
        )
    end)
end

local function clearZone()
    if zoneBlip then RemoveBlip(zoneBlip) end
    if point then point:remove() end

    zoneBlip, point = nil, nil
end

---@param task TaskView
local function showZone(task)
    zoneBlip = AddBlipForRadius(task.coords.x, task.coords.y, task.coords.z, task.radius)

    SetBlipColour(zoneBlip, ZONE_COLOUR)
    SetBlipAlpha(zoneBlip, ZONE_ALPHA)

    local text <const> = ('You are in %s. Empty the bins and dumpsters inside the circle into the %s.'):format(
        task.label,
        ((def --[[@as JobDefinition]]).vehicle --[[@as JobVehicle]]).label
    )

    point = lib.points.new({
        coords = task.coords,
        distance = task.radius,
        onEnter = function() exports.cobalt_core:Notify(text, 'inform') end,
    })
end

---@param job JobDefinition
local function addTargets(job)
    local collect <const> = job.collect --[[@as CollectConfig]]

    exports.ox_target:addModel(collect.models, {
        {
            name = BIN_OPTION,
            label = collect.empty.prompt,
            icon = 'fa-solid fa-trash',
            distance = BIN_REACH,
            canInteract = function(entity)
                if cache.vehicle or carrying or emptied[entity] then return false end

                return inZone()
            end,
            onSelect = function(data)
                local entity <const> = data.entity

                CreateThread(function()
                    local target <const> = { type = 'bin', coords = GetEntityCoords(entity) }

                    if Work.run(target, collect.empty) then emptied[entity] = true end
                end)
            end,
        },
    })

    exports.ox_target:addGlobalVehicle({
        {
            name = OPEN_OPTION,
            label = collect.open.prompt,
            icon = 'fa-solid fa-dumpster',
            distance = VEHICLE_REACH,
            canInteract = function(entity)
                if cache.vehicle or current?.open then return false end

                return CrewVehicle.is(entity)
            end,
            onSelect = function()
                CreateThread(function() Work.run({ type = 'open' }, collect.open) end)
            end,
        },
        {
            name = THROW_OPTION,
            label = collect.throw.prompt,
            icon = 'fa-solid fa-dumpster',
            distance = VEHICLE_REACH,
            canInteract = function(entity)
                if not carrying or cache.vehicle or not current?.open then return false end

                return CrewVehicle.is(entity)
            end,
            onSelect = function()
                CreateThread(function() Work.run({ type = 'throw' }, collect.throw) end)
            end,
        },
    })
end

local Collect <const> = {}

---@param job JobDefinition
function Collect.enter(job)
    def = job

    addTargets(job)
end

---@param _ JobDefinition
---@param view ShiftView
function Collect.update(_, view)
    local task <const> = view.task
    local previous <const> = current

    current = task
    carrying = view.carrying == true

    if carrying then holdBag() else dropBag() end

    if not task then return clearZone() end
    if previous and previous.label == task.label and zoneBlip then return end

    clearZone()
    table.wipe(emptied)
    showZone(task)
end

function Collect.leave()
    clearZone()
    dropBag()

    exports.ox_target:removeModel(((def --[[@as JobDefinition]]).collect --[[@as CollectConfig]]).models, BIN_OPTION)
    exports.ox_target:removeGlobalVehicle({ OPEN_OPTION, THROW_OPTION })
    table.wipe(emptied)

    def, current, carrying = nil, nil, false
end

return Collect
