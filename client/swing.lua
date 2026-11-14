local sound <const> = exports.cobalt_sound

---@param swing JobSwing
local function strike(swing)
    local at <const> = GetOffsetFromEntityInWorldCoords(cache.ped, swing.reach.x, swing.reach.y, swing.reach.z)

    for _, fx in ipairs(swing.particles) do
        UseParticleFxAssetNextCall(fx.asset)
        StartNetworkedParticleFxNonLoopedAtCoord(fx.name, at.x, at.y, at.z, 0.0, 0.0, 0.0, fx.scale, false, false, false)
    end

    sound:PlayAt(at, swing.sounds[math.random(1, #swing.sounds)], swing.volume, swing.distance)
end

---@param last number
---@param phase number
---@param hit number
---@return boolean
local function crossed(last, phase, hit)
    if phase >= last then return last < hit and phase >= hit end

    return last < hit or phase >= hit
end

---@param anim { dict: string, clip: string }
---@param swing JobSwing
---@param isRunning fun(): boolean
local function track(anim, swing, isRunning)
    for _, fx in ipairs(swing.particles) do lib.requestNamedPtfxAsset(fx.asset) end

    local last = 0.0

    while isRunning() do
        if IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then
            local phase <const> = GetEntityAnimCurrentTime(cache.ped, anim.dict, anim.clip)

            if crossed(last, phase, swing.hitPhase) then strike(swing) end

            last = phase
        end

        Wait(0)
    end

    for _, fx in ipairs(swing.particles) do RemoveNamedPtfxAsset(fx.asset) end
end

---@param anim { dict: string, clip: string }
---@param swing JobSwing
---@return fun() stop
return function(anim, swing)
    local running = true

    CreateThread(function()
        track(anim, swing, function() return running end)
    end)

    return function() running = false end
end
