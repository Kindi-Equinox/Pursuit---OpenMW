local core = require("openmw.core")
local self = require("openmw.self")
local ai = require('openmw.interfaces').AI
local types = require('openmw.types')
local canMove = types.Actor.canMove
local pursuers = {}
local masa = 0 --time between active and inactive state during pursuit

return {
    engineHandlers = {
        onActive = function()
            if not next(pursuers) then
                return
            end
            masa = core.getSimulationTime() - masa
            for pursuer in pairs(pursuers) do
                if canMove(self) and canMove(pursuer) then
                    core.sendGlobalEvent("Pursuit_chaseCombatTarget_eqnx", {pursuer, self, masa})
                end
            end
            pursuers = {}
            masa = 0
        end,
        onInactive = function()
            masa = core.getSimulationTime()
        end
    },
    eventHandlers = {
        --sent from pursuer.lua
        Pursuit_pursuerData_eqnx = function(data)
            pursuers[data] = true
        end,
    }
}
