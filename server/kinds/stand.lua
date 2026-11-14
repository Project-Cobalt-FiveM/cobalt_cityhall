local Registry <const> = require 'server.registry'
local State <const> = require 'server.hotdog.state'

local Stand <const> = {}

---@param shift Shift
---@return string
local function reason(shift)
    return ('cobalt_cityhall:%s'):format(shift.def.id)
end

---@param shift Shift
function Stand.assign(shift)
    local item <const> = shift.def.stand.item

    if State.stands[shift.src] then return end
    if (exports.cobalt_inventory:GetItemCount(shift.src, item) or 0) > 0 then return end

    if not exports.cobalt_inventory:AddItem(shift.src, item, 1, nil, nil, reason(shift)) then
        Registry.notify(shift.src, 'Make room in your pockets for the cart, then sign up again', 'error')
    end
end

---@return nil
function Stand.view() end

---@return boolean
function Stand.finish()
    return false
end

---@param shift Shift
function Stand.stop(shift)
    State.remove(shift.src)

    local item <const> = shift.def.stand.item
    local count <const> = exports.cobalt_inventory:GetItemCount(shift.src, item) or 0

    if count > 0 then exports.cobalt_inventory:RemoveItem(shift.src, item, count, nil, reason(shift)) end
end

return Stand
