---@class DmvProgress
---@field src integer
---@field theory boolean
---@field failedAt? integer os.time of the last failed driving test

---@type table<string, DmvProgress>
local records <const> = {}

local Progress <const> = {}

---@param citizenid string
---@return DmvProgress?
function Progress.get(citizenid)
    return records[citizenid]
end

---@param src integer
---@param citizenid string
function Progress.passTheory(src, citizenid)
    records[citizenid] = { src = src, theory = true }
end

---@param citizenid string
function Progress.failPractical(citizenid)
    local record <const> = records[citizenid]

    if record then record.failedAt = os.time() end
end

---@param citizenid string
function Progress.clear(citizenid)
    records[citizenid] = nil
end

---@param src integer
local function forget(src)
    for citizenid, record in pairs(records) do
        if record.src == src then records[citizenid] = nil end
    end
end

AddEventHandler('playerDropped', function()
    forget(source)
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', forget)

return Progress
