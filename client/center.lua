local config <const> = require 'config'
local Work <const> = require 'client.work'
local Nui <const> = require 'client.nui'

local center <const> = config.center

---@type integer?
local clerk

Work.blip(center.coords.xyz, center.blip, center.label, 0.85)

lib.points.new({
    coords = center.coords.xyz,
    distance = 60.0,
    onEnter = function()
        clerk = Work.spawnPed(center.ped, center.coords, 'WORLD_HUMAN_CLIPBOARD')

        if not clerk then return end

        exports.ox_target:addLocalEntity(clerk, {
            {
                name = 'cobalt_cityhall:center',
                label = 'Browse jobs',
                icon = 'fa-solid fa-briefcase',
                distance = config.interactRange,
                onSelect = function() Nui.open('center') end,
            },
        })
    end,
    onExit = function()
        Work.delete(clerk)
        clerk = nil
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then Work.delete(clerk) end
end)
