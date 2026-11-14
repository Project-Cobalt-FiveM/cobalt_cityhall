local Station <const> = require 'client.hotdog.station'

local core <const> = exports.cobalt_core

local LOOK_X <const>, LOOK_Y <const> = 1, 2
local SQUEEZE <const> = 24
local NOZZLE_GAP <const> = 0.03
local AIM_SENSITIVITY <const> = 0.012
local AIM_ACROSS <const> = 0.07
local AIM_OVERHANG <const> = 0.06
local SAUCE_ACROSS <const> = 0.035
local SAUCE_LIFT <const> = 0.045
local PIECE_LIMIT <const> = 90
local LINE_STEP <const> = 0.006
local LINE_WIDTH <const> = 0.008
local LINE_HEIGHT <const> = 0.006
local ZIGZAG_AMPLITUDE <const> = 0.006
local ZIGZAG_WAVELENGTH <const> = 0.04
local CHUNK_MS <const> = 45
local CHUNK_SCATTER <const> = 0.007

---@class SauceState
---@field index integer into config.sauces
---@field bottle? integer
---@field bottleTop number height of the bottle above its origin, which hangs above the nozzle when flipped
---@field added table<SauceId, boolean>
---@field covered table<SauceId, table<integer, true>>
---@field pieces table<SauceId, integer[]> sauce segments and topping chunks laid on the hot dog
---@field last? vector3 where the sauce line reached on the current squeeze
---@field travel number meters the nozzle has moved on the current squeeze, which sets the zig-zag
---@field aim vector2 along and across the hot dog, in the cart's X and Y
---@field flip number 1 when the camera looks along the cart's +Y, -1 when it looks along -Y
---@field squeezing boolean
---@field sound? integer the squeeze sound while the bottle is pressed
---@field lastChunk integer
---@field halfLength number

---@alias SauceStep fun(action: string, ...: unknown): boolean, unknown?

local Sauce <const> = {}

---@param config StandConfig
---@return SauceState
function Sauce.new(config)
    local camera <const> = config.kitchen.camera

    return {
        index = 1,
        bottleTop = 0.0,
        added = {},
        covered = {},
        pieces = {},
        travel = 0.0,
        aim = vec2(0.0, 0.0),
        flip = camera.target.y < camera.offset.y and -1 or 1,
        squeezing = false,
        lastChunk = 0,
        halfLength = 0.1,
    }
end

---@param state SauceState
function Sauce.clear(state)
    Station.stopSound(state.sound)
    Station.remove(state.bottle)

    for _, list in pairs(state.pieces) do
        for _, piece in ipairs(list) do Station.remove(piece) end
    end

    state.bottle, state.squeezing, state.sound, state.last = nil, false, nil, nil
    state.added, state.covered, state.pieces = {}, {}, {}
end

---@param state SauceState
---@param config StandConfig
---@param index integer
function Sauce.pick(state, config, index)
    local sauce <const> = config.sauces[index]

    if not sauce or state.squeezing then return end

    state.index = index
    Station.stopSound(state.sound)
    state.sound = nil
    Station.remove(state.bottle)
    state.bottle = Station.prop(sauce.model, vec3(0.0, 0.0, 0.0), 0.0, config.kitchen.standIns.bottle)

    if state.bottle then
        local _, high <const> = GetModelDimensions(GetEntityModel(state.bottle))

        state.bottleTop = high.z
    end

    Station.cue('NAV_UP_DOWN', 'HUD_FRONTEND_CLOTHESSHOP_SOUNDSET')
end

---@param state SauceState
---@param config StandConfig
---@param hotdog integer
function Sauce.ready(state, config, hotdog)
    local low <const>, high <const> = GetModelDimensions(GetEntityModel(hotdog))

    state.halfLength = math.max(high.x - low.x, high.y - low.y) / 2
    state.aim = vec2(state.flip * state.halfLength, 0.0)

    Sauce.pick(state, config, state.index)
end

---@param cart integer
---@return vector3 right the cart's +X
---@return vector3 forward the cart's +Y
local function axes(cart)
    local heading <const> = math.rad(GetEntityHeading(cart))

    return vec3(math.cos(heading), math.sin(heading), 0.0), vec3(-math.sin(heading), math.cos(heading), 0.0)
end

---@param state SauceState
---@param cart integer
---@param board vector3
---@param across? number extra offset across the hot dog
---@return vector3
local function aimPoint(state, cart, board, across)
    local right <const>, forward <const> = axes(cart)

    return Station.at(cart, board) + right * state.aim.x + forward * (state.aim.y + (across or 0.0))
end

---@param state SauceState
---@param cart integer
---@param board vector3
local function aim(state, cart, board)
    local dx <const> = GetDisabledControlNormal(0, LOOK_X) * AIM_SENSITIVITY * state.flip
    local dy <const> = -GetDisabledControlNormal(0, LOOK_Y) * AIM_SENSITIVITY * state.flip
    local limit <const> = state.halfLength + AIM_OVERHANG

    state.aim = vec2(
        math.max(-limit, math.min(limit, state.aim.x + dx)),
        math.max(-AIM_ACROSS, math.min(AIM_ACROSS, state.aim.y + dy))
    )

    if not state.bottle then return end

    local point <const> = aimPoint(state, cart, board)

    SetEntityCoordsNoOffset(state.bottle, point.x, point.y, point.z + NOZZLE_GAP + state.bottleTop, false, false, false)
    Station.orient(state.bottle, GetEntityHeading(cart), 180.0)
end

---@param state SauceState
---@param config StandConfig
---@param sauce StandSauce
---@return number
local function coverage(state, config, sauce)
    local count = 0

    for _ in pairs(state.covered[sauce.id] or {}) do count += 1 end

    return count / config.squeeze.bins
end

---@param state SauceState
---@param config StandConfig
---@param sauce StandSauce
local function cover(state, config, sauce)
    local bins <const> = config.squeeze.bins
    local bin <const> = math.min(bins, math.floor((state.aim.x + state.halfLength) / (2 * state.halfLength) * bins) + 1)

    state.covered[sauce.id] = state.covered[sauce.id] or {}
    state.covered[sauce.id][bin] = true
end

---@param state SauceState
---@param sauce StandSauce
---@param entity integer?
local function keep(state, sauce, entity)
    if not entity then return end

    state.pieces[sauce.id] = state.pieces[sauce.id] or {}
    table.insert(state.pieces[sauce.id], entity)
end

---@param state SauceState
---@param sauce StandSauce
---@return boolean
local function full(state, sauce)
    return #(state.pieces[sauce.id] or {}) >= PIECE_LIMIT
end

---@param from vector3
---@param to vector3
---@param model string
---@return integer?
local function segment(from, to, model)
    local piece <const> = Station.prop(model, (from + to) / 2, 0.0)

    if not piece then return end

    local along <const> = to - from
    local length <const> = #along
    local dir <const> = along / length
    local side <const> = vec3(-dir.y, dir.x, 0.0) * LINE_WIDTH
    local middle <const> = (from + to) / 2
    local stretch <const> = dir * (length + LINE_WIDTH * 0.6)

    SetEntityMatrix(piece, side.x, side.y, side.z, stretch.x, stretch.y, stretch.z, 0.0, 0.0, LINE_HEIGHT, middle.x, middle.y, middle.z)

    return piece
end

---@param state SauceState
---@param config StandConfig
---@param sauce StandSauce
---@param cart integer
local function pipe(state, config, sauce, cart)
    local wave <const> = math.sin(state.travel / ZIGZAG_WAVELENGTH * 2 * math.pi) * ZIGZAG_AMPLITUDE
    local point <const> = aimPoint(state, cart, config.kitchen.board, wave) + vec3(0.0, 0.0, SAUCE_LIFT)

    if not state.last then
        state.last = point
        return
    end

    local step <const> = #(point - state.last)

    if step < LINE_STEP then return end

    state.travel += step
    keep(state, sauce, segment(state.last, point, sauce.piece))
    state.last = point
end

---@param state SauceState
---@param config StandConfig
---@param sauce StandSauce
---@param cart integer
---@param now integer
local function sprinkle(state, config, sauce, cart, now)
    if now - state.lastChunk < CHUNK_MS then return end

    state.lastChunk = now

    local scatter <const> = (math.random() * 2 - 1) * CHUNK_SCATTER
    local point <const> = aimPoint(state, cart, config.kitchen.board, scatter) + vec3(0.0, 0.0, SAUCE_LIFT)
    local chunk <const> = Station.prop(sauce.piece, point, math.random() * 360.0)

    if chunk then Station.orient(chunk, math.random() * 360.0, math.random() * 360.0) end

    keep(state, sauce, chunk)
end

---@param state SauceState
---@param config StandConfig
---@param sauce StandSauce
---@param cart integer
---@param now integer
local function drip(state, config, sauce, cart, now)
    if math.abs(state.aim.x) > state.halfLength or math.abs(state.aim.y) > SAUCE_ACROSS then
        state.last = nil
        return
    end

    cover(state, config, sauce)

    if full(state, sauce) then return end

    if sauce.kind == 'chunks' then return sprinkle(state, config, sauce, cart, now) end

    pipe(state, config, sauce, cart)
end

---@param state SauceState
---@param config StandConfig
---@param sauce StandSauce
---@param step SauceStep
local function release(state, config, sauce, step)
    local ok <const>, added <const> = step('sauceEnd', sauce.id, coverage(state, config, sauce))

    state.squeezing = false

    if ok and added then
        state.added[sauce.id] = true
        return Station.cue('CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET')
    end

    if ok then core:Notify(('Run the %s along the whole hot dog'):format(sauce.label:lower()), 'inform') end
end

---@param state SauceState
---@param config StandConfig
---@param cart integer
---@param now integer
---@param step SauceStep
---@param act fun(work: fun()) runs work off the frame loop, one piece at a time
function Sauce.update(state, config, cart, now, step, act)
    aim(state, cart, config.kitchen.board)

    local sauce <const> = config.sauces[state.index]

    if not state.bottle or state.added[sauce.id] then return end

    local held <const> = IsDisabledControlPressed(0, SQUEEZE)

    if held and not state.squeezing then
        state.squeezing, state.last, state.travel = true, nil, 0.0
        state.sound = Station.loopSound('SPRAY', 'CARWASH_SOUNDS')

        return act(function()
            if step('sauceStart', sauce.id) then return end

            state.squeezing = false
            Station.stopSound(state.sound)
            state.sound = nil
        end)
    end

    if held then return drip(state, config, sauce, cart, now) end

    if state.sound then
        Station.stopSound(state.sound)
        state.sound = nil
    end

    if state.squeezing then
        act(function() release(state, config, sauce, step) end)
    end
end

return Sauce
