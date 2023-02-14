local self = require("openmw.self")
local ai = require("openmw.interfaces").AI
local types = require("openmw.types")
local time = require("openmw_aux.time")
local aux_util = require("openmw_aux.util")
local nearby = require("openmw.nearby")
local core = require("openmw.core")
local util = require("openmw.util")
local aux = require('scripts.pursuit_for_omw.auxiliary')
local storage = require('openmw.storage')
local General_Settings = storage.globalSection('Settings_Pursuit_Options_Key_KINDI')
local async = require("openmw.async")

local myActiveTarget = ai.getActiveTarget

local oripos
local oricell

local function hasFollowEscortPackage(target)
    local following = false
    ai.forEachPackage(function(package)
        local pkgType = package.type
        local correctTarget = target == nil or target == package.target
        local follow_or_escort = pkgType == "Follow" or pkgType == "Escort"
        if follow_or_escort and correctTarget then
            following = true
            return
        end
    end)
    return following
end

local function isAggro()
    return myActiveTarget("Combat") or myActiveTarget("Pursue") == "Pursue"
end

local clearMethod = {
    __index = function(t, k, v)
        if k == "clear" then
            return function(this)
                for _ in pairs(this) do
                    this[_] = nil
                end
                this[#this + 1] = oricell
                if not isAggro() then
                    self:sendEvent("StartAIPackage", {
                        type = "Wander",
                        distance = 2048
                    })
                end
            end
        end
    end
}

local cellsTraversed = setmetatable({}, clearMethod)

local function return_back()

    async:newUnsavableSimulationTimer(math.random() + 0.5, return_back)

    if not General_Settings:get('Actor Return') then
        cellsTraversed:clear()
        return
    end

    if not (oripos and oricell) then
        return
    end

    if not isAggro() and not hasFollowEscortPackage() then
        if self.cell.name == oricell then
            ai.startPackage { type = "Travel", destPosition = oripos }
            if (oripos - self.position):length() < 500 then
                self:sendEvent("StartAIPackage", {
                    type = "Wander",
                    distance = 2048
                })
            end
            oricell = nil
            oripos = nil
            cellsTraversed:clear()
        else
            local nearestDoor
            for _, cellName in ipairs(cellsTraversed) do
                nearestDoor = aux.findNearestDoorToCell(self.position, cellName)
                if nearestDoor then
                    break
                end
            end
            if nearestDoor == nil then
                return
            end
            ai.startPackage { type = "Travel", destPosition = nearestDoor.position }

            local selfposV2 = util.vector2(self.position.x, self.position.y)
            local doorposV2 = util.vector2(nearestDoor.position.x, nearestDoor.position.y)
            local distV2 = (selfposV2 - doorposV2):length()

            if distV2 < 100
            then
                -- NPC cannot use teleport doors, but this plays the "open door" sound (waiting for proper sound API)
                nearestDoor:activateBy(self)
                core.sendGlobalEvent("Pursuit_teleportToDoorDestInstant_eqnx", { nearestDoor, self })
            end
        end
    end
end

return_back()

return {
    engineHandlers = {
        onSave = function()
            return { oripos = oripos, oricell = oricell, cellsTraversed = cellsTraversed }
        end,
        onLoad = function(e)
            if e then
                oripos = e.oripos
                oricell = e.oricell
                cellsTraversed = e.cellsTraversed
                setmetatable(cellsTraversed, clearMethod)
            end
        end,
    },
    eventHandlers = {
        Pursuit_returnInit_eqnx = function(e)
            if not oripos and not oricell and not hasFollowEscortPackage() then
                oripos, oricell = e.position, e.cellName
            end
        end,
        Pursuit_updateCell_eqnx = function(e)
            cellsTraversed[#cellsTraversed + 1] = e.prevCell
            cellsTraversed[#cellsTraversed + 1] = e.cellName
        end,
        Pursuit_returnToOricellInstant_eqnx = function()
            if oripos and oricell and not isAggro() and not hasFollowEscortPackage() then
                core.sendGlobalEvent("Pursuit_teleportPositionCell_eqnx", { self, oricell, oripos })
                oricell = nil
                oripos = nil
                cellsTraversed:clear()
                self:sendEvent("StartAIPackage", {
                    type = "Wander",
                    distance = 2048
                })
            end
        end
    }
}
