local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@alias PayAccount 'cash' | 'bank'

---@type PayAccount[]
local ACCOUNTS <const> = { 'cash', 'bank' }

local Payment <const> = {}

---@param src integer
---@param amount integer
---@param reason string
---@return PayAccount? account the account that paid, nil when neither covers the amount
function Payment.charge(src, amount, reason)
    local player <const> = Cobalt.Functions.GetPlayer(src)

    if not player then return end
    if amount <= 0 then return 'cash' end

    for _, account in ipairs(ACCOUNTS) do
        if player.Functions.RemoveMoney(account, amount, reason) then return account end
    end
end

---@param src integer
---@param account PayAccount
---@param amount integer
---@param reason string
function Payment.refund(src, account, amount, reason)
    local player <const> = amount > 0 and Cobalt.Functions.GetPlayer(src)

    if player then player.Functions.AddMoney(account, amount, reason) end
end

return Payment
