local config <const> = require 'config'
local Nui <const> = require 'client.nui'
local play <const> = require 'client.cues'

local practical <const> = config.dmv.practical
local route <const> = practical.route
local RING_HEIGHT <const> = 1.5
local RING_COLOUR <const> = { 80, 120, 215, 140 }
local ARROW_COLOUR <const> = { 124, 155, 228, 220 }
local ARROW_HEIGHT <const> = 3.5
local ARROW_SIZE <const> = 1.4
local MARKER_RING <const> = 1
local MARKER_ARROW <const> = 2
local MARKER_FLAG <const> = 4
---@type string
local NO_TEXTURE <const> = nil
local BLIP_CHECKPOINT <const> = 1
local BLIP_FINISH <const> = 38
local BLIP_COLOUR <const> = 3
local NEXT_BLIP_ALPHA <const> = 120
local NEXT_BLIP_SCALE <const> = 0.7
local HUD_INTERVAL_MS <const> = 200
local UNIT_FACTORS <const> = { mph = 2.236936, kmh = 3.6 }
local unitFactor <const> = UNIT_FACTORS[practical.unit] or UNIT_FACTORS.mph

---@type DriveTestView?
local state

---@type integer[]
local blips = {}

local function removeBlips()
    for _, handle in ipairs(blips) do
        if DoesBlipExist(handle) then RemoveBlip(handle) end
    end

    blips = {}
end

---@param index integer
---@param current boolean
---@return integer
local function addBlip(index, current)
    local coords <const> = route[index].coords
    local finish <const> = index == #route
    local handle <const> = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(handle, finish and BLIP_FINISH or BLIP_CHECKPOINT)
    SetBlipColour(handle, BLIP_COLOUR)

    if not finish then ShowNumberOnBlip(handle, index) end

    if current then
        SetBlipRoute(handle, true)
        SetBlipRouteColour(handle, BLIP_COLOUR)
    else
        SetBlipAlpha(handle, NEXT_BLIP_ALPHA)
        SetBlipScale(handle, NEXT_BLIP_SCALE)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(finish and 'Driving test finish' or 'Driving test checkpoint')
    EndTextCommandSetBlipName(handle)

    return handle
end

local function placeBlips()
    local view <const> = state --[[@as DriveTestView]]

    removeBlips()

    blips[1] = addBlip(view.checkpoint, true)

    if route[view.checkpoint + 1] then blips[2] = addBlip(view.checkpoint + 1, false) end
end

---@param kind integer
---@param coords vector3
---@param size number
---@param height number
---@param colour integer[]
---@param animated boolean
local function marker(kind, coords, size, height, colour, animated)
    DrawMarker(
        kind,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        size, size, height,
        colour[1], colour[2], colour[3], colour[4],
        animated, false, 2, animated, NO_TEXTURE, NO_TEXTURE, false
    )
end

local function drawMarkers()
    local ringSize <const> = practical.checkpointRadius * 2

    while state do
        local coords <const> = route[state.checkpoint].coords
        local finish <const> = state.checkpoint == #route
        local top <const> = coords + vec3(0.0, 0.0, ARROW_HEIGHT)

        marker(MARKER_RING, coords - vec3(0.0, 0.0, 1.0), ringSize, RING_HEIGHT, RING_COLOUR, false)
        marker(finish and MARKER_FLAG or MARKER_ARROW, top, ARROW_SIZE, ARROW_SIZE, ARROW_COLOUR, true)
        Wait(0)
    end
end

local function feedHud()
    while state do
        local coords <const> = route[state.checkpoint].coords
        local vehicle <const> = cache.vehicle

        SendNUIMessage({
            action = 'driveTick',
            speed = vehicle and math.floor(GetEntitySpeed(vehicle) * unitFactor) or 0,
            distance = math.floor(#(GetEntityCoords(cache.ped) - coords)),
        })
        Wait(HUD_INTERVAL_MS)
    end
end

---@param previous DriveTestView?
local function cue(previous)
    local view <const> = state --[[@as DriveTestView]]

    if not previous then
        play('start')
    elseif #view.strikes > #previous.strikes then
        play('strike')
    elseif view.checkpoint > previous.checkpoint then
        play('checkpoint')
    end
end

---@param view DriveTestView?
local function apply(view)
    local previous <const> = state

    state = view

    if not state then
        removeBlips()
        SendNUIMessage({ action = 'drive', drive = false })
        return
    end

    if previous?.checkpoint ~= state.checkpoint then placeBlips() end

    cue(previous)
    SendNUIMessage({ action = 'drive', drive = { view = state, limit = route[state.checkpoint].limit } })

    if previous then return end

    CreateThread(drawMarkers)
    CreateThread(feedHud)
end

RegisterNetEvent('cobalt_cityhall:driveTest', function(view)
    apply(view or nil)
end)

RegisterNetEvent('cobalt_cityhall:driveTestResult', function(result)
    apply(nil)
    play(result.passed and 'passed' or 'failed')
    Nui.open('dmv', result)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and state then removeBlips() end
end)
