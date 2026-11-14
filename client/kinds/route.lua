local Work <const> = require 'client.work'
local CrewVehicle <const> = require 'client.crewvehicle'
local play <const> = require 'client.cues'
local showMarker <const> = require 'client.marker'

local INTERACT_KEY <const> = 38
local VEHICLE_REACH <const> = 3.0
local LOAD_HINT <const> = 'Walk to the back of the truck and load the cargo.'

---@type JobDefinition?
local def
---@type TaskView?
local current
---@type CPoint?
local point
local vehicleOut = false
local loadHinted = false
---@type fun()?
local hideMarker
---@type string[]
local optionNames <const> = {}

local function clear()
    if hideMarker then hideMarker() end

    hideMarker = nil

    if point then
        point:remove()
        exports.cobalt_core:HideTextUI()
    end

    point = nil
end

---@param task TaskView
---@return boolean
local function inTaskArea(task)
    return #(GetEntityCoords(cache.ped).xy - task.coords.xy) <= task.radius
end

---@param stage string
---@param action JobAction
---@return table
local function vehicleOption(stage, action)
    local name <const> = ('cobalt_cityhall:%s'):format(stage)

    optionNames[#optionNames + 1] = name

    return {
        name = name,
        label = action.prompt,
        icon = 'fa-solid fa-box',
        distance = VEHICLE_REACH,
        canInteract = function(entity)
            if cache.vehicle or not current or current.stage ~= stage then return false end

            return inTaskArea(current) and CrewVehicle.is(entity)
        end,
        onSelect = function()
            CreateThread(function() Work.run({ type = stage }, action) end)
        end,
    }
end

---@param route RouteConfig
local function addVehicleOptions(route)
    local options <const> = { vehicleOption('stop', route.action) }

    if route.load then options[#options + 1] = vehicleOption('load', route.load) end

    exports.ox_target:addGlobalVehicle(options)
end

---@param task TaskView
---@return JobAction
local function actionFor(task)
    local route <const> = (def --[[@as JobDefinition]]).route --[[@as RouteConfig]]

    return route.tasks?[task.task] or route.action
end

---@param action JobAction
---@param task TaskView
local function watchPoint(action, task)
    local text <const> = ('[E] %s'):format(action.prompt)

    point = lib.points.new({
        coords = task.coords,
        distance = task.radius,
        onEnter = function()
            exports.cobalt_core:ShowTextUI(text)
        end,
        onExit = function()
            exports.cobalt_core:HideTextUI()
        end,
        nearby = function()
            if not IsControlJustReleased(0, INTERACT_KEY) then return end

            if cache.vehicle then
                return exports.cobalt_core:Notify('Get out of the vehicle first', 'error')
            end

            local watched <const> = point --[[@as CPoint]]

            exports.cobalt_core:HideTextUI()

            CreateThread(function()
                if task.heading then SetEntityHeading(cache.ped, task.heading) end

                if Work.run({ type = 'stop' }, action) then play('checkpoint') end

                if point == watched and watched.currentDistance then exports.cobalt_core:ShowTextUI(text) end
            end)
        end,
    })
end

---@param task TaskView
local function watchArrival(task)
    local vehicle <const> = ((def --[[@as JobDefinition]]).vehicle --[[@as JobVehicle]]).label

    loadHinted = false

    point = lib.points.new({
        coords = task.coords,
        distance = task.radius,
        onEnter = function()
            if task.stage ~= 'stop' then return end

            local text <const> = 'You reached %s. Park, then unload the cargo from the back of the %s.'

            exports.cobalt_core:Notify(text:format(task.label, vehicle), 'inform')
        end,
        nearby = function()
            if task.stage ~= 'load' or loadHinted or not vehicleOut then return end

            loadHinted = true

            exports.cobalt_core:Notify(LOAD_HINT, 'inform')
        end,
    })
end

local Route <const> = {}

---@param job JobDefinition
function Route.enter(job)
    def = job

    local route <const> = job.route --[[@as RouteConfig]]

    if route.atVehicle then addVehicleOptions(route) end
end

---@param _ JobDefinition
---@param view ShiftView
function Route.update(_, view)
    local task <const> = view.task
    local previous <const> = current

    current = task
    vehicleOut = view.vehicle ~= nil

    if not task then return clear() end

    if previous and previous.stage == task.stage and #(previous.coords - task.coords) < 0.5 then return end

    clear()

    if ((def --[[@as JobDefinition]]).route --[[@as RouteConfig]]).atVehicle then return watchArrival(task) end

    if task.marker then hideMarker = showMarker(task.coords) end

    watchPoint(actionFor(task), task)
end

function Route.leave()
    clear()

    if #optionNames > 0 then exports.ox_target:removeGlobalVehicle(optionNames) end

    table.wipe(optionNames)

    def, current, vehicleOut, loadHinted = nil, nil, false, false
end

return Route
