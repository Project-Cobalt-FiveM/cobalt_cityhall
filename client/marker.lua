local Work <const> = require 'client.work'

local RANGE <const> = 80.0
local RING_SIZE <const> = 1.6
local RING_HEIGHT <const> = 0.6
local RING_COLOUR <const> = { 80, 120, 215, 140 }
local ARROW_COLOUR <const> = { 124, 155, 228, 220 }
local ARROW_HEIGHT <const> = 1.8
local ARROW_SIZE <const> = 0.6
local MARKER_RING <const> = 1
local MARKER_ARROW <const> = 2
---@type string
local NO_TEXTURE <const> = nil

---@param ground vector3
---@param top vector3
local function draw(ground, top)
    DrawMarker(
        MARKER_RING,
        ground.x, ground.y, ground.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        RING_SIZE, RING_SIZE, RING_HEIGHT,
        RING_COLOUR[1], RING_COLOUR[2], RING_COLOUR[3], RING_COLOUR[4],
        false, false, 2, false, NO_TEXTURE, NO_TEXTURE, false
    )
    DrawMarker(
        MARKER_ARROW,
        top.x, top.y, top.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        ARROW_SIZE, ARROW_SIZE, ARROW_SIZE,
        ARROW_COLOUR[1], ARROW_COLOUR[2], ARROW_COLOUR[3], ARROW_COLOUR[4],
        true, false, 2, true, NO_TEXTURE, NO_TEXTURE, false
    )
end

---@param coords vector3
---@return fun() stop
return function(coords)
    local running = true

    CreateThread(function()
        local ground <const> = vec3(coords.x, coords.y, Work.groundZ(coords))
        local top <const> = ground + vec3(0.0, 0.0, ARROW_HEIGHT)

        while running do
            if #(GetEntityCoords(cache.ped) - ground) < RANGE then
                draw(ground, top)
                Wait(0)
            else
                Wait(500)
            end
        end
    end)

    return function() running = false end
end
