local Work <const> = require 'client.work'

local core <const> = exports.cobalt_core

local RAY_FLAGS <const> = 1 | 16
local RAY_EXTRA <const> = 6.0
local RECHECK_MS <const> = 100
local GLIDE <const> = 18.0
local ROTATE_SPEED <const> = 90.0
local FINE_SCALE <const> = 0.2
local SCROLL_STEP <const> = 15.0
local FINE_SCROLL_STEP <const> = 2.0
local GHOST_ALPHA <const> = 170
local OVERHEAD <const> = 2.1
local VALID_COLOUR <const> = { 80, 200, 120 }
local INVALID_COLOUR <const> = { 220, 60, 60 }
---@type string
local NO_TEXTURE <const> = nil

local CONTROL <const> = {
    rotateLeft = 44,
    rotateRight = 38,
    scrollUp = 15,
    scrollDown = 14,
    fine = 21,
    click = 24,
    enter = 191,
    cancel = 177,
}

---@type integer[]
local BLOCKED <const> = { 14, 15, 16, 17, 24, 25, 37, 38, 44, 140, 141, 142, 177, 191, 199, 200, 257, 263 }

local TOOLTIP <const> = '[Scroll] [Q] [E] Turn  [Shift] Fine turn  [Click] Set up here  [Backspace] Cancel'

---@param coords vector3
---@param heading number
---@param x number
---@param y number
---@return vector3
local function offset(coords, heading, x, y)
    local rad <const> = math.rad(heading)
    local cos <const>, sin <const> = math.cos(rad), math.sin(rad)

    return vec3(coords.x + x * cos - y * sin, coords.y + x * sin + y * cos, coords.z)
end

---@param coords vector3
---@param heading number
---@param place StandPlace
---@return boolean
local function levelGround(coords, heading, place)
    local fx <const>, fy <const> = place.footprint.x, place.footprint.y

    for _, corner in ipairs({ { fx, fy }, { -fx, fy }, { fx, -fy }, { -fx, -fy } }) do
        local at <const> = offset(coords, heading, corner[1], corner[2])
        local found <const>, z <const> = GetGroundZFor_3dCoord(at.x, at.y, coords.z + 1.0, false)

        if not found or math.abs(z - coords.z) > place.maxStep then return false end
    end

    return true
end

---@param coords vector3
---@param ghost? integer
---@return boolean
local function crowded(coords, ghost)
    for _, object in ipairs(lib.getNearbyObjects(coords, 1.3)) do
        if object.object ~= ghost then return true end
    end

    if #lib.getNearbyVehicles(coords, 2.6, true) > 0 then return true end
    if #lib.getNearbyPeds(coords, 1.0) > 0 then return true end

    return #(GetEntityCoords(cache.ped) - coords) < 0.8
end

---@param coords vector3
---@return boolean
local function inWater(coords)
    local found <const>, height <const> = GetWaterHeight(coords.x, coords.y, coords.z + 2.0)

    return found and height > coords.z - 0.15
end

---@param coords vector3
---@return boolean
local function covered(coords)
    local hit <const> = lib.raycast.fromCoords(coords + vec3(0.0, 0.0, 0.4), coords + vec3(0.0, 0.0, OVERHEAD), RAY_FLAGS)

    return hit
end

---@param hit boolean
---@param entity integer
---@param coords vector3
---@param normal vector3
---@param heading number
---@param place StandPlace
---@param ghost? integer
---@return string? problem nil when the cart fits
local function problem(hit, entity, coords, normal, heading, place, ghost)
    if not hit then return 'Aim at the ground' end
    if #(GetEntityCoords(cache.ped) - coords) > place.range then return 'Too far away' end
    if entity ~= 0 and GetEntityType(entity) ~= 0 then return 'Something is in the way' end
    if normal.z < math.cos(math.rad(place.maxSlope)) then return 'Too steep here' end
    if inWater(coords) then return 'Not in the water' end
    if GetInteriorFromEntity(cache.ped) ~= 0 then return 'Set it up outdoors' end
    if GetInteriorAtCoords(coords.x, coords.y, coords.z) ~= 0 then return 'Set it up outdoors' end
    if covered(coords) then return 'No room overhead' end
    if not levelGround(coords, heading, place) then return 'The ground is too uneven' end
    if crowded(coords, ghost) then return 'Something is in the way' end
end

---@param heading number
---@return number
local function turn(heading)
    local fine <const> = IsDisabledControlPressed(0, CONTROL.fine)
    local speed <const> = ROTATE_SPEED * GetFrameTime() * (fine and FINE_SCALE or 1.0)
    local step <const> = fine and FINE_SCROLL_STEP or SCROLL_STEP

    if IsDisabledControlPressed(0, CONTROL.rotateLeft) then heading += speed end
    if IsDisabledControlPressed(0, CONTROL.rotateRight) then heading -= speed end
    if IsDisabledControlJustPressed(0, CONTROL.scrollUp) then heading += step end
    if IsDisabledControlJustPressed(0, CONTROL.scrollDown) then heading -= step end

    return heading % 360.0
end

---@param coords vector3
---@param valid boolean
local function drawRing(coords, valid)
    local colour <const> = valid and VALID_COLOUR or INVALID_COLOUR

    DrawMarker(
        25,
        coords.x, coords.y, coords.z + 0.03,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        2.2, 2.2, 1.0,
        colour[1], colour[2], colour[3], 160,
        false, false, 2, false, NO_TEXTURE, NO_TEXTURE, false
    )
end

---@param text string
---@param shown string?
---@return string
local function tooltip(text, shown)
    if text ~= shown then core:ShowTextUI(text, { position = 'bottom-center' }) end

    return text
end

local Placement <const> = {}

---@type integer?
local ghost

---@class PlacementAim
---@field active boolean
---@field heading number
---@field target? vector3 the last ground point a ray found
---@field reason? string why the cart can't go at `checked`, nil when it fits
---@field checked? vector3 the point `reason` was worked out for

---@param aim PlacementAim
---@param place StandPlace
local function trackAim(aim, place)
    local reach <const> = place.range + RAY_EXTRA
    local checkedAt = 0

    while aim.active do
        local hit <const>, entity <const>, coords <const>, normal <const> = lib.raycast.fromCamera(RAY_FLAGS, 4, reach)

        if hit then aim.target = coords end

        if GetGameTimer() - checkedAt > RECHECK_MS then
            aim.reason = problem(hit, entity, coords, normal, aim.heading, place, ghost)
            aim.checked = hit and coords or nil
            checkedAt = GetGameTimer()
        end
    end
end

---@param from vector3
---@param to vector3
---@return vector3
local function glide(from, to)
    return from + (to - from) * math.min(1.0, GetFrameTime() * GLIDE)
end

---@param stand StandConfig
---@return vector3? coords
---@return number? heading
function Placement.run(stand)
    local hash <const> = Work.loadModel(stand.model)

    if not hash then return end

    local start <const> = GetEntityCoords(cache.ped)

    ghost = CreateObject(hash, start.x, start.y, start.z - 5.0, false, false, false)

    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityAlpha(ghost, GHOST_ALPHA, false)
    SetEntityDrawOutlineShader(1)
    SetEntityDrawOutline(ghost, true)

    ---@type PlacementAim
    local aim <const> = { active = true, heading = GetEntityHeading(cache.ped), reason = 'Aim at the ground' }
    local shown, shownAt, result, resultHeading

    CreateThread(function() trackAim(aim, stand.place) end)

    while true do
        for _, control in ipairs(BLOCKED) do DisableControlAction(0, control, true) end

        aim.heading = turn(aim.heading)

        local valid <const> = aim.reason == nil
        local colour <const> = valid and VALID_COLOUR or INVALID_COLOUR

        if aim.target then
            shownAt = shownAt and glide(shownAt, aim.target) or aim.target

            SetEntityCoordsNoOffset(ghost, shownAt.x, shownAt.y, shownAt.z, false, false, false)
            SetEntityHeading(ghost, aim.heading)
            drawRing(shownAt, valid)
        end

        SetEntityDrawOutlineColor(colour[1], colour[2], colour[3], 255)
        shown = tooltip(aim.reason and ('%s  ·  %s'):format(aim.reason, TOOLTIP) or TOOLTIP, shown)

        if IsDisabledControlJustPressed(0, CONTROL.cancel) then break end
        if Work.isDown() or not LocalPlayer.state.LoggedIn then break end

        if IsDisabledControlJustPressed(0, CONTROL.click) or IsDisabledControlJustPressed(0, CONTROL.enter) then
            if valid and aim.checked then
                result, resultHeading = aim.checked, aim.heading
                break
            end

            PlaySoundFrontend(-1, 'ERROR', 'HUD_AMMO_SHOP_SOUNDSET', true)
        end

        Wait(0)
    end

    aim.active = false

    SetEntityDrawOutline(ghost, false)
    DeleteEntity(ghost)
    ghost = nil
    core:HideTextUI()

    return result, resultHeading
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not ghost then return end

    SetEntityDrawOutline(ghost, false)
    DeleteEntity(ghost)
    core:HideTextUI()
end)

return Placement
