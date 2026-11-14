local config <const> = require 'config'
local Registry <const> = require 'server.registry'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local Payout <const> = {}

---@param shift Shift
---@param amount number
---@param reason string
---@param account? PayAccount defaults to the configured pay account
---@return integer paid
function Payout.pay(shift, amount, reason, account)
    local total <const> = math.floor(amount + 0.5)

    if total <= 0 then return 0 end

    local player <const> = Cobalt.Functions.GetPlayer(shift.src)
    local note <const> = ('%s: %s'):format(shift.def.label, reason)
    local into <const> = account or config.payAccount

    if not player or not player.Functions.AddMoney(into, total, note) then return 0 end

    shift.earned += total

    exports.cobalt_management:AddJobPayout(shift.def.id, total)
    Registry.notify(shift.src, locale(('payout.%s'):format(into), total, reason), 'success')

    return total
end

---Splits one payment evenly between the crew members who shared the work, with the crew bonus when two or more did
---@param shifts Shift[]
---@param amount number
---@param reason string
function Payout.split(shifts, amount, reason)
    if #shifts == 0 then return end

    local bonus <const> = #shifts > 1 and 1 + config.crew.bonus or 1
    local share <const> = amount * bonus / #shifts

    for _, member in ipairs(shifts) do Payout.pay(member, share, reason) end
end

return Payout
