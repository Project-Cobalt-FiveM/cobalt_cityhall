local config <const> = require 'config'
local Registry <const> = require 'server.registry'
local Payment <const> = require 'server.payment'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local cards <const> = config.cards
local DESK_SLACK <const> = 3.0
local ID <const> = 'id'

---@class CardOffer
---@field key string `id`, or the licence key
---@field label string
---@field price integer
---@field held boolean the player holds the licence, always true for the ID card
---@field carried integer how many of the card the player carries
---@field grantedAt? integer unix time of the grant
---@field grantedBy? string who granted the licence

local Cards <const> = {}

---@param key string
---@return { label: string, item: string, price: integer }?
local function cardOf(key)
    if key == ID then return cards.id end

    local card <const> = cards.licences[key]
    local info <const> = card and exports.cobalt_core:GetLicenseTypes()[key]

    if not info then return end

    return { label = locale('card.licence', info.label), item = card.item, price = card.price }
end

---@param src integer
---@param key string
---@param records table<string, LicenseRecord>
---@return CardOffer?
local function offer(src, key, records)
    local card <const> = cardOf(key)

    if not card then return end

    local record <const> = records[key]

    return {
        key = key,
        label = card.label,
        price = card.price,
        held = key == ID or record?.held == true,
        carried = exports.cobalt_inventory:GetItemCount(src, card.item) or 0,
        grantedAt = record?.grantedAt,
        grantedBy = record?.grantedBy,
    }
end

---@param src integer
---@return CardOffer[]
function Cards.offers(src)
    local records <const> = exports.cobalt_core:GetLicenseRecords(src) or {}
    local licences <const> = {}

    for key in pairs(cards.licences) do
        licences[#licences + 1] = offer(src, key, records)
    end

    table.sort(licences, function(a, b) return a.label < b.label end)
    table.insert(licences, 1, offer(src, ID, records))

    return licences
end

---@class CardsView
---@field offers CardOffer[]
---@field cash integer
---@field bank integer

---@param src integer
---@return CardsView
function Cards.view(src)
    local player <const> = Cobalt.Functions.GetPlayer(src)

    return {
        offers = Cards.offers(src),
        cash = player and player.Functions.GetMoney('cash') or 0,
        bank = player and player.Functions.GetMoney('bank') or 0,
    }
end

lib.callback.register('cobalt_cityhall:cards', function(src)
    return Cards.view(src)
end)

lib.callback.register('cobalt_cityhall:buyCard', function(src, key)
    if type(key) ~= 'string' then return false, locale('card.pick') end

    if not Registry.near(src, config.center.coords, config.interactRange + DESK_SLACK) then
        return false, locale('card.at_desk')
    end

    local card <const> = cardOf(key)

    if not card then return false, locale('card.unknown') end

    if key ~= ID and not exports.cobalt_core:HasLicense(src, key) then
        return false, locale('card.not_held', card.label:lower())
    end

    local metadata <const> = exports.cobalt_core:CardMetadata(src, key ~= ID and key or nil)

    if not metadata then return false, locale('card.not_loaded') end
    if not exports.cobalt_inventory:CanCarry(src, card.item, 1) then return false, locale('card.pockets_full') end

    local what <const> = key == ID and locale('card.id_card') or locale('card.licence_card', card.label)
    local account <const> = Payment.charge(src, card.price, card.label)

    if not account then
        return false, locale('card.cannot_afford', card.price, what)
    end

    if not exports.cobalt_inventory:AddItem(src, card.item, 1, metadata, nil, 'cityhall') then
        Payment.refund(src, account, card.price, locale('card.refund', card.label))

        return false, locale('card.not_given')
    end

    exports.cobalt_core:LogPlayer(src, 'cityhall.card', ('Bought %s for $%d'):format(what, card.price), {
        key = key,
        account = account,
        price = card.price,
    })

    Registry.notify(src, locale('card.bought', what), 'success')

    return true, nil, Cards.view(src)
end)

return Cards
