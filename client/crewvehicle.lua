local CrewVehicle <const> = {}

---@type table<integer, true>
local crew <const> = {}

---@param view ShiftView?
function CrewVehicle.track(view)
    table.wipe(crew)

    for _, member in ipairs(view?.crew or {}) do crew[member.id] = true end
end

---@param entity integer
---@return boolean
function CrewVehicle.is(entity)
    local owner <const> = Entity(entity).state['cobalt_cityhall:owner']

    return owner ~= nil and crew[owner] == true
end

return CrewVehicle
