---@meta

---@class CobaltCityhallExports
local CobaltCityhallExports = {}

---**Server.** The player's shift at a civilian job, or nil when they have none.
---@param src integer
---@return ShiftView?
function CobaltCityhallExports:GetShift(src) end

---**Server.** Ends the player's shift and clears their temp job; false when they had no shift.
---@param src integer
---@param reason? string shown to the player
---@return boolean
function CobaltCityhallExports:EndShift(src, reason) end

---**Client.** cobalt_inventory's use handler for the `hotdog_stand` item: on `usedItem`, starts placing the cart.
---@param event 'usingItem'|'usedItem'
function CobaltCityhallExports:UseHotdogStand(event) end
