local config <const> = require 'config'
local Progress <const> = require 'server.progress'
local Registry <const> = require 'server.registry'
local Payment <const> = require 'server.payment'

local dmv <const> = config.dmv
local practical <const> = dmv.practical
local route <const> = practical.route
local TICK_MS <const> = 500
local SPAWN_GRACE_MS <const> = 10000
local SPAWN_CLEARANCE <const> = 3.0
local MAX_TRAVEL_SPEED <const> = 70.0
local TRAVEL_SLACK <const> = 15.0
local UNIT_FACTORS <const> = { mph = 2.236936, kmh = 3.6 }
local unitFactor <const> = UNIT_FACTORS[practical.unit] or UNIT_FACTORS.mph

---@class DriveStrike
---@field kind 'speed' | 'crash'
---@field checkpoint integer
---@field speed? integer
---@field limit? integer

---@class DriveTest
---@field src integer
---@field citizenid string
---@field vehicle integer
---@field plate string
---@field checkpoint integer the index of the next checkpoint in the route
---@field strikes DriveStrike[]
---@field speeding boolean
---@field lastSpeedStrike integer
---@field lastCrashStrike integer
---@field body number
---@field startedAt integer
---@field graceUntil integer
---@field awaySince? integer
---@field lastCoords vector3
---@field lastAt integer

---@class DriveTestView
---@field checkpoint integer
---@field total integer
---@field strikes DriveStrike[]
---@field maxStrikes integer
---@field unit string
---@field returnSeconds? integer seconds left to get back in the driver's seat

---@class DriveTestResult
---@field passed boolean
---@field reason? string
---@field reached integer checkpoints driven through
---@field total integer
---@field strikes DriveStrike[]
---@field maxStrikes integer
---@field seconds integer
---@field unit string

---@type table<integer, DriveTest>
local tests <const> = {}

---@type unknown?
local ticker

local DriveTest <const> = {}

---@param src integer
---@return boolean
function DriveTest.active(src)
    return tests[src] ~= nil
end

---@param progress? DmvProgress
---@return integer fee
---@return integer wait seconds before a retake can start
function DriveTest.terms(progress)
    local failedAt <const> = progress?.failedAt

    if not failedAt then return practical.fee, 0 end

    return practical.retakeFee, math.max(0, practical.retakeCooldown - (os.time() - failedAt))
end

---@param test DriveTest
---@param now integer
---@return DriveTestView
local function view(test, now)
    local deadline <const> = test.awaySince and test.awaySince + practical.leaveSeconds * 1000

    return {
        checkpoint = test.checkpoint,
        total = #route,
        strikes = test.strikes,
        maxStrikes = practical.maxStrikes,
        unit = practical.unit,
        returnSeconds = deadline and math.ceil((deadline - now) / 1000) or nil,
    }
end

---@param test DriveTest
---@param now integer
local function sync(test, now)
    TriggerClientEvent('cobalt_cityhall:driveTest', test.src, view(test, now))
end

---@param test DriveTest
local function release(test)
    tests[test.src] = nil

    exports.cobalt_vehiclekeys:RemoveKeys(test.plate)

    if DoesEntityExist(test.vehicle) then DeleteEntity(test.vehicle) end

    if not next(tests) and ticker then
        ClearInterval(ticker)
        ticker = nil
    end
end

---@param test DriveTest
---@param passed boolean
---@param reason? string
local function finish(test, passed, reason)
    release(test)

    if passed then
        Progress.clear(test.citizenid)
    else
        Progress.failPractical(test.citizenid)
    end

    local ped <const> = GetPlayerPed(test.src)

    SetEntityCoords(ped, dmv.returnPoint.x, dmv.returnPoint.y, dmv.returnPoint.z, false, false, false, false)
    SetEntityHeading(ped, dmv.returnPoint.w)

    TriggerClientEvent('cobalt_cityhall:driveTestResult', test.src, {
        passed = passed,
        reason = reason,
        reached = passed and #route or test.checkpoint - 1,
        total = #route,
        strikes = test.strikes,
        maxStrikes = practical.maxStrikes,
        seconds = os.time() - test.startedAt,
        unit = practical.unit,
    })

    local message <const> = passed and 'Passed the driving test' or ('Failed the driving test: %s'):format(reason)

    exports.cobalt_core:LogPlayer(test.src, 'cityhall.dmv', message, {
        checkpoint = test.checkpoint,
        strikes = #test.strikes,
    })
end

---@param test DriveTest
---@param reason string
local function fail(test, reason)
    finish(test, false, reason)
end

---@param test DriveTest
local function pass(test)
    exports.cobalt_core:GrantLicense(test.src, 'driver', 'the DMV')
    finish(test, true)
end

---@param test DriveTest
---@param now integer
---@param strike DriveStrike
local function addStrike(test, now, strike)
    test.strikes[#test.strikes + 1] = strike

    if #test.strikes >= practical.maxStrikes then
        return fail(test, ('You reached %d strikes at checkpoint %d.'):format(#test.strikes, test.checkpoint))
    end

    sync(test, now)
end

---@param test DriveTest
---@param now integer
local function checkSpeed(test, now)
    local speed <const> = #GetEntityVelocity(test.vehicle) * unitFactor
    local limit <const> = route[test.checkpoint].limit

    if speed <= limit + practical.tolerance then
        test.speeding = false
        return
    end

    local counted <const> = test.speeding or now - test.lastSpeedStrike < practical.strikeCooldown * 1000

    test.speeding = true

    if counted then return end

    test.lastSpeedStrike = now

    addStrike(test, now, { kind = 'speed', checkpoint = test.checkpoint, speed = math.floor(speed), limit = limit })
end

---@param test DriveTest
---@param now integer
local function checkCrash(test, now)
    local body <const> = GetVehicleBodyHealth(test.vehicle)
    local damage <const> = test.body - body

    test.body = body

    if damage < practical.crashDamage or now - test.lastCrashStrike < practical.strikeCooldown * 1000 then return end

    test.lastCrashStrike = now

    addStrike(test, now, { kind = 'crash', checkpoint = test.checkpoint })
end

---@param test DriveTest
---@param now integer
---@return boolean failed
local function checkSeat(test, now)
    local driving <const> = GetPedInVehicleSeat(test.vehicle, -1) == GetPlayerPed(test.src)

    if driving then
        if test.awaySince then
            test.awaySince = nil
            sync(test, now)
        end

        return false
    end

    if now < test.graceUntil then return false end

    if not test.awaySince then
        test.awaySince = now
        sync(test, now)
        return false
    end

    if now - test.awaySince < practical.leaveSeconds * 1000 then return false end

    fail(test, 'You left the car.')

    return true
end

---@param test DriveTest
---@param now integer
---@return boolean failed
local function checkWreck(test, now)
    if not DoesEntityExist(test.vehicle) then
        fail(test, 'The car is gone.')
        return true
    end

    if now < test.graceUntil then return false end
    if GetEntityHealth(test.vehicle) > 0 and GetVehicleEngineHealth(test.vehicle) > 0 then return false end

    fail(test, 'The car was wrecked.')

    return true
end

---@param test DriveTest
---@param now integer
---@return boolean failed
local function checkTravel(test, now)
    local coords <const> = GetEntityCoords(test.vehicle)
    local travelled <const> = #(coords - test.lastCoords)
    local allowed <const> = MAX_TRAVEL_SPEED * (now - test.lastAt) / 1000 + TRAVEL_SLACK

    test.lastCoords, test.lastAt = coords, now

    if now < test.graceUntil or travelled <= allowed then return false end

    fail(test, 'The car moved further than it could drive.')
    exports.cobalt_core:LogPlayer(test.src, 'cityhall.dmv', 'The driving test car jumped', {
        travelled = travelled,
        allowed = allowed,
    }, 'security')

    return true
end

---@param test DriveTest
---@param now integer
local function check(test, now)
    if checkWreck(test, now) or checkSeat(test, now) or checkTravel(test, now) then return end
    if test.awaySince or now < test.graceUntil then return end

    checkCrash(test, now)

    if tests[test.src] then checkSpeed(test, now) end
    if not tests[test.src] then return end

    if #(test.lastCoords.xy - route[test.checkpoint].coords.xy) > practical.checkpointRadius then return end
    if test.checkpoint == #route then return pass(test) end

    test.checkpoint += 1
    test.speeding = false

    sync(test, now)
end

local function tick()
    local now <const> = GetGameTimer()

    for _, test in pairs(tests) do
        check(test, now)
    end
end

---@return boolean
local function spawnClear()
    for _, vehicle in ipairs(GetAllVehicles() --[[@as integer[] ]]) do
        if #(GetEntityCoords(vehicle) - practical.spawn.xyz) < SPAWN_CLEARANCE then return false end
    end

    return true
end

---@param seconds integer
---@return string
local function duration(seconds)
    local minutes <const> = seconds // 60

    return minutes > 0 and ('%dm %ds'):format(minutes, seconds % 60) or ('%ds'):format(seconds)
end

---@param src integer
---@return boolean ok
---@return string? reason
function DriveTest.start(src)
    local citizenid <const> = Registry.citizenid(src)

    if not citizenid then return false, 'Your character isn\'t loaded' end
    if tests[src] then return false, 'You are already taking the driving test' end
    if exports.cobalt_core:HasLicense(src, 'driver') then return false, 'You already hold a driver licence' end

    local progress <const> = Progress.get(citizenid)

    if not progress?.theory then return false, 'Pass the theory test first' end

    local fee <const>, wait <const> = DriveTest.terms(progress)

    if wait > 0 then return false, ('You can retake the driving test in %s'):format(duration(wait)) end
    if not spawnClear() then return false, 'A car is blocking the test bay. Try again in a moment.' end

    local account <const> = Payment.charge(src, fee, 'DMV driving test')

    if not account then return false, ('The driving test costs $%d'):format(fee) end

    local vehicle <const> = exports.cobalt_core:SpawnVehicle(src, practical.model, practical.spawn, true, 'automobile')

    if not vehicle then
        Payment.refund(src, account, fee, 'DMV driving test refund')

        return false, 'The test car failed to spawn. Try again.'
    end

    local plate <const> = ('%s%04d'):format(practical.plate, math.random(0, 9999))
    local now <const> = GetGameTimer()

    SetVehicleNumberPlateText(vehicle, plate)
    exports.cobalt_vehiclekeys:GiveKey(src, plate, vehicle)

    local test <const> = {
        src = src,
        citizenid = citizenid,
        vehicle = vehicle,
        plate = plate,
        checkpoint = 1,
        strikes = {},
        speeding = false,
        lastSpeedStrike = 0,
        lastCrashStrike = 0,
        body = 1000.0,
        startedAt = os.time(),
        graceUntil = now + SPAWN_GRACE_MS,
        lastCoords = practical.spawn.xyz,
        lastAt = now,
    }

    tests[src] = test
    ticker = ticker or SetInterval(tick, TICK_MS)

    TriggerClientEvent('cobalt_cityhall:driveTest', src, view(test, now))
    exports.cobalt_core:LogPlayer(src, 'cityhall.dmv', 'Started the driving test', { fee = fee, account = account })

    return true
end

lib.addCommand('quitdrivetest', { help = 'End your driving test' }, function(src)
    local test <const> = tests[src]

    if not test then return Registry.notify(src, 'You aren\'t taking the driving test', 'error') end

    fail(test, 'You ended the test.')
end)

---@param src integer
local function forget(src)
    local test <const> = tests[src]

    if test then release(test) end
end

AddEventHandler('playerDropped', function()
    forget(source)
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', forget)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, test in pairs(tests) do
        release(test)
    end
end)

return DriveTest
