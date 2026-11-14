local Hotdog <const> = {}

---@param ms integer
---@param doneAt integer
---@param burntAt integer
---@param grace? integer milliseconds the edges of the done window stretch in the cook's favour
---@return 'under' | 'done' | 'over'
local function stage(ms, doneAt, burntAt, grace)
    local slack <const> = grace or 0

    if ms >= burntAt + slack then return 'over' end
    if ms >= doneAt - slack then return 'done' end

    return 'under'
end

---@type table<string, CookLevel>
local COOK <const> = { under = 'raw', done = 'cooked', over = 'burnt' }

---@type table<string, BunLevel>
local TOAST <const> = { under = 'warm', done = 'toasted', over = 'burnt' }

---@param stand StandConfig
---@param ms integer milliseconds the sausage spent on the grill
---@param grace? integer
---@return CookLevel
function Hotdog.cookLevel(stand, ms, grace)
    local sausage <const> = stand.kitchen.sausage

    return COOK[stage(ms, sausage.cookedAt, sausage.burntAt, grace)]
end

---@param stand StandConfig
---@param ms integer milliseconds the bun spent on the grill
---@param grace? integer
---@return BunLevel
function Hotdog.bunLevel(stand, ms, grace)
    if ms <= 0 then return 'plain' end

    local toast <const> = stand.kitchen.toast

    return TOAST[stage(ms, toast.toastedAt, toast.burntAt, grace)]
end

---@param stand StandConfig
---@param sides { [1]: integer, [2]: integer } milliseconds each side spent face down
---@return boolean
function Hotdog.evenlyBrowned(stand, sides)
    local total <const> = sides[1] + sides[2]

    return math.min(sides[1], sides[2]) >= total * stand.kitchen.sausage.evenShare
end

---@param ms integer
---@param doneAt integer
---@param burntAt integer
---@return number progress 0 to 1 at done, up to 2 when burnt
function Hotdog.meter(ms, doneAt, burntAt)
    if ms < doneAt then return ms / doneAt end

    return math.min(2.0, 1.0 + (ms - doneAt) / (burntAt - doneAt))
end

---@param stand StandConfig
---@param rep integer
---@return integer
function Hotdog.price(stand, rep)
    local pay <const> = stand.pay

    return math.floor(pay.base * (1 + rep / stand.rep.max * pay.repPrice) + 0.5)
end

---@param stand StandConfig
---@param rep integer
---@return integer
function Hotdog.tip(stand, rep)
    local pay <const> = stand.pay
    local roll <const> = math.random(pay.tip[1], pay.tip[2])

    return math.floor(roll * (1 + rep / stand.rep.max * pay.repTip) + 0.5)
end

---@param stand StandConfig
---@param pedestrians integer
---@param rep integer
---@return number
function Hotdog.customerChance(stand, pedestrians, rep)
    local customers <const> = stand.customers
    local crowd <const> = math.min(pedestrians, customers.crowdCap)
    local boost <const> = 1 + rep / stand.rep.max * customers.repBoost

    if crowd == 0 then return 0 end

    return math.max(customers.minChance, math.min(customers.maxChance, crowd * customers.perPed * boost))
end

---@param stand StandConfig
---@param id string
---@return StandSauce?
function Hotdog.sauce(stand, id)
    for _, sauce in ipairs(stand.sauces) do
        if sauce.id == id then return sauce end
    end
end

return Hotdog
