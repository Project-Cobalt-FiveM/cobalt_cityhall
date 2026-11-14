local Registry <const> = require 'server.registry'
local Jobs <const> = require 'shared.jobs'

local STATE_KEY <const> = 'cobalt_cityhall:prop'
local HOLD_EVENT <const> = 'cobalt_cityhall:holdProp'

local Props <const> = {}

---@param value unknown
---@return boolean
local function isProp(value)
    if type(value) ~= 'table' then return false end

    return type(value.model) == 'string' and math.type(value.bone) == 'integer' and type(value.pos) == 'vector3'
end

---@param node table
---@param into table<string, JobProp>
local function collect(node, into)
    for _, value in pairs(node) do
        if isProp(value) then
            into[value.model] = value
        elseif type(value) == 'table' then
            collect(value, into)
        end
    end
end

---@type table<string, table<string, JobProp>> the props each job's workers hold, by job id and model
local allowed <const> = {}

for id, def in pairs(Jobs.byId) do
    allowed[id] = {}
    collect(def, allowed[id])
end

---@param src integer
function Props.release(src)
    local state <const> = Player(src).state

    if state[STATE_KEY] then state:set(STATE_KEY, nil, true) end
end

RegisterNetEvent(HOLD_EVENT, function(model)
    local src <const> = source
    local shift <const> = Registry.get(src)
    local spec <const> = shift and type(model) == 'string' and allowed[shift.def.id][model] or nil

    if spec then
        Player(src).state:set(STATE_KEY, spec, true)
    else
        Props.release(src)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, id in ipairs(GetPlayers()) do Props.release(tonumber(id) --[[@as integer]]) end
end)

return Props
