local config <const> = require 'config'
local Progress <const> = require 'server.progress'
local Registry <const> = require 'server.registry'
local Payment <const> = require 'server.payment'
local DriveTest <const> = require 'server.drivetest'
local questions <const> = require 'server.questions'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local dmv <const> = config.dmv
local DESK_SLACK <const> = 3.0

---@class TheoryQuestionView
---@field question string
---@field answers string[]

---@class TheorySitting
---@field order integer[][] for each question, the original answer index at each shown position
---@field shown TheoryQuestionView[]

---@class DmvView
---@field theory { fee: integer, passMark: integer, questions: integer, passed: boolean }
---@field practical DmvPracticalView
---@field cash integer
---@field bank integer

---@class DmvPracticalView
---@field fee integer what the next attempt costs
---@field retakeSeconds integer seconds before a retake can start
---@field checkpoints integer
---@field maxStrikes integer
---@field unit string
---@field available boolean the theory is passed and the driver licence isn't held
---@field licensed boolean
---@field active boolean
---@field cardPrice integer the driver licence card's price at City Hall

---@type table<integer, TheorySitting>
local sittings <const> = {}

---@param src integer
---@return boolean
local function atDesk(src)
    return Registry.near(src, dmv.coords, config.interactRange + DESK_SLACK)
end

---@param src integer
---@return DmvView?
local function view(src)
    local citizenid <const> = Registry.citizenid(src)

    if not citizenid then return end

    local progress <const> = Progress.get(citizenid)
    local licensed <const> = exports.cobalt_core:HasLicense(src, 'driver')
    local fee <const>, wait <const> = DriveTest.terms(progress)
    local player <const> = Cobalt.Functions.GetPlayer(src)

    return {
        theory = {
            fee = dmv.theory.fee,
            passMark = dmv.theory.passMark,
            questions = #questions,
            passed = progress?.theory == true,
        },
        practical = {
            fee = fee,
            retakeSeconds = wait,
            checkpoints = #dmv.practical.route,
            maxStrikes = dmv.practical.maxStrikes,
            unit = dmv.practical.unit,
            available = progress?.theory == true and not licensed,
            licensed = licensed,
            active = DriveTest.active(src),
            cardPrice = config.cards.licences.driver?.price or 0,
        },
        cash = player and player.Functions.GetMoney('cash') or 0,
        bank = player and player.Functions.GetMoney('bank') or 0,
    }
end

---@param count integer
---@return integer[]
local function shuffled(count)
    local order <const> = {}

    for i = 1, count do
        order[i] = i
    end

    for i = count, 2, -1 do
        local j <const> = math.random(i)

        order[i], order[j] = order[j], order[i]
    end

    return order
end

---@return TheorySitting
local function newSitting()
    local sitting <const> = { order = {}, shown = {} }

    for i, entry in ipairs(questions) do
        local order <const> = shuffled(#entry.answers)
        local answers <const> = {}

        for position, original in ipairs(order) do
            answers[position] = entry.answers[original]
        end

        sitting.order[i] = order
        sitting.shown[i] = { question = entry.question, answers = answers }
    end

    return sitting
end

lib.callback.register('cobalt_cityhall:dmv', function(src)
    return view(src)
end)

lib.callback.register('cobalt_cityhall:startTheory', function(src)
    if not atDesk(src) then return false, 'Talk to the DMV clerk to take the theory test' end

    local current <const> = view(src)

    if not current then return false, 'Your character isn\'t loaded' end
    if current.practical.licensed then return false, 'You already hold a driver licence' end
    if current.theory.passed then return false, 'You already passed the theory test' end
    if sittings[src] then return true, nil, sittings[src].shown end

    if not Payment.charge(src, dmv.theory.fee, 'DMV theory test') then
        return false, ('The theory test costs $%d'):format(dmv.theory.fee)
    end

    sittings[src] = newSitting()

    return true, nil, sittings[src].shown
end)

lib.callback.register('cobalt_cityhall:submitTheory', function(src, answers)
    local sitting <const> = sittings[src]
    local citizenid <const> = Registry.citizenid(src)

    if not sitting or not citizenid then return false, 'Start the theory test first' end
    if type(answers) ~= 'table' then return false, 'Answer every question' end

    local review <const> = {}
    local score = 0

    for i, entry in ipairs(questions) do
        local position <const> = math.tointeger(answers[i])

        if not position or not sitting.order[i][position] then return false, 'Answer every question' end

        review[i] = sitting.order[i][position] == entry.correct

        if review[i] then score += 1 end
    end

    sittings[src] = nil

    local passed <const> = score >= dmv.theory.passMark

    if passed then Progress.passTheory(src, citizenid) end

    exports.cobalt_core:LogPlayer(src, 'cityhall.dmv', ('%s the theory test with %d of %d'):format(
        passed and 'Passed' or 'Failed',
        score,
        #questions
    ), { score = score })

    return true, nil, { passed = passed, score = score, total = #questions, review = review, dmv = view(src) }
end)

lib.callback.register('cobalt_cityhall:startPractical', function(src)
    if not atDesk(src) then return false, 'Talk to the DMV clerk to book the driving test' end

    return DriveTest.start(src)
end)

---@param src integer
local function forget(src)
    sittings[src] = nil
end

AddEventHandler('playerDropped', function()
    forget(source)
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', forget)
