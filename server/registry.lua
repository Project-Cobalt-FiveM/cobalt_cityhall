---@class Crew
---@field job string
---@field leader integer
---@field members integer[]

---@class PendingAction
---@field key string
---@field startedAt integer
---@field duration integer

---@class Shift
---@field src integer
---@field def JobDefinition
---@field citizenid string
---@field name string
---@field startedAt integer
---@field earned integer
---@field done integer
---@field crew? Crew
---@field task table
---@field vehicle? integer
---@field plate? string
---@field pending? PendingAction
---@field awaySince? integer
---@field bag? boolean carrying a trash bag
---@field binAt? vector3 the bin being emptied
---@field openAt? integer the vehicle whose back is being opened
---@field doorsOpen? integer the vehicle whose rear doors this player opened

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local Registry <const> = {
    ---@type table<integer, Shift>
    shifts = {},
}

---@param src integer
---@return string?
function Registry.citizenid(src)
    return Cobalt.Functions.GetPlayer(src)?.PlayerData.citizenid
end

---@param src integer
---@return Shift?
function Registry.get(src)
    return Registry.shifts[src]
end

---@param shift Shift
---@return Shift[]
function Registry.crewShifts(shift)
    if not shift.crew then return { shift } end

    local list <const> = {}

    for _, member in ipairs(shift.crew.members) do
        list[#list + 1] = Registry.shifts[member]
    end

    return list
end

---@param src integer
---@return vector3
function Registry.coords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

---@param src integer
---@param coords vector3
---@param range number
---@return boolean
function Registry.near(src, coords, range)
    return #(Registry.coords(src) - coords.xyz) <= range
end

---@param src integer
---@param coords vector3
---@param range number
---@return boolean
function Registry.nearFlat(src, coords, range)
    return #(Registry.coords(src).xy - coords.xy) <= range
end

---@param src integer
---@return boolean
function Registry.isDown(src)
    local revive <const> = Player(src).state.revive

    return revive ~= nil and revive.state ~= 'alive'
end

local ACTION_GRACE_MS <const> = 750

---@param shift Shift
---@param key string
---@param duration integer
function Registry.startAction(shift, key, duration)
    shift.pending = { key = key, startedAt = GetGameTimer(), duration = duration }
end

---@param shift Shift
---@param key string
---@return boolean finished the started action ran its full duration
function Registry.endAction(shift, key)
    local pending <const> = shift.pending

    shift.pending = nil

    if not pending or pending.key ~= key then return false end

    return GetGameTimer() - pending.startedAt >= pending.duration - ACTION_GRACE_MS
end

---@param src integer
---@param text string
---@param kind? 'success' | 'error' | 'inform'
function Registry.notify(src, text, kind)
    exports.cobalt_core:Notify(src, text, kind or 'inform')
end

---@param shift Shift
---@param text string
---@param kind? 'success' | 'error' | 'inform'
function Registry.notifyCrew(shift, text, kind)
    for _, member in ipairs(Registry.crewShifts(shift)) do
        Registry.notify(member.src, text, kind)
    end
end

return Registry
