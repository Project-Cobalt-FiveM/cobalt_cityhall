local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Payout <const> = require 'server.payout'
local Jobs <const> = require 'shared.jobs'

local REACH_SLACK <const> = 2.5
local DEFAULT_RADIUS <const> = 2.0
local SELL_REASON <const> = 'cobalt_cityhall:sell'

---@type table<string, table<string, integer>>
local readyAt <const> = {}

---@param group integer
---@param index integer
---@return string
local function nodeKey(group, index)
    return ('%d:%d'):format(group, index)
end

---@param def JobDefinition
---@param group unknown
---@param index unknown
---@return GatherGroup?
---@return GatherPoint?
local function resolve(def, group, index)
    if math.type(group) ~= 'integer' or math.type(index) ~= 'integer' then return end

    local spec <const> = def.groups[group]
    local point <const> = spec?.points[index]

    if not point then return end

    return spec, point
end

---@param yields GatherYield[]
---@return GatherYield
local function roll(yields)
    local total = 0

    for _, yield in ipairs(yields) do total += yield.weight end

    local pick = math.random() * total

    for _, yield in ipairs(yields) do
        pick -= yield.weight

        if pick <= 0 then return yield end
    end

    return yields[#yields]
end

---@param jobId string
---@param key string
---@return integer remaining milliseconds
local function resting(jobId, key)
    local at <const> = readyAt[jobId]?[key]

    if not at then return 0 end

    return math.max(0, at - GetGameTimer())
end

---@param shift Shift
---@param group integer
---@param index integer
---@param cooldown integer
local function rest(shift, group, index, cooldown)
    local jobId <const> = shift.def.id

    readyAt[jobId] = readyAt[jobId] or {}
    readyAt[jobId][nodeKey(group, index)] = GetGameTimer() + cooldown

    for src, other in pairs(Registry.shifts) do
        if other.def.id == jobId then
            TriggerClientEvent('cobalt_cityhall:rest', src, group, index, cooldown)
        end
    end
end

---@param src integer
---@param input GatherInput?
---@return GatherInput? input the item the player has too few of
local function lacking(src, input)
    if input and (exports.cobalt_inventory:GetItemCount(src, input.name) or 0) < input.amount then return input end
end

local Gather <const> = {}

function Gather.assign() end

---@return nil
function Gather.view() end

---@param shift Shift
---@return { group: integer, index: integer, ms: integer }[]
function Gather.resting(shift)
    local list <const> = {}

    for key, at in pairs(readyAt[shift.def.id] or {}) do
        local ms <const> = at - GetGameTimer()

        if ms > 0 then
            local group, index = key:match('^(%d+):(%d+)$')

            list[#list + 1] = { group = tonumber(group), index = tonumber(index), ms = ms }
        end
    end

    return list
end

---@param shift Shift
---@param target { group: integer, index: integer }
---@return integer? duration
---@return string? reason
function Gather.begin(shift, target)
    local spec, point = resolve(shift.def, target.group, target.index)

    if not spec or not point then return end

    local reach <const> = (point.radius or spec.radius or DEFAULT_RADIUS) + REACH_SLACK

    if not Registry.near(shift.src, point.coords, reach) then return nil, locale('gather.move_closer') end
    if resting(shift.def.id, nodeKey(target.group, target.index)) > 0 then return nil, locale('gather.resting') end

    local missing <const> = lacking(shift.src, spec.requires) or lacking(shift.src, spec.consumes)

    if missing then return nil, locale('gather.need', missing.amount, missing.label) end

    local duration <const> = Jobs.rollDuration(spec.action.duration)

    Registry.startAction(shift, nodeKey(target.group, target.index), duration)

    return duration
end

---@param shift Shift
---@param yield GatherYield
---@param amount integer
---@return boolean
local function grant(shift, yield, amount)
    if not yield.name then
        if (yield.value or 0) <= 0 then
            if yield.label then
                Registry.notify(shift.src, locale('gather.caught', yield.label:lower()))
            else
                Registry.notify(shift.src, locale('gather.caught_nothing'))
            end

            return true
        end

        Payout.pay(shift, yield.value * amount, yield.label or shift.def.label)

        return true
    end

    if not exports.cobalt_inventory:CanCarry(shift.src, yield.name, amount) then
        Registry.notify(shift.src, locale('gather.pockets_full'), 'error')
        return false
    end

    local reason <const> = ('cobalt_cityhall:%s'):format(shift.def.id)

    return exports.cobalt_inventory:AddItem(shift.src, yield.name, amount, nil, nil, reason)
end

---@param shift Shift
---@param target { group: integer, index: integer }
---@return boolean
function Gather.finish(shift, target)
    local spec, point = resolve(shift.def, target.group, target.index)

    if not spec or not point then return false end

    local key <const> = nodeKey(target.group, target.index)
    local reach <const> = (point.radius or spec.radius or DEFAULT_RADIUS) + REACH_SLACK

    if not Registry.endAction(shift, key) then return false end
    if not Registry.near(shift.src, point.coords, reach) then return false end

    if resting(shift.def.id, key) > 0 then
        Registry.notify(shift.src, locale('gather.taken'), 'error')
        return false
    end

    local input <const> = spec.consumes
    local reason <const> = ('cobalt_cityhall:%s'):format(shift.def.id)

    if input and not exports.cobalt_inventory:RemoveItem(shift.src, input.name, input.amount, nil, reason) then
        Registry.notify(shift.src, locale('gather.need', input.amount, input.label), 'error')
        return false
    end

    local yield <const> = roll(spec.yields)
    local range <const> = yield.amount or spec.amount

    if not grant(shift, yield, math.random(range[1], range[2])) then
        if input then exports.cobalt_inventory:AddItem(shift.src, input.name, input.amount, nil, nil, reason) end

        return false
    end

    shift.done += 1

    if spec.cooldown > 0 then rest(shift, target.group, target.index, spec.cooldown) end

    return true
end

---@param src integer
---@param sold { name: string, count: integer }[]
local function restore(src, sold)
    for _, entry in ipairs(sold) do
        exports.cobalt_inventory:AddItem(src, entry.name, entry.count, nil, nil, SELL_REASON)
    end
end

---@param sold { name: string, count: integer }[]
---@return string
local function describe(sold)
    local parts <const> = table.create(#sold, 0)

    table.sort(sold, function(x, y) return x.name < y.name end)

    for i, entry in ipairs(sold) do
        local label <const> = exports.cobalt_inventory:GetItemDef(entry.name)?.label or entry.name

        parts[i] = locale('gather.sold_item', entry.count, label)
    end

    if #parts == 1 then return parts[1] end

    local last <const> = table.remove(parts)

    return locale('gather.sold_list', table.concat(parts, ', '), last)
end

---@param def JobDefinition
---@return vector3 coords
---@return number reach
local function sellSpot(def)
    local point <const> = def.sellPoint

    if point then return point.coords, point.radius + REACH_SLACK end

    return def.site.coords.xyz, config.interactRange + REACH_SLACK
end

---@param shift Shift
---@return boolean
function Gather.sell(shift)
    local prices <const> = shift.def.prices

    if not prices then return false end

    local coords <const>, reach <const> = sellSpot(shift.def)

    if not Registry.near(shift.src, coords, reach) then return false end

    local sold <const> = {}
    local total = 0

    for item, price in pairs(prices) do
        local count <const> = exports.cobalt_inventory:GetItemCount(shift.src, item) or 0

        if count > 0 then
            if not exports.cobalt_inventory:RemoveItem(shift.src, item, count, nil, SELL_REASON) then
                restore(shift.src, sold)
                Registry.notify(shift.src, locale('gather.sale_failed'), 'error')
                return false
            end

            sold[#sold + 1] = { name = item, count = count }
            total += count * price
        end
    end

    if #sold == 0 then
        local goods <const> = shift.def.goods or locale('gather.goods')

        Registry.notify(shift.src, locale('gather.nothing_to_sell', goods:lower()), 'error')
        return false
    end

    if Payout.pay(shift, total, locale('gather.sold', describe(sold))) == 0 then
        restore(shift.src, sold)
        Registry.notify(shift.src, locale('gather.sale_failed'), 'error')
        return false
    end

    return true
end

return Gather
