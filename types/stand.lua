---@meta

---@alias LidName 'fryer' | 'griddle'

---@alias SauceId 'mustard' | 'ketchup' | 'mayo' | 'relish' | 'onions'

---@alias CookLevel 'raw' | 'cooked' | 'burnt'

---@alias BunLevel 'plain' | 'warm' | 'toasted' | 'burnt'

---@class StandAnim
---@field dict string
---@field clip string
---@field flag integer

---@class StandPlace
---@field range number meters from the player the cart can go
---@field maxSlope number degrees
---@field maxStep number meters the ground may rise or fall under the cart
---@field footprint vector2 half width and half depth of the cart
---@field duration integer
---@field label string
---@field anim StandAnim

---@class StandPack
---@field duration integer
---@field label string
---@field anim StandAnim

---@class StandSpots
---@field vendor vector3 where the vendor stands to cook, in the cart's space
---@field vendorHeading number degrees from the cart's heading the vendor faces
---@field counter vector3 where the first customer stands, in the cart's space
---@field customerHeading number degrees from the cart's heading customers face
---@field queueStep vector3 offset from one customer in line to the next, in the cart's space

---@class StandFx
---@field asset string
---@field name string
---@field scale number
---@field lift number meters above the well floor

---@class StandKitchen
---@field fryer vector3 centre of the oil surface in the cart's fryer well
---@field griddle vector3 centre of the toasting plate in the cart's bun well
---@field lids table<LidName, vector3> the hinge of each lid panel, on the well's back edge
---@field ready { sausage: vector3, bun: vector3 } spots on the cart's rack for finished food
---@field supply vector3 where fresh sausages and buns come from
---@field board vector3 where the hot dog is put together and sauced
---@field camera { offset: vector3, target: vector3, fov: number, easeMs: integer }
---@field motion { carryMs: integer, lidMs: integer, lift: number }
---@field sausage { cookedAt: integer, burntAt: integer, evenShare: number } milliseconds the sausage spends in the grill
---@field toast { toastedAt: integer, burntAt: integer } milliseconds the bun spends in the grill
---@field graceMs integer the server stretches each done window by this much at both ends
---@field models { rawSausage: string, cookedSausage: string, halfDownSausage: string, halfUpSausage: string, burntSausage: string, bun: string, toastedBun: string, burntBun: string, hotdog: string, lids: table<LidName, string>, tongs: string, bubble: string }
---@field oil { liquid: string } the rippling oil surface laid over the cart's fryer well while cooking
---@field standIns { food: string, bottle: string } base game models used until the custom ones stream
---@field steam StandFx
---@field smoke StandFx
---@field sizzle { sound: string, volume: number, distance: number } cobalt_sound file looped on the cart while something is on the grill
---@field anim JobAnim played while cooking
---@field prop JobProp held while cooking

---@class StandSauce
---@field id SauceId
---@field label string
---@field model string the bottle
---@field kind 'line' | 'chunks' a squeezed line of sauce, or scattered pieces
---@field piece string model of one sauce segment, stretched along the line, or of one chunk

---@class StandCustomers
---@field radius number meters scanned for people on foot
---@field scanMs integer
---@field maxQueue integer
---@field recruitGapMs integer the server's minimum time between two customers
---@field perPed number chance each nearby pedestrian adds per scan
---@field crowdCap integer pedestrians counted at most
---@field minChance number chance per scan whenever anyone is walking nearby, so a new cart still gets customers
---@field maxChance number
---@field repBoost number at full rep the chance is multiplied by 1 + repBoost
---@field ownerRange number the vendor must be this close for customers to come
---@field patience { [1]: integer, [2]: integer } milliseconds a customer waits in line
---@field walkMs integer milliseconds allowed for the walk to the cart
---@field toastChance number
---@field sauceChance number chance each sauce is on an order
---@field idle string

---@class StandPay
---@field base integer
---@field repPrice number at full rep the price is multiplied by 1 + repPrice
---@field tip { [1]: integer, [2]: integer }
---@field repTip number at full rep the tip is multiplied by 1 + repTip

---@class StandConfig
---@field item string
---@field model string
---@field place StandPlace
---@field pack StandPack
---@field spots StandSpots
---@field kitchen StandKitchen
---@field sauces StandSauce[]
---@field squeeze { coverage: number, minMs: integer, bins: integer }
---@field customers StandCustomers
---@field pay StandPay
---@field rep { max: integer, correct: integer, wrong: integer, walkout: integer, killed: integer }
---@field limits { serveGapMs: integer, stepGapMs: integer }

---@class JobDefinition
---@field stand? StandConfig

---@class HotdogOrder
---@field toasted boolean
---@field sauces table<SauceId, boolean>

---@class HotdogCustomerView
---@field id integer
---@field order HotdogOrder
---@field patience integer milliseconds

---@class HotdogServeResult
---@field ok boolean every part matched the order
---@field paid integer
---@field tip integer
---@field rep integer the vendor's rep after the sale
---@field misses string[] what the customer noticed was wrong
