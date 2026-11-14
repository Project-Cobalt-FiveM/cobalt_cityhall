local Work <const> = require 'client.work'
local Props <const> = require 'client.props'
local Customers <const> = require 'client.hotdog.customers'
local Dui <const> = require 'client.hotdog.dui'
local Dressing <const> = require 'client.hotdog.dressing'
local Station <const> = require 'client.hotdog.station'
local Sauce <const> = require 'client.hotdog.sauce'
local Hotdog <const> = require 'shared.hotdog'

local core <const> = exports.cobalt_core
local sound <const> = exports.cobalt_sound

local CONTROL <const> = {
    primary = 38,
    turn = 45,
    plain = 47,
    serve = 23,
    bin = 73,
    leave = 177,
}

---@type integer[]
local SAUCE_KEYS <const> = { 157, 158, 160, 164, 165 }

---@type integer[]
local BLOCKED <const> = {
    1, 2, 22, 23, 24, 25, 37, 38, 44, 45, 47, 73, 140, 141, 142,
    157, 158, 160, 164, 165, 177, 199, 200, 244, 257, 263, 288, 289, 322,
}

local WALK_TIMEOUT_MS <const> = 3000
local METER_SEND_MS <const> = 100
local METER_WIDTH <const>, METER_HEIGHT <const> = 420, 330
local METER_SCREEN <const> = { x = 0.13, y = 0.46, width = 0.2 }
local ROLL_MS <const> = 350
local ROLL_HOP <const> = 0.012
local ALONG_Y <const> = 90.0
local STACK_LIFT <const> = 0.02
local RING_BUBBLES <const> = 10
local BUBBLES <const> = 16
local WELL_HALF <const> = vec2(0.065, 0.14)
local BUBBLE_SIZE <const> = 0.007
local BUBBLE_PERIOD_MS <const> = 650
local BUBBLE_SPIN_MS <const> = 1800
local BUBBLE_RING <const> = vec2(0.024, 0.088)
local LIQUID_LIFT <const> = 0.002

---@alias KitchenStage 'sausage' | 'bun' | 'assemble' | 'sauce'

---@alias SausageLook CookLevel | 'halfDown' | 'halfUp'

---@class KitchenSession
---@field config StandConfig
---@field cart integer
---@field cam integer
---@field meter HotdogDui
---@field stage KitchenStage
---@field busy boolean an action is playing out
---@field tongs? integer
---@field liquid? integer the moving oil surface over the fryer
---@field bubbles integer[] bubbles that ring the sausage, then spread over the well, while it fries
---@field spots vector2[] where each loose bubble rises, across and along the well
---@field bubbling boolean
---@field cookStart? integer when the sausage went into the oil, by the click that put it there
---@field cookMs integer
---@field sides { [1]: integer, [2]: integer } milliseconds each side spent face down
---@field side 1 | 2 the side face down in the oil
---@field sideAt integer
---@field roll number degrees the sausage is turned around its length
---@field cookLook? SausageLook
---@field bunStart? integer
---@field bunMs integer
---@field bunLook? BunLevel
---@field sausage? integer
---@field bun? integer
---@field hotdog? integer
---@field steam? integer
---@field smoke? integer
---@field sizzle? integer | false the looping grill sound, false while the server starts it
---@field sauce SauceState
---@field sentAt integer
---@field tooltip? string

local Kitchen <const> = {}

local running = false

---@type KitchenSession?
local current

---@param action string
---@param ... unknown
---@return boolean ok
---@return unknown? detail
local function step(action, ...)
    return lib.callback.await('cobalt_cityhall:hotdog:step', false, action, ...)
end

---@param s KitchenSession
---@param offset vector3
---@return vector3
local function at(s, offset)
    return Station.at(s.cart, offset)
end

---@param s KitchenSession
---@return number
local function yaw(s)
    return GetEntityHeading(s.cart)
end


---@param s KitchenSession
---@param work fun()
local function act(s, work)
    if s.busy then return end

    s.busy = true

    CreateThread(function()
        work()
        s.busy = false
    end)
end

---@param blocked boolean
local function blockActions(blocked)
    LocalPlayer.state:set('invBusy', blocked, false)

    if GetResourceState('npwd') ~= 'started' then return end

    if blocked then exports.npwd:setPhoneVisible(false) end

    exports.npwd:setPhoneDisabled(blocked)
end

---@param s KitchenSession
---@param entity integer
---@param base vector3
---@param pose? { yaw?: number, pitch?: number, radius?: number }
local function carry(s, entity, base, pose)
    local motion <const> = s.config.kitchen.motion

    Station.move(entity, {
        base = base,
        yaw = pose?.yaw or yaw(s) + ALONG_Y,
        pitch = pose?.pitch,
        radius = pose?.radius,
        ms = motion.carryMs,
        lift = motion.lift,
        tongs = s.tongs,
        cartYaw = yaw(s),
    })

    Station.grip(s.tongs, at(s, s.config.kitchen.supply), yaw(s))
end

---@param s KitchenSession
---@param lid LidName
---@param open boolean
local function swing(s, lid, open)
    Station.cue('NAV_UP_DOWN', 'HUD_FRONTEND_CLOTHESSHOP_SOUNDSET')
    Dressing.swing(s.cart, lid, open, s.config.kitchen.motion.lidMs)
end

---@param s KitchenSession
local function stopSizzle(s)
    if s.sizzle then sound:Stop(s.sizzle) end

    s.sizzle = nil
end

---@param s KitchenSession
local function syncSizzle(s)
    if not s.cookStart and not s.bunStart then return stopSizzle(s) end
    if s.sizzle ~= nil then return end

    local spec <const> = s.config.kitchen.sizzle

    s.sizzle = false

    local id <const> = sound:PlayOnEntity(NetworkGetNetworkIdFromEntity(s.cart), spec.sound, spec.volume, spec.distance)

    if s.sizzle ~= false then
        if id then sound:Stop(id) end
        return
    end

    s.sizzle = id or nil

    if id then sound:SetLoop(id, true) end
end

---@param s KitchenSession
---@param well vector3
---@param fx StandFx
---@return integer
local function wellFx(s, well, fx)
    return Station.startFx(fx, at(s, well + vec3(0.0, 0.0, fx.lift)))
end

---@param s KitchenSession
local function stopHeat(s)
    Station.stopFx(s.steam)
    Station.stopFx(s.smoke)

    s.steam, s.smoke = nil, nil

    syncSizzle(s)
end

---@param s KitchenSession
---@param visible boolean
local function showBubbles(s, visible)
    if s.bubbling == visible then return end

    s.bubbling = visible

    for _, bubble in ipairs(s.bubbles) do SetEntityVisible(bubble, visible, false) end
end

---@param s KitchenSession
---@param now integer
local function fizz(s, now)
    if not s.cookStart or not s.sausage then return showBubbles(s, false) end

    showBubbles(s, true)

    local heat <const> = 0.3 + 0.7 * math.min(1.0, (now - s.cookStart) / s.config.kitchen.sausage.cookedAt)
    local active <const> = math.ceil(#s.bubbles * heat)
    local centre <const> = at(s, s.config.kitchen.fryer)
    local rad <const> = math.rad(yaw(s))
    local right <const> = vec3(math.cos(rad), math.sin(rad), 0.0)
    local forward <const> = vec3(-math.sin(rad), math.cos(rad), 0.0)
    local spin <const> = now / BUBBLE_SPIN_MS

    for index, bubble in ipairs(s.bubbles) do
        local angle <const> = index / RING_BUBBLES * 2 * math.pi + spin
        local phase <const> = ((now + index * 137) % BUBBLE_PERIOD_MS) / BUBBLE_PERIOD_MS
        local size <const> = index <= active and BUBBLE_SIZE * heat * math.sin(phase * math.pi) or 0.0
        local loose <const> = s.spots[index - RING_BUBBLES]
        local offset <const> = loose or vec2(math.cos(angle) * BUBBLE_RING.x, math.sin(angle) * BUBBLE_RING.y)
        local spot <const> = centre + right * offset.x + forward * offset.y
        local across <const>, along <const> = right * size, forward * size

        SetEntityMatrix(bubble, along.x, along.y, along.z, across.x, across.y, across.z, 0.0, 0.0, size * 0.6, spot.x, spot.y, spot.z)
    end
end

---@param s KitchenSession
---@param model string
---@return integer?
local function fresh(s, model)
    return Station.prop(model, at(s, s.config.kitchen.supply), yaw(s) + ALONG_Y, s.config.kitchen.standIns.food)
end

---@param s KitchenSession
---@return number
local function sausageRadius(s)
    return Station.radius(s.config.kitchen.models.rawSausage)
end

---@param s KitchenSession
---@param now integer
---@return { [1]: integer, [2]: integer }
local function liveSides(s, now)
    local sides <const> = { s.sides[1], s.sides[2] }

    if s.cookStart then sides[s.side] += now - s.sideAt end

    return sides
end

---@param s KitchenSession
---@param now integer
---@return SausageLook
local function sausageLook(s, now)
    local level <const> = Hotdog.cookLevel(s.config, now - s.cookStart)

    if level ~= 'cooked' then return level end

    local sides <const> = liveSides(s, now)

    if Hotdog.evenlyBrowned(s.config, sides) then return 'cooked' end

    return sides[1] >= sides[2] and 'halfDown' or 'halfUp'
end

---@type table<CookLevel, string>
local COOK_LINES <const> = {
    raw = 'Still pink in the middle. Nobody pays for that.',
    cooked = 'Browned all over with grill lines. Perfect.',
    burnt = 'Charred black. That one is going back.',
}

local ONE_SIDE_LINE <const> = 'Browned on one side and pale on the other. Roll it while it fries.'

---@type table<BunLevel, string>
local BUN_LINES <const> = {
    plain = 'Soft and plain.',
    warm = 'Barely warm. Not what anyone calls toasted.',
    toasted = 'Golden and crisp.',
    burnt = 'The bun caught. Bin it and start over.',
}

---@param s KitchenSession
local function sausageIn(s)
    local kitchen <const> = s.config.kitchen

    swing(s, 'fryer', true)

    s.sausage = fresh(s, kitchen.models.rawSausage)

    if not s.sausage then return end

    local radius <const> = sausageRadius(s)

    carry(s, s.sausage, at(s, kitchen.fryer) - vec3(0.0, 0.0, radius), { radius = radius })

    local sent <const> = GetGameTimer()

    if not step('grillOn') then
        Station.remove(s.sausage)
        s.sausage = nil
        return swing(s, 'fryer', false)
    end

    s.cookStart, s.cookMs, s.cookLook = sent, 0, 'raw'
    s.sides, s.side, s.sideAt, s.roll = { 0, 0 }, 1, sent, 0.0
    s.steam = wellFx(s, kitchen.fryer, kitchen.steam)

    Station.cue('Prop_Drop_Water', 'DLC_Dmod_Prop_Editor_Sounds')
    syncSizzle(s)
end

---@param s KitchenSession
local function roll(s)
    local sausage <const> = s.sausage

    if not sausage then return end

    local kitchen <const> = s.config.kitchen
    local radius <const> = sausageRadius(s)
    local base <const> = at(s, kitchen.fryer) - vec3(0.0, 0.0, radius)
    local from <const> = s.roll
    local began <const> = GetGameTimer()

    s.roll = (s.roll + 180.0) % 360.0

    while DoesEntityExist(sausage) do
        local t <const> = math.min(1.0, (GetGameTimer() - began) / ROLL_MS)
        local hop <const> = vec3(0.0, 0.0, ROLL_HOP * math.sin(math.pi * t))

        Station.place(sausage, { base = base + hop, yaw = yaw(s) + ALONG_Y, pitch = from + 180.0 * t, radius = radius })
        Station.grip(s.tongs, base + hop + vec3(0.0, 0.0, radius), yaw(s))

        if t >= 1.0 then break end

        Wait(0)
    end

    Station.grip(s.tongs, at(s, kitchen.supply), yaw(s))
end

---@param s KitchenSession
local function turn(s)
    if not s.sausage then return end

    local now <const> = GetGameTimer()

    if not step('turn') then return end

    s.sides[s.side] += now - s.sideAt
    s.side, s.sideAt = s.side == 1 and 2 or 1, now

    Station.cue('Prop_Drop_Water', 'DLC_Dmod_Prop_Editor_Sounds')
    roll(s)
end

---@param s KitchenSession
local function sausageOut(s)
    local clicked <const> = GetGameTimer()
    local start <const> = s.cookStart --[[@as integer]]

    s.cookMs, s.cookStart = clicked - start, nil
    s.sides[s.side] += clicked - s.sideAt

    local ok <const>, level <const>, even <const> = step('grillOff')

    if not ok then
        s.sides[s.side] -= clicked - s.sideAt
        s.cookStart = start
        return
    end

    stopHeat(s)

    if s.sausage then
        carry(s, s.sausage, at(s, s.config.kitchen.ready.sausage), { pitch = s.roll, radius = sausageRadius(s) })
    end

    swing(s, 'fryer', false)

    s.stage = 'bun'

    local perfect <const> = level == 'cooked' and even

    Station.cue(perfect and 'CHECKPOINT_NORMAL' or 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET')

    if level == 'cooked' and not even then return core:Notify(ONE_SIDE_LINE, 'error') end

    core:Notify(COOK_LINES[level --[[@as CookLevel]]] or COOK_LINES.raw, perfect and 'success' or 'error')
end

---@param s KitchenSession
---@param toast boolean
local function bunIn(s, toast)
    local kitchen <const> = s.config.kitchen

    if toast then swing(s, 'griddle', true) end

    s.bun = fresh(s, kitchen.models.bun)

    if not s.bun then return end

    carry(s, s.bun, at(s, toast and kitchen.griddle or kitchen.ready.bun))

    local sent <const> = GetGameTimer()

    if not step(toast and 'bunOn' or 'bunPlain') then
        Station.remove(s.bun)
        s.bun = nil

        if toast then swing(s, 'griddle', false) end

        return
    end

    Station.cue('Prop_Drop_Land', 'DLC_Dmod_Prop_Editor_Sounds')

    if not toast then
        s.stage = 'assemble'
        return
    end

    s.bunStart, s.bunMs, s.bunLook = sent, 0, 'warm'
    s.steam = wellFx(s, kitchen.griddle, kitchen.steam)

    syncSizzle(s)
end

---@param s KitchenSession
local function bunOut(s)
    local clicked <const> = GetGameTimer()
    local start <const> = s.bunStart --[[@as integer]]

    s.bunMs, s.bunStart = clicked - start, nil

    local ok <const>, level <const> = step('bunOff')

    if not ok then
        s.bunStart = start
        return
    end

    stopHeat(s)

    if s.bun then carry(s, s.bun, at(s, s.config.kitchen.ready.bun)) end

    swing(s, 'griddle', false)

    s.stage = 'assemble'

    Station.cue(level == 'toasted' and 'CHECKPOINT_NORMAL' or 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET')
    core:Notify(BUN_LINES[level --[[@as BunLevel]]] or BUN_LINES.warm, level == 'toasted' and 'success' or 'error')
end

---@param s KitchenSession
local function assemble(s)
    if not step('assemble') then return end

    local kitchen <const> = s.config.kitchen
    local board <const> = at(s, kitchen.board)

    if s.bun then carry(s, s.bun, board, { yaw = yaw(s) }) end

    if s.sausage then
        carry(s, s.sausage, board + vec3(0.0, 0.0, STACK_LIFT), { yaw = yaw(s), pitch = s.roll, radius = sausageRadius(s) })
    end

    Station.remove(s.sausage)
    Station.remove(s.bun)
    s.sausage, s.bun = nil, nil

    s.hotdog = Station.prop(kitchen.models.hotdog, board, yaw(s))

    if s.hotdog then
        local low <const>, high <const> = GetModelDimensions(GetEntityModel(s.hotdog))

        if high.y - low.y > high.x - low.x then Station.orient(s.hotdog, yaw(s) + ALONG_Y, 0.0) end

        Sauce.ready(s.sauce, s.config, s.hotdog)
    end

    s.stage = 'sauce'
    Station.cue('Prop_Drop_Land', 'DLC_Dmod_Prop_Editor_Sounds')
end

---@param s KitchenSession
local function clearFood(s)
    s.cookStart, s.bunStart = nil, nil

    stopHeat(s)
    Station.remove(s.sausage)
    Station.remove(s.bun)
    Station.remove(s.hotdog)
    Sauce.clear(s.sauce)

    Dressing.close(s.cart)

    s.sausage, s.bun, s.hotdog = nil, nil, nil
    s.stage, s.cookMs, s.cookLook, s.bunMs, s.bunLook = 'sausage', 0, nil, 0, nil
    s.sides, s.side, s.roll = { 0, 0 }, 1, 0.0
end

---@param result HotdogServeResult
local function announce(result)
    local cash = ('$%d'):format(result.paid)

    if result.tip > 0 then cash = ('$%d and a $%d tip'):format(result.paid, result.tip) end

    if result.ok then
        Station.cue('PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET')
        return core:Notify(('"That\'s exactly it." %s. Street rep %d'):format(cash, result.rep), 'success')
    end

    Station.cue('ERROR', 'HUD_AMMO_SHOP_SOUNDSET')

    local complaint <const> = table.concat(result.misses, ', ')
    local paid <const> = result.paid > 0 and ('They paid %s'):format(cash) or 'They refused to pay'

    core:Notify(('"%s." %s. Street rep %d'):format(complaint, paid, result.rep), 'error')
end

---@param s KitchenSession
local function serve(s)
    if not Customers.front() then
        return core:Notify('Nobody is at the counter yet', 'inform')
    end

    local result <const> = lib.callback.await('cobalt_cityhall:hotdog:serve', false) --[[@as HotdogServeResult?]]

    if not result then return core:Notify('Give it a moment', 'error') end

    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 4.0, -4.0, 1500, 48, 0.0, false, false, false)
    announce(result)
    Customers.served(result)
    clearFood(s)
end

---@param s KitchenSession
local function bin(s)
    if not lib.callback.await('cobalt_cityhall:hotdog:discard', false) then return end

    Station.cue('Trash_Bag_Land', 'DLC_HEIST_SERIES_A_SOUNDS')
    clearFood(s)
end

---@type table<SausageLook, string>
local SAUSAGE_MODEL <const> = {
    raw = 'rawSausage',
    halfDown = 'halfDownSausage',
    halfUp = 'halfUpSausage',
    cooked = 'cookedSausage',
    burnt = 'burntSausage',
}

---@type table<BunLevel, string>
local BUN_MODEL <const> = { plain = 'bun', warm = 'bun', toasted = 'toastedBun', burnt = 'burntBun' }

---@param s KitchenSession
---@param now integer
local function updateLooks(s, now)
    local kitchen <const> = s.config.kitchen

    if s.cookStart and s.sausage then
        local look <const> = sausageLook(s, now)

        if look ~= s.cookLook then
            s.cookLook = look
            s.sausage = Station.swap(s.sausage, kitchen.models[SAUSAGE_MODEL[look]], kitchen.standIns.food)

            if look == 'burnt' and not s.smoke then s.smoke = wellFx(s, kitchen.fryer, kitchen.smoke) end
        end
    end

    if s.bunStart and s.bun then
        local level <const> = Hotdog.bunLevel(s.config, now - s.bunStart)

        if level ~= s.bunLook then
            s.bunLook = level
            s.bun = Station.swap(s.bun, kitchen.models[BUN_MODEL[level]], kitchen.standIns.food)

            if level == 'burnt' and not s.smoke then s.smoke = wellFx(s, kitchen.griddle, kitchen.smoke) end
        end
    end
end

---@param ms integer
---@param doneAt integer
---@param burntAt integer
---@param done string
---@return string
local function countdown(ms, doneAt, burntAt, done)
    if ms < doneAt then return ('%s in %d s'):format(done, math.ceil((doneAt - ms) / 1000)) end
    if ms < burntAt then return ('%s now. Take it out within %d s'):format(done, math.ceil((burntAt - ms) / 1000)) end

    return 'Burning. Take it out'
end

---@type table<CookLevel, string>
local COOK_LABEL <const> = { raw = 'Raw', cooked = 'Cooked', burnt = 'Charred' }

---@type table<BunLevel, string>
local BUN_LABEL <const> = { plain = 'Plain', warm = 'Warm', toasted = 'Toasted', burnt = 'Burnt' }

---@param s KitchenSession
---@param now integer
---@return string
local function hint(s, now)
    local kitchen <const> = s.config.kitchen

    if s.cookStart then
        local sides <const> = liveSides(s, now)
        local down <const>, up <const> = sides[s.side], sides[s.side == 1 and 2 or 1]

        if down >= kitchen.sausage.cookedAt / 2 and up < down / 2 then
            return 'Roll it [R] so the other side browns'
        end

        return countdown(now - s.cookStart, kitchen.sausage.cookedAt, kitchen.sausage.burntAt, 'Cooked')
    end

    if s.bunStart then
        return countdown(now - s.bunStart, kitchen.toast.toastedAt, kitchen.toast.burntAt, 'Toasted')
    end

    if s.stage == 'sausage' then return 'Drop a sausage in the oil' end
    if s.stage == 'bun' then return 'Toast the bun on the plate, or keep it plain' end
    if s.stage == 'assemble' then return 'Put the sausage in the bun' end

    return 'Squeeze each sauce along the whole hot dog, then serve'
end

---@param s KitchenSession
---@param now integer
local function sendMeter(s, now)
    if now - s.sentAt < METER_SEND_MS then return end

    s.sentAt = now

    local kitchen <const> = s.config.kitchen
    local cookMs <const> = s.cookStart and now - s.cookStart or s.cookMs
    local bunMs <const> = s.bunStart and now - s.bunStart or s.bunMs
    local front <const> = Customers.front()

    Dui.send(s.meter, {
        type = 'meter',
        stage = s.stage,
        hint = hint(s, now),
        sausage = {
            value = Hotdog.meter(cookMs, kitchen.sausage.cookedAt, kitchen.sausage.burntAt),
            live = s.cookStart ~= nil,
            text = cookMs > 0 and COOK_LABEL[Hotdog.cookLevel(s.config, cookMs)] or 'Waiting',
        },
        bun = {
            value = Hotdog.meter(bunMs, kitchen.toast.toastedAt, kitchen.toast.burntAt),
            live = s.bunStart ~= nil,
            text = BUN_LABEL[Hotdog.bunLevel(s.config, bunMs)],
        },
        sauce = s.config.sauces[s.sauce.index].id,
        added = s.sauce.added,
        order = front?.order,
    })
end

---@param s KitchenSession
---@param text string
local function tooltip(s, text)
    if s.tooltip == text then return end

    s.tooltip = text
    core:ShowTextUI(text, { position = 'bottom-center' })
end

---@param s KitchenSession
---@return string
local function controlsFor(s)
    local tail <const> = '  [X] Bin it  [Backspace] Step away'

    if s.busy then return 'Working…' .. tail end

    if s.stage == 'sausage' then
        if s.cookStart then return '[R] Roll it  [E] Lift it out' .. tail end

        return '[E] Sausage into the oil' .. tail
    end

    if s.stage == 'bun' then
        if s.bunStart then return '[E] Lift the bun off' .. tail end

        return '[E] Toast the bun  [G] Keep it plain' .. tail
    end

    if s.stage == 'assemble' then return '[E] Sausage into the bun' .. tail end

    return '[1-5] Pick a bottle  [Mouse] Aim  [Hold click] Squeeze along it  [F] Serve' .. tail
end

---@param s KitchenSession
---@param now integer
local function handle(s, now)
    local pressed <const> = IsDisabledControlJustPressed

    if s.stage == 'sauce' then
        for index, key in ipairs(SAUCE_KEYS) do
            if pressed(0, key) then Sauce.pick(s.sauce, s.config, index) end
        end

        Sauce.update(s.sauce, s.config, s.cart, now, step, function(work) act(s, work) end)
    end

    if s.busy then return end

    if pressed(0, CONTROL.bin) then return act(s, function() bin(s) end) end

    if s.stage == 'sausage' then
        if pressed(0, CONTROL.primary) then
            act(s, function() if s.cookStart then sausageOut(s) else sausageIn(s) end end)
        elseif pressed(0, CONTROL.turn) and s.cookStart then
            act(s, function() turn(s) end)
        end
    elseif s.stage == 'bun' then
        if pressed(0, CONTROL.primary) then
            act(s, function() if s.bunStart then bunOut(s) else bunIn(s, true) end end)
        elseif pressed(0, CONTROL.plain) and not s.bunStart then
            act(s, function() bunIn(s, false) end)
        end
    elseif s.stage == 'assemble' then
        if pressed(0, CONTROL.primary) then act(s, function() assemble(s) end) end
    elseif pressed(0, CONTROL.serve) and not s.sauce.squeezing then
        act(s, function() serve(s) end)
    end
end

---@param config StandConfig
---@param cart integer
local function walkBehind(config, cart)
    local spot <const> = Station.at(cart, config.spots.vendor)
    local heading <const> = GetEntityHeading(cart) + config.spots.vendorHeading
    local deadline <const> = GetGameTimer() + WALK_TIMEOUT_MS

    TaskGoStraightToCoord(cache.ped, spot.x, spot.y, spot.z, 1.0, WALK_TIMEOUT_MS, heading, 0.2)

    while #(GetEntityCoords(cache.ped).xy - spot.xy) > 0.4 and GetGameTimer() < deadline do Wait(100) end

    SetEntityHeading(cache.ped, heading)
    Work.playAnim(config.kitchen.anim)
    Props.hold(config.kitchen.prop)
end

---@param config StandConfig
---@param cart integer
---@return integer
local function openCamera(config, cart)
    local camera <const> = config.kitchen.camera
    local from <const> = Station.at(cart, camera.offset)
    local target <const> = Station.at(cart, camera.target)
    local cam <const> = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        from.x, from.y, from.z,
        0.0, 0.0, 0.0,
        camera.fov,
        false, 2
    )

    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, camera.easeMs, true, true)

    return cam
end

---@param s KitchenSession
local function setUp(s)
    local kitchen <const> = s.config.kitchen
    local models <const> = kitchen.models

    Dressing.ensure(s.cart)
    s.tongs = Station.prop(models.tongs, at(s, kitchen.supply), yaw(s))
    s.liquid = Station.prop(kitchen.oil.liquid, at(s, kitchen.fryer + vec3(0.0, 0.0, LIQUID_LIFT)), yaw(s))

    for index = 1, BUBBLES - RING_BUBBLES do
        s.spots[index] = vec2((math.random() * 2 - 1) * WELL_HALF.x, (math.random() * 2 - 1) * WELL_HALF.y)
    end

    for index = 1, BUBBLES do
        local bubble <const> = Station.prop(models.bubble, at(s, kitchen.fryer), yaw(s))

        if bubble then s.bubbles[index] = bubble end
    end

    s.bubbling = true
    showBubbles(s, false)

    Station.grip(s.tongs, at(s, kitchen.supply), yaw(s))
end

---@param s KitchenSession
---@param easeMs integer
local function tearDown(s, easeMs)
    clearFood(s)

    Station.remove(s.tongs)
    Station.remove(s.liquid)

    for _, bubble in ipairs(s.bubbles) do Station.remove(bubble) end

    Dui.destroy(s.meter)
    RenderScriptCams(false, easeMs > 0, easeMs, true, true)
    DestroyCam(s.cam, false)
    core:HideTextUI()
    Props.release()

    if Work.isDown() then return end

    ClearPedTasks(cache.ped)
    blockActions(false)
end

---@param config StandConfig
---@param cart integer
---@return KitchenSession
local function open(config, cart)
    blockActions(true)
    walkBehind(config, cart)

    ---@type KitchenSession
    local s <const> = {
        config = config,
        cart = cart,
        cam = openCamera(config, cart),
        meter = Dui.create('meter', METER_WIDTH, METER_HEIGHT, { stage = 'sausage' }),
        stage = 'sausage',
        busy = false,
        bubbles = {},
        spots = {},
        bubbling = false,
        cookMs = 0,
        sides = { 0, 0 },
        side = 1,
        sideAt = 0,
        roll = 0.0,
        bunMs = 0,
        sauce = Sauce.new(config),
        sentAt = 0,
    }

    setUp(s)

    return s
end

---@param s KitchenSession
---@return boolean
local function wantsOut(s)
    if Work.isDown() then return true end

    return IsDisabledControlJustPressed(0, CONTROL.leave) and not s.busy
end

---@param config StandConfig
---@param cart integer
function Kitchen.run(config, cart)
    if running then return end
    if not lib.callback.await('cobalt_cityhall:hotdog:cook', false, true) then return end

    running = true
    lib.callback.await('cobalt_cityhall:hotdog:discard', false)

    local s <const> = open(config, cart)

    current = s

    while running and DoesEntityExist(cart) do
        local now <const> = GetGameTimer()

        for _, control in ipairs(BLOCKED) do DisableControlAction(0, control, true) end

        if IsPauseMenuActive() then SetPauseMenuActive(false) end
        if wantsOut(s) then break end

        handle(s, now)
        updateLooks(s, now)
        fizz(s, now)
        sendMeter(s, now)
        tooltip(s, controlsFor(s))
        Dui.drawScreen(s.meter, METER_SCREEN.x, METER_SCREEN.y, METER_SCREEN.width)

        Wait(0)
    end

    running = false

    while s.busy do Wait(0) end

    current = nil
    tearDown(s, config.kitchen.camera.easeMs)

    lib.callback.await('cobalt_cityhall:hotdog:discard', false)
    lib.callback.await('cobalt_cityhall:hotdog:cook', false, false)
end

function Kitchen.leave()
    running = false
end

---@return boolean
function Kitchen.active()
    return running
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not current then return end

    tearDown(current, 0)
end)

return Kitchen
