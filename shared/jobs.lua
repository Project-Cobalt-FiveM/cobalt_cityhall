local config <const> = require 'config'

local Jobs <const> = {
    ---@type string[]
    order = config.jobs,
    ---@type table<string, JobDefinition>
    byId = {},
}

for _, id in ipairs(config.jobs) do
    local def <const> = require(('data.%s'):format(id)) --[[@as JobDefinition]]

    def.id = id
    Jobs.byId[id] = def
end

---@param amount number
---@return string
local function money(amount)
    if amount == math.floor(amount) then return ('$%d'):format(amount) end

    return ('$%.2f'):format(amount)
end

---@param values number[]
---@return string
local function moneyRange(values)
    local low, high = math.huge, 0

    for _, value in ipairs(values) do
        if value > 0 then
            low = math.min(low, value)
            high = math.max(high, value)
        end
    end

    if low == high then return money(low) end

    return ('%s–%s'):format(money(low), money(high))
end

---@param def JobDefinition
---@return number[]
local function yieldValues(def)
    local values <const> = {}

    if def.prices then
        for _, price in pairs(def.prices) do values[#values + 1] = price end

        return values
    end

    for _, group in ipairs(def.groups) do
        for _, yield in ipairs(group.yields) do values[#values + 1] = yield.value or 0 end
    end

    return values
end

---@param def JobDefinition
---@return string
function Jobs.payLine(def)
    if def.stand then
        return ('%s per hot dog + tips'):format(money(def.stand.pay.base))
    end

    if def.taxi then
        return ('%s per fare + %s per 100 m'):format(money(def.taxi.base), money(def.taxi.perMeter * 100))
    end

    if def.collect then
        local pay <const> = def.collect.pay

        local area <const> = pay.perBin * def.collect.bins

        return ('%s per cleared area, %s per route'):format(money(area), money(pay.routeBonus))
    end

    if def.route then
        local pay <const> = def.route.pay
        local line = ('%s per %s'):format(money(pay.perAction), def.route.unit)

        if pay.perMeter then
            line = ('%s + %s per 100 m'):format(line, money(pay.perMeter * 100))
        end

        if pay.routeBonus then
            line = ('%s, %s %s'):format(line, money(pay.routeBonus), pay.bonusText)
        end

        return line
    end

    if def.goods then
        return ('%s sells for %s'):format(def.goods, moneyRange(yieldValues(def)))
    end

    return ('%s per catch'):format(moneyRange(yieldValues(def)))
end

local EXAMPLE_METERS <const> = 3000

---@alias PayRow { label: string, value: string }

---@param def JobDefinition
---@return PayRow[]
function Jobs.payRows(def)
    if def.stand then
        local pay <const> = def.stand.pay

        return {
            { label = 'Each hot dog, new on the street', value = money(pay.base) },
            { label = 'Each hot dog, local favourite', value = money(math.floor(pay.base * (1 + pay.repPrice) + 0.5)) },
            { label = 'Tips on a perfect order', value = ('%s–%s'):format(money(pay.tip[1]), money(pay.tip[2] * (1 + pay.repTip))) },
        }
    end

    if def.taxi then
        return {
            { label = 'Each fare', value = money(def.taxi.base) },
            { label = 'Distance', value = ('%s per 100 m'):format(money(def.taxi.perMeter * 100)) },
            { label = 'A 3 km fare pays', value = money(def.taxi.base + def.taxi.perMeter * EXAMPLE_METERS) },
        }
    end

    if def.collect then
        local collect <const> = def.collect --[[@as CollectConfig]]

        local area <const> = money(collect.pay.perBin * collect.bins)

        return {
            { label = ('Area of %d bins cleared'):format(collect.bins), value = area },
            { label = ('Route of %d areas'):format(collect.length), value = money(collect.pay.routeBonus) },
        }
    end

    if def.route then
        local route <const> = def.route --[[@as RouteConfig]]
        local pay <const> = route.pay
        local rows <const> = { { label = ('Each %s'):format(route.unit), value = money(pay.perAction) } }

        if pay.perMeter then
            rows[#rows + 1] = { label = 'Distance', value = ('%s per 100 m'):format(money(pay.perMeter * 100)) }
            rows[#rows + 1] = {
                label = route.cargo and 'A 3 km delivery pays' or ('A 3 km %s pays'):format(route.unit),
                value = money(pay.perAction * route.actions + pay.perMeter * EXAMPLE_METERS),
            }
        end

        if pay.routeBonus then
            rows[#rows + 1] = { label = pay.bonusLabel, value = money(pay.routeBonus) }
        end

        return rows
    end

    if def.goods then
        return { { label = def.goods, value = ('%s each'):format(moneyRange(yieldValues(def))) } }
    end

    return { { label = 'Each catch', value = moneyRange(yieldValues(def)) } }
end

---@param duration integer | { [1]: integer, [2]: integer }
---@return integer
function Jobs.rollDuration(duration)
    if type(duration) == 'number' then return duration end

    return math.random(duration[1], duration[2])
end

return Jobs
