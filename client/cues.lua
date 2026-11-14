---@alias CityhallCue 'start' | 'checkpoint' | 'strike' | 'passed' | 'failed' | 'theoryPassed' | 'gps' | 'purchase'

---@class FrontendSound
---@field name string
---@field set string

---@type table<CityhallCue, FrontendSound>
local sounds <const> = {
    start = { name = 'GO', set = 'HUD_MINI_GAME_SOUNDSET' },
    checkpoint = { name = 'CHECKPOINT_NORMAL', set = 'HUD_MINI_GAME_SOUNDSET' },
    strike = { name = 'CHECKPOINT_MISSED', set = 'HUD_MINI_GAME_SOUNDSET' },
    passed = { name = 'RANK_UP', set = 'HUD_AWARDS' },
    failed = { name = 'LOSER', set = 'HUD_AWARDS' },
    theoryPassed = { name = 'MEDAL_UP', set = 'HUD_MINI_GAME_SOUNDSET' },
    gps = { name = 'WAYPOINT_SET', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    purchase = { name = 'PURCHASE', set = 'HUD_LIQUOR_STORE_SOUNDSET' },
}

---@param cue CityhallCue
return function(cue)
    local sound <const> = sounds[cue]

    PlaySoundFrontend(-1, sound.name, sound.set, true)
end
