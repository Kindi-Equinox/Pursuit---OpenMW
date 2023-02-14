local core = require("openmw.core")
local self = require("openmw.self")
local types = require('openmw.types')
local nearby = require("openmw.nearby")

local isActor = types.Actor.objectIsInstance
local isPlayer = types.Player.objectIsInstance
local DOOR = types.Door

return {
    engineHandlers = {
        onActivated = function(actor)
            if actor.type == types.Player then
                if DOOR.isTeleport(self) and (DOOR.destCell(self) == actor.cell) then
                    for _, nearbyActor in pairs(nearby.actors) do
                        if not isPlayer(nearbyActor) and isActor(nearbyActor) and (actor ~= nearbyActor) then
                            nearbyActor:sendEvent("Pursuit_teleportDoorButSameCell_eqnx",
                                { activatedDoor = self, activatingActor = actor })
                        end
                    end
                end
            else --expected call from pursuer.lua -> self:activateBy(pursuer)
                --currently not used
                --core.sendGlobalEvent("Pursuit_teleportToDoorDestInstant_eqnx", { self, actor })
            end
        end

    }

}
