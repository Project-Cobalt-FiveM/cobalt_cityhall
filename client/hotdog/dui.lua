local PAGE <const> = ('nui://%s/_nui/build/order.html'):format(cache.resource)
local SCREEN_WIDTH <const> = 0.085
local NEAR <const> = 4.0
local MIN_SCALE <const> = 0.45
local MAX_DISTANCE <const> = 30.0

---@class HotdogDui
---@field handle integer
---@field name string
---@field width integer
---@field height integer

local Dui <const> = {}

local created = 0

---@param value string
---@return string
local function encode(value)
    return (value:gsub('[^%w%-_%.~]', function(char) return ('%%%02X'):format(char:byte()) end))
end

---@param mode 'order' | 'meter'
---@param width integer
---@param height integer
---@param initial table sent in the page address so it shows before the first message
---@return HotdogDui
function Dui.create(mode, width, height, initial)
    created += 1

    local name <const> = ('cobalt_hotdog_%d'):format(created)
    local url <const> = ('%s?mode=%s#%s'):format(PAGE, mode, encode(json.encode(initial)))
    local handle <const> = CreateDui(url, width, height)
    local txd <const> = CreateRuntimeTxd(name)

    CreateRuntimeTextureFromDuiHandle(txd, name, GetDuiHandle(handle))

    return { handle = handle, name = name, width = width, height = height }
end

---@param dui HotdogDui
---@param payload table
function Dui.send(dui, payload)
    SendDuiMessage(dui.handle, json.encode(payload))
end

---@param dui HotdogDui?
function Dui.destroy(dui)
    if dui then DestroyDui(dui.handle) end
end

---@param dui HotdogDui
---@param coords vector3
---@param size? number screen width as a fraction at close range
function Dui.draw(dui, coords, size)
    local camera <const> = GetFinalRenderedCamCoord()
    local distance <const> = #(camera - coords)

    if distance > MAX_DISTANCE then return end

    local screenX <const>, screenY <const> = GetActiveScreenResolution()
    local scale <const> = math.max(MIN_SCALE, math.min(1.0, NEAR / math.max(distance, 0.01)))
    local width <const> = (size or SCREEN_WIDTH) * scale
    local height <const> = width * dui.height / dui.width * screenX / screenY

    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawSprite(dui.name, dui.name, 0.0, -height / 2, width, height, 0.0, 255, 255, 255, 255)
    ClearDrawOrigin()
end

---@param dui HotdogDui
---@param x number screen fraction of the sprite's centre
---@param y number
---@param width number screen fraction
function Dui.drawScreen(dui, x, y, width)
    local screenX <const>, screenY <const> = GetActiveScreenResolution()
    local height <const> = width * dui.height / dui.width * screenX / screenY

    DrawSprite(dui.name, dui.name, x, y, width, height, 0.0, 255, 255, 255, 255)
end

return Dui
