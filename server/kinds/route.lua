local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Payout <const> = require 'server.payout'
local Vehicles <const> = require 'server.vehicles'
local Jobs <const> = require 'shared.jobs'

local REACH_SLACK <const> = 3.0
local CHAIN_START_CHOICES <const> = 5
local LOAD_RANGE <const> = 40.0
local AT_VEHICLE <const> = 7.0

---@class RouteTask
---@field stops integer[]
---@field at integer
---@field actions integer
---@field from vector3
---@field loaded? boolean
---@field boxes integer boxes in the cargo vehicle
---@field cargoVehicle? integer

---@param stops JobStop[]
---@param from vector3
---@param taken table<integer, true>
---@return integer[]
local function nearestFirst(stops, from, taken)
    local order <const> = {}

    for index in ipairs(stops) do
        if not taken[index] then order[#order + 1] = index end
    end

    table.sort(order, function(a, b)
        return #(stops[a].coords.xyz - from) < #(stops[b].coords.xyz - from)
    end)

    return order
end

---@param stops JobStop[]
---@param indexes integer[]
---@param from vector3
---@return integer[]
local function chainFrom(stops, indexes, from)
    local left <const> = {}
    local picked <const> = {}
    local at = from

    for _, index in ipairs(indexes) do left[index] = true end

    while next(left) do
        ---@type integer?
        local nearest

        for index in pairs(left) do
            if not nearest or #(stops[index].coords.xyz - at) < #(stops[nearest].coords.xyz - at) then
                nearest = index
            end
        end

        picked[#picked + 1] = nearest
        left[nearest] = nil
        at = stops[nearest].coords.xyz
    end

    return picked
end

---@param route RouteConfig
---@param from vector3
---@param previous? integer
---@return integer[]
local function pickSite(route, from, previous)
    local last <const> = previous and route.stops[previous].site
    local sites <const> = {}
    local members <const> = {}

    for index, stop in ipairs(route.stops) do
        if not members[stop.site] then
            members[stop.site] = {}

            if stop.site ~= last then sites[#sites + 1] = stop.site end
        end

        local list <const> = members[stop.site]

        list[#list + 1] = index
    end

    local site <const> = #sites > 0 and sites[math.random(1, #sites)] or last

    return chainFrom(route.stops, members[site], from)
end

---@param route RouteConfig
---@param from vector3
---@param previous? integer
---@return integer[]
local function pickStops(route, from, previous)
    if route.bySite then return pickSite(route, from, previous) end

    local taken <const> = { [previous or 0] = true }
    local picked <const> = {}

    if route.chain then
        local starts <const> = nearestFirst(route.stops, from, taken)
        local first <const> = starts[math.random(1, math.min(CHAIN_START_CHOICES, #starts))]

        picked[1] = first
        taken[first] = true

        while #picked < route.length do
            local next <const> = nearestFirst(route.stops, route.stops[picked[#picked]].coords.xyz, taken)[1]

            if not next then break end

            picked[#picked + 1] = next
            taken[next] = true
        end

        return picked
    end

    while #picked < route.length do
        local index <const> = math.random(1, #route.stops)

        if not taken[index] then
            picked[#picked + 1] = index
            taken[index] = true
        end
    end

    return picked
end

---@param task RouteTask
---@return integer
local function currentStop(task)
    return task.stops[task.at]
end
---@param shift Shift
---@return boolean
local function needsLoad(shift)
    return shift.def.route.cargo ~= nil and not shift.task.loaded
end

---@param task RouteTask
---@param boxes integer
local function setCargo(task, boxes)
    task.boxes = boxes

    if task.cargoVehicle and DoesEntityExist(task.cargoVehicle) then
        Entity(task.cargoVehicle).state:set('cobalt_cityhall:cargo', boxes, true)
    end
end

---@param shift Shift
---@param coords vector3
---@return integer? vehicle the crew vehicle to work at
---@return string? reason
local function workVehicle(shift, coords)
    local task <const> = shift.task --[[@as RouteTask]]
    local route <const> = shift.def.route --[[@as RouteConfig]]
    local spec <const> = shift.def.vehicle

    if not spec then return end

    if not Vehicles.crewHasVehicle(shift) then
        return nil, ('Take a %s from the clerk at %s first'):format(spec.label, shift.def.site.label)
    end

    if route.vehicleWithin and not Vehicles.crewVehicleNear(shift, coords, route.vehicleWithin) then
        return nil, ('Bring the %s closer'):format(spec.label)
    end

    if not route.atVehicle then return end

    local vehicle <const> = Vehicles.nearestCrewVehicle(shift, Registry.coords(shift.src), AT_VEHICLE)

    if not vehicle then return nil, ('Stand at the back of the %s'):format(spec.label) end

    if task.boxes > 0 and task.cargoVehicle ~= vehicle then
        return nil, ('The cargo is in the other %s'):format(spec.label)
    end

    return vehicle
end

local Route <const> = {}

---@param shift Shift
function Route.assign(shift)
    local task <const> = shift.task --[[@as RouteTask]]
    local route <const> = shift.def.route --[[@as RouteConfig]]
    local from <const> = task.from or shift.def.site.coords.xyz
    local previous <const> = task.stops and task.stops[#task.stops]

    task.stops = pickStops(route, from, previous)
    task.at = 1
    task.actions = 0
    task.from = from
    task.loaded = false

    setCargo(task, 0)

    task.cargoVehicle = nil
end

---@param shift Shift
---@return TaskView
function Route.view(shift)
    local task <const> = shift.task --[[@as RouteTask]]
    local route <const> = shift.def.route --[[@as RouteConfig]]

    if needsLoad(shift) then
        local site <const> = shift.def.site
        local total <const> = route.cargo.boxes

        return {
            title = ('Load the cargo at %s'):format(site.label),
            label = site.label,
            coords = site.coords.xyz,
            radius = LOAD_RANGE,
            step = ('Box %d of %d'):format(task.boxes + 1, total),
            stage = 'load',
            progress = { done = task.boxes, total = total },
        }
    end

    local stop <const> = route.stops[currentStop(task)]
    local single <const> = #task.stops == 1
    local total <const> = single and route.actions or #task.stops
    local done <const> = single and task.actions or task.at - 1
    local verb <const> = route.cargo and 'Deliver to' or ('Next %s:'):format(route.unit)

    local view <const> = {
        title = ('%s %s'):format(verb, stop.label),
        label = stop.label,
        coords = stop.coords.xyz,
        radius = route.radius,
        stage = 'stop',
        task = stop.task,
        heading = type(stop.coords) == 'vector4' and stop.coords.w or nil,
        marker = route.marker,
    }

    if total > 1 then
        local unit <const> = route.unit:sub(1, 1):upper() .. route.unit:sub(2)

        view.step = ('%s %d of %d'):format(unit, done + 1, total)
        view.progress = { done = done, total = total }
    end

    return view
end

---@param shift Shift
---@return integer? duration
---@return string? reason
local function beginLoad(shift)
    local site <const> = shift.def.site
    local route <const> = shift.def.route --[[@as RouteConfig]]

    if not route.load or not needsLoad(shift) then return nil, 'The cargo is already loaded' end

    if not Registry.nearFlat(shift.src, site.coords, LOAD_RANGE) then
        return nil, ('Load the cargo at %s'):format(site.label)
    end

    local vehicle <const>, problem <const> = workVehicle(shift, site.coords)

    if problem then return nil, problem end

    local duration <const> = Jobs.rollDuration(route.load.duration)

    shift.task.cargoVehicle = vehicle

    Vehicles.openDoors(shift, vehicle --[[@as integer]])
    Registry.startAction(shift, 'load', duration)

    return duration
end

---@param shift Shift
---@return integer? duration
---@return string? reason
local function beginStop(shift)
    local task <const> = shift.task --[[@as RouteTask]]
    local route <const> = shift.def.route --[[@as RouteConfig]]

    if needsLoad(shift) then
        return nil, ('Load the cargo at %s first'):format(shift.def.site.label)
    end

    local stop <const> = route.stops[currentStop(task)]

    if not Registry.nearFlat(shift.src, stop.coords, route.radius + REACH_SLACK) then
        return nil, ('You are not at %s yet'):format(stop.label)
    end

    local vehicle, problem = workVehicle(shift, stop.coords)

    if problem then return nil, problem end

    local action <const> = route.tasks?[stop.task] or route.action
    local duration <const> = Jobs.rollDuration(action.duration)

    if vehicle then Vehicles.openDoors(shift, vehicle) end

    Registry.startAction(shift, 'stop', duration)

    return duration
end

---@param shift Shift
---@param target { type: string }
---@return integer? duration
---@return string? reason
function Route.begin(shift, target)
    if target.type == 'load' then return beginLoad(shift) end

    return beginStop(shift)
end

---@param shift Shift
---@param coords vector3
---@return Shift[]
local function workersNear(shift, coords)
    local list <const> = {}

    for _, member in ipairs(Registry.crewShifts(shift)) do
        if member == shift or Registry.near(member.src, coords, config.crew.shareRange) then
            list[#list + 1] = member
        end
    end

    return list
end

---@param shift Shift
---@return boolean
local function finishLoad(shift)
    local task <const> = shift.task --[[@as RouteTask]]
    local route <const> = shift.def.route --[[@as RouteConfig]]

    if not Registry.endAction(shift, 'load') then return false end
    if not needsLoad(shift) then return false end
    if not Registry.nearFlat(shift.src, shift.def.site.coords, LOAD_RANGE + REACH_SLACK) then return false end

    setCargo(task, task.boxes + 1)

    if task.boxes < route.cargo.boxes then return true end

    task.loaded = true

    local stop <const> = route.stops[currentStop(task)]
    local text <const> = ('Cargo loaded. Drive it to %s, the route is on your GPS.'):format(stop.label)

    Registry.notifyCrew(shift, text, 'success')

    return true
end

---@param shift Shift
---@param workers Shift[]
local function finishRoute(shift, workers)
    local route <const> = shift.def.route --[[@as RouteConfig]]

    if route.pay.routeBonus then
        Payout.split(workers, route.pay.routeBonus, 'route finished')
    end

    Route.assign(shift)

    if route.cargo then
        local text <const> = ('Delivery done. Drive back to %s for the next load.'):format(shift.def.site.label)

        return Registry.notifyCrew(shift, text)
    end

    local next <const> = route.stops[currentStop(shift.task)]

    if route.bySite then
        local site <const> = next.label:match('^[^,]+')

        return Registry.notifyCrew(shift, ('Site finished. Head to the %s next.'):format(site), 'success')
    end

    Registry.notifyCrew(shift, ('All done here. Next %s: %s.'):format(route.unit, next.label))
end

---@param shift Shift
---@return boolean
local function finishStop(shift)
    local task <const> = shift.task --[[@as RouteTask]]
    local route <const> = shift.def.route --[[@as RouteConfig]]
    local stop <const> = route.stops[currentStop(task)]

    if not Registry.endAction(shift, 'stop') then return false end
    if needsLoad(shift) then return false end
    if not Registry.nearFlat(shift.src, stop.coords, route.radius + REACH_SLACK) then return false end

    task.actions += 1

    if route.cargo then setCargo(task, math.max(task.boxes - 1, 0)) end

    local stopDone <const> = task.actions >= route.actions
    local amount = route.pay.perAction

    if stopDone and route.pay.perMeter then
        amount += route.pay.perMeter * #(stop.coords.xyz - task.from)
    end

    local workers <const> = workersNear(shift, stop.coords.xyz)

    Payout.split(workers, amount, stop.label)

    for _, worker in ipairs(workers) do worker.done += 1 end

    if not stopDone then return true end

    task.from = stop.coords.xyz
    task.actions = 0
    task.at += 1

    if task.at > #task.stops then
        finishRoute(shift, workers)

        return true
    end

    local next <const> = route.stops[currentStop(task)]

    Registry.notifyCrew(shift, ('Next %s: %s.'):format(route.unit, next.label))

    return true
end

---@param shift Shift
---@param target { type: string }
---@return boolean
function Route.finish(shift, target)
    if target.type == 'load' then return finishLoad(shift) end

    return finishStop(shift)
end

---@param shift Shift
---@param why LossReason
---@return string? lost what the crew lost, as a sentence
function Route.reset(shift, why)
    local task <const> = shift.task --[[@as RouteTask]]

    if why ~= 'vehicle' or not shift.def.route.cargo or task.boxes == 0 then return end

    task.loaded = false
    task.actions = 0

    setCargo(task, 0)

    task.cargoVehicle = nil

    return ('The cargo is lost. Load a new one at %s.'):format(shift.def.site.label)
end

return Route
