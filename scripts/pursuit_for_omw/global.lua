local async = require("openmw.async")
local util = require("openmw.util")
local core = require("openmw.core")
local world = require("openmw.world")
local types = require("openmw.types")
local aux_util = require('openmw_aux.util')
local auxiliary = require('scripts.pursuit_for_omw.auxiliary')
local time = require("openmw_aux.time")
local storage = require('openmw.storage')
local General_Settings = storage.globalSection('Settings_Pursuit_Options_Key_KINDI')
local isCreature = types.Creature.objectIsInstance
local blackListedActors = {}
local pursuingActors = {}

local travelToTheDoor =
async:registerTimerCallback(
    "goToTheDoor",
    function(data)
        local actor, target = data.actor, data.target
        if not target:isValid() or not actor:isValid() then
            return
        end
        if #actor.cell:getAll(types.Player) > 0 then
            return
        end
        if types.Actor.stats.dynamic.health(target).current <= 0 then
            return
        end
        if actor.cell ~= target.cell then
            pursuingActors[#pursuingActors + 1] = actor
            actor:teleport(data.destCellName, data.destPos - util.vector3(0, 0, 50), data.destRot)
            actor:sendEvent("Pursuit_updateCell_eqnx", { prevCell = actor.cell.name, cellName = data.destCellName })
        end
    end
)

local function isBlacklisted(actor)
    if blackListedActors[actor.recordId] or blackListedActors[tostring(actor)] then
        return true
    end
    if not General_Settings:get('Creature Pursuit') and isCreature(actor) then
        return true
    end
end

--the possible values for this event data
--[1] the pursuing actor object
--[2] the target actor object of [1]
--[3] number in seconds to deduct to the time it takes to teleport (optional)
local function chaseCombatTarget(e)
    local actor, target, masa = table.unpack(e)
    local delay

    if not General_Settings:get('Mod Status') then
        return
    end

    if isBlacklisted(actor) then
        return
    end

    if not (target and actor) then
        return
    end
    if not (actor:isValid() and target:isValid()) then
        return
    end

    --local bestDoor = auxiliary.getBestDoor(actor, target.cell.name, target, nil, actor.cell:getAll(types.Door))
    local bestDoor = auxiliary.findNearestDoorToCell(actor.position, target.cell.name, actor.cell:getAll(types.Door))

    if not bestDoor then
        return
    end

    if storage.globalSection('Settings_Pursuit_Debug_Key_KINDI'):get('Debug') then
        target:sendEvent("Pursuit_Debug_Pursuer_Details_eqnx", { actor = actor, target = target })
    end

    if actor.type == types.NPC then
        delay = (actor.position - bestDoor.position):length() / types.Actor.runSpeed(actor)
    else
        delay = (actor.position - bestDoor.position):length() / (types.Actor.runSpeed(actor) * 8)
    end
    if masa and type(masa) == "number" then
        delay = delay - masa
    end
    if delay > math.abs(General_Settings:get('Pursue Time')) then
        --print(string.format("%s will not pursue further", actor))
        return
    end
    if delay < 0 then
        delay = 0.1
    end

    --print(string.format("%s : delay = %f", actor.recordId, delay))

    async:newSimulationTimer(
        delay,
        travelToTheDoor,
        {
            actor = actor,
            target = target,
            destCellName = types.Door.destCell(bestDoor).name,
            destPos = types.Door.destPosition(bestDoor),
            destRot = types.Door.destRotation(bestDoor),
        }
    )

    actor:sendEvent("Pursuit_returnInit_eqnx", { position = actor.position, cellName = actor.cell.name })
end

local function teleportPositionCellInstance(e)
    e[1]:teleport(e[2], e[3])
end

local function teleportToDoorDestInstant(data)
    local DOOR_OBJ, actor, aiPackageType, aiPackageTarget = table.unpack(data)
    local DOOR = types.Door
    local destCellName = DOOR.destCell(DOOR_OBJ).name
    local destPos = DOOR.destPosition(DOOR_OBJ)
    local destRot = DOOR.destRotation(DOOR_OBJ)

    if isBlacklisted(actor) then
        return
    end

    actor:teleport(destCellName, destPos - util.vector3(0, 0, 50), destRot)

    if aiPackageType then
        actor:sendEvent('StartAIPackage', { type = aiPackageType, target = aiPackageTarget })
    end
end

local function updateBlacklistedActors(data)
    blackListedActors[tostring(data[1])] = data[2]
end

time.runRepeatedly(function()
    if General_Settings:get('Actor Return') then
        for _, actor in pairs(pursuingActors) do
            actor:sendEvent("Pursuit_returnToOricellInstant_eqnx")
        end
        pursuingActors = {}
    end
end, time.day, {
    initialDelay = time.day - core.getGameTime() % time.day,
    type = time.GameTime,
})

return {
    engineHandlers = {
        onActorActive = function(actor)
            if core.API_REVISION < 29 then
                error('Pursuit mod requires a newer version of OpenMW, please update.')
            end
            if actor and (actor.type == types.NPC or actor.type == types.Creature) then
                actor:addScript("scripts/pursuit_for_omw/pursued.lua")
                actor:addScript("scripts/pursuit_for_omw/pursuer.lua")
            end
        end,
        onSave = function()
            return {pursuingActors = pursuingActors}
        end,
        onLoad = function(e)
            if e and e.pursuingActors then
                pursuingActors = e.pursuingActors
            end
        end
    },
    eventHandlers = {
        --sent from pursuer.lua / pursued.lua
        Pursuit_chaseCombatTarget_eqnx = chaseCombatTarget,

        --sent from pursuer.lua / door.lua(unused)
        Pursuit_teleportToDoorDestInstant_eqnx = teleportToDoorDestInstant,

        --sent from player.lua
        Pursuit_updateBlacklistedActors_eqnx = updateBlacklistedActors,

        --sent from return.lua
        Pursuit_teleportPositionCell_eqnx = teleportPositionCellInstance
    }
}
