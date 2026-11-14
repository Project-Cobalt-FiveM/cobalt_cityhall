local Cart <const> = require 'client.hotdog.cart'

---@type ClientJobKind
return {
    enter = function(def)
        Cart.enter(def.stand --[[@as StandConfig]])
    end,
    update = function() end,
    leave = Cart.leave,
}
