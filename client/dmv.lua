local config <const> = require 'config'
local Work <const> = require 'client.work'
local Nui <const> = require 'client.nui'

local dmv <const> = config.dmv

---@type integer?
local clerk

Work.blip(dmv.coords.xyz, dmv.blip, dmv.label, 0.85)

lib.points.new({
    coords = dmv.coords.xyz,
    distance = 60.0,
    onEnter = function()
        clerk = Work.spawnPed(dmv.ped, dmv.coords, 'WORLD_HUMAN_CLIPBOARD')

        if not clerk then return end

        exports.ox_target:addLocalEntity(clerk, {
            {
                name = 'cobalt_cityhall:dmv',
                label = 'Driving tests',
                icon = 'fa-solid fa-car',
                distance = config.interactRange,
                onSelect = function() Nui.open('dmv') end,
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
