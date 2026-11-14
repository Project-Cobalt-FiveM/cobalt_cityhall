---@meta

---@alias JobKind 'taxi' | 'route' | 'gather' | 'collect' | 'stand'

---@alias LossReason 'vehicle' | 'down'

---@class JobBlip
---@field sprite integer
---@field color integer
---@field coords? vector3

---@class JobSite
---@field label string
---@field coords vector4
---@field ped? string
---@field scenario? string
---@field blip JobBlip

---@class JobProp
---@field model string
---@field bone integer
---@field pos vector3
---@field rot vector3

---@class JobSwingParticle
---@field asset string
---@field name string
---@field scale number

---@class JobSwing
---@field hitPhase number anim phase, 0 to 1, when the tool lands
---@field reach vector3 offset from the player where the tool lands
---@field particles JobSwingParticle[]
---@field sounds string[] cobalt_sound files, one picked at random per hit
---@field volume number
---@field distance number meters the hit carries

---@class JobAction
---@field label string shown on the progress bar
---@field prompt string shown before the player starts
---@field duration integer | { [1]: integer, [2]: integer }
---@field anim { dict?: string, clip?: string, scenario?: string, flag?: integer }
---@field prop? JobProp
---@field swing? JobSwing particles and a sound on every swing of the anim

---@class JobVehicle
---@field label string
---@field model string
---@field plate string
---@field spawns vector4[]

---@class JobStop
---@field label string
---@field coords vector3 | vector4 the heading in `w` turns the player to face the work
---@field site? string stops sharing a site are worked as one route when `bySite` is set
---@field task? string key into `RouteConfig.tasks`; the stop uses `action` without one

---@class TaxiStop
---@field label string
---@field coords vector4 the kerbside lane point the cab stops at, heading along traffic
---@field passenger vector4 where the fare waits on the pavement, facing the road

---@class TaxiConfig
---@field base integer
---@field perMeter number
---@field minTrip number
---@field passengers string[]
---@field stops TaxiStop[]

---@class RoutePay
---@field perAction integer
---@field perMeter? number
---@field routeBonus? integer
---@field bonusText? string as in "$200 for a full route"
---@field bonusLabel? string as in "Full route of 10 bins"

---@class RouteCargo
---@field boxes integer
---@field model string
---@field size vector3 the box prop's width, depth and height, with its origin at the centre
---@field columns integer boxes across the cargo bed
---@field rows integer boxes from the back doors inward
---@field gap number meters between neighbouring boxes
---@field floor number cargo floor height in vehicle space
---@field doorLine number y of the closed back doors in vehicle space
---@field fromDoors number meters left clear between the doors and the nearest row

---@class RouteConfig
---@field length integer stops per route, unused when `bySite` is set
---@field bySite? boolean each route is every stop of one site, nearest first
---@field tasks? table<string, JobAction> actions a stop can name in its `task`
---@field marker? boolean draws a marker on the stop
---@field actions integer actions needed at each stop
---@field chain? boolean pick each next stop nearest the last
---@field radius number
---@field vehicleWithin? number the work vehicle must be this close to the stop
---@field atVehicle? boolean the action targets the work vehicle instead of a point
---@field load? JobAction loads one box into the vehicle at the site; needs `cargo`
---@field cargo? RouteCargo boxes loaded before each run and unloaded one per action
---@field unit string
---@field pay RoutePay
---@field action JobAction
---@field stops JobStop[]

---@class CollectZone
---@field label string
---@field coords vector3
---@field radius number
---@field pay? integer paid for clearing this area; defaults to `perBin` times `bins`

---@class CollectPay
---@field perBin integer paid per bin when an area is cleared
---@field routeBonus integer

---@class CollectConfig
---@field length integer areas per route
---@field bins integer bins to empty in each area
---@field truckWithin number the work vehicle must be this close to a bin
---@field pay CollectPay
---@field models string[] bin and dumpster models players can empty
---@field empty JobAction
---@field open JobAction opens the back of the vehicle so bags can go in
---@field throw JobAction
---@field bag JobProp carried from the bin to the vehicle
---@field zones CollectZone[]

---@class GatherYield
---@field name? string inventory item; nil pays `value` in money instead
---@field label? string
---@field weight integer
---@field value? integer
---@field amount? { [1]: integer, [2]: integer }

---@class GatherPoint
---@field coords vector3
---@field heading? number
---@field label? string
---@field radius? number

---@class GatherInput
---@field name string inventory item taken on each finished action
---@field amount integer
---@field label string as in "You need 2 grapes"

---@class JobGear
---@field name string inventory item
---@field label string
---@field amount integer items in one purchase
---@field price integer dollars, cash then bank

---@class GatherGroup
---@field label string
---@field requires? GatherInput inventory item the player must carry, never used up
---@field consumes? GatherInput
---@field marker? boolean draws a marker on every ready point
---@field guide? boolean routes the GPS to the nearest ready point
---@field zone? boolean stand inside the point's radius instead of targeting a prop
---@field prop? string
---@field props? string[]
---@field radius? number
---@field cooldown integer milliseconds a point rests after use; 0 never rests
---@field amount { [1]: integer, [2]: integer }
---@field blip? JobBlip
---@field action JobAction
---@field yields GatherYield[]
---@field points GatherPoint[]

---@class JobDefinition : JobData
---@field id string the data file's name, set when the job loads

---@class JobData
---@field label string
---@field description string
---@field icon string
---@field kind JobKind
---@field doneLabel string the shift stat counting finished work
---@field goods? string what a gather job sells, as in "Ore sells for $2–$20"
---@field crewSize integer
---@field site JobSite
---@field vehicle? JobVehicle
---@field taxi? TaxiConfig
---@field route? RouteConfig
---@field collect? CollectConfig
---@field groups? GatherGroup[]
---@field prices? table<string, integer>
---@field gear? JobGear[] what the site ped sells to workers
---@field entrance? { outside: vector4, inside: vector4 }

---@class TaskView
---@field title string
---@field label string
---@field coords vector3
---@field radius number
---@field step? string
---@field stage? string
---@field progress? { done: integer, total: integer }
---@field open? boolean the back of the crew vehicle is open
---@field task? string the stop's task key
---@field heading? number the way the player faces for the work
---@field marker? boolean
---@field passenger? vector4 where a taxi fare waits
---@field distance? integer meters from the player, filled in on the client

---@class CrewMemberView
---@field id integer
---@field name string
---@field leader boolean
---@field earned integer

---@class ShiftView
---@field job string
---@field startedAt integer unix seconds
---@field earned integer
---@field done integer
---@field crew CrewMemberView[]
---@field task? TaskView
---@field vehicle? integer network id
---@field carrying? boolean holding a trash bag
