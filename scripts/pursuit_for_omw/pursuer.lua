local self = require("openmw.self")
local time = require("openmw_aux.time")
local nearby = require("openmw.nearby")
local core = require("openmw.core")
local ai = require("openmw.interfaces").AI
local types = require("openmw.types")
local util = require("openmw.util")
local async = require("openmw.async")
local storage = require('openmw.storage')
local General_Settings = storage.globalSection('Settings_Pursuit_Options_Key_KINDI')
local vector2 = util.vector2
local getHealth = types.Actor.stats.dynamic.health
local pursueTarget
local nearestPursuitDoor
local lastAIPackage
local masa = math.huge

if self.type == types.Player then
    return
end

local function scanIfPursuing()
    async:newUnsavableSimulationTimer(math.random() * 0.3, scanIfPursuing)

    if not (ai.getActiveTarget("Combat") or ai.getActiveTarget("Pursue")) then
        pursueTarget = nil
        return
    end

    pursueTarget = ai.getActivePackage().target

    if getHealth(pursueTarget).current <= 0 then
        return
    end

    --players are handled in onInactive handler
    if pursueTarget.type ~= types.Player then
        pursueTarget:sendEvent("Pursuit_pursuerData_eqnx", self)
    end
end

local function scanIfNearPursuitDoor()
    if nearestPursuitDoor then
        local doorPos = vector2(nearestPursuitDoor.position.x, nearestPursuitDoor.position.y)
        local selfPos = vector2(self.position.x, self.position.y)
        local dist = (doorPos - selfPos):length()

        self.controls.run = true

        if dist < 155 then
            --maybe unnecessary
            ai.startPackage { type = 'Wander' }

            --see door.lua
            --nearestPursuitDoor:activateBy(self)
            
            core.sendGlobalEvent("Pursuit_teleportToDoorDestInstant_eqnx",
                { nearestPursuitDoor, self, lastAIPackage and lastAIPackage.type, lastAIPackage and lastAIPackage.target })

            masa = math.huge
            self.controls.run = false
            nearestPursuitDoor = nil
        end
    end

    if core.getSimulationTime() - masa > math.abs(General_Settings:get('Pursue Time')) then
        masa = math.huge
        self.controls.run = false
        nearestPursuitDoor = nil
        ai.startPackage { type = 'Wander', distance = 2048 }
    end

    async:newUnsavableSimulationTimer(math.random() * 0.4, scanIfNearPursuitDoor)
end

scanIfPursuing()
scanIfNearPursuitDoor()

return {
    engineHandlers = {
        onInactive = function()
            if not types.Actor.canMove(self) then
                return
            end
            if not pursueTarget or (pursueTarget.type ~= types.Player) then
                return
            end
            core.sendGlobalEvent("Pursuit_chaseCombatTarget_eqnx", { self, pursueTarget })
        end,
        onLoad = function(savedData)
            if savedData then
                nearestPursuitDoor = savedData.nearestPursuitDoor
            end
        end,
        onSave = function()
            return {nearestPursuitDoor = nearestPursuitDoor}
        end
    },
    eventHandlers = {
        --sent from door.lua
        Pursuit_teleportDoorButSameCell_eqnx = function(e)
            if (pursueTarget == e.activatingActor) and (e.activatedDoor.cell == self.cell) then
                lastAIPackage = ai.getActivePackage()
                nearestPursuitDoor = e.activatedDoor
                ai.startPackage { type = 'Travel', destPosition = nearestPursuitDoor.position }
                masa = core.getSimulationTime()
            end
        end
    }
}
