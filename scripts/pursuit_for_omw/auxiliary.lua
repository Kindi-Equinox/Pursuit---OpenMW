local types = require("openmw.types")
local aux_util = require("openmw_aux.util")
local core = require("openmw.core")
local time = require('openmw_aux.time')

local this = {}
this.include = function(moduleName)
	local status, result = pcall(require, moduleName)
	if (status) then
		return result
	end
end

this.find = function(t, v)
    for _, val in pairs(t) do
        if val == v then
            return _
        end
    end
end

this.remove = function(t, v)
    local i = this.find(t, v)
    if (i ~= nil) then
        table.remove(t, i)
        return true
    end
    return false
end

this.filterToUnique = function(t)
    local seen = {}
    local result = {}
    for _, value in ipairs(t) do
        if not seen[value] then
            table.insert(result, value)
            seen[value] = true
        end
    end
    return result
end

this.getDaysPassed = function()
    --same as mw global dayspassed
    return core.getGameTime() / time.day --86400 seconds
end

--should replace with native omw-lua funcs
this.findChild = function(element, id)
    for k, v in pairs(element.content) do
        if v.name == id then
            return v
        end
        if v.content then
          local found = this.findChild(v, id)
          if found then
            return found
          end
        end
      end
end

--should replace with native omw-lua funcs
this.traverse = function(t)
    local function traverse(t)
        for k, v in pairs(t) do
            local success = pcall(next, v)
            if success then
                traverse(v)
            else
                coroutine.yield(k, v)
            end
        end
    end
    return coroutine.wrap(function() traverse(t) end)
end

this.findNearestDoorToCell = function(pos, cell, doors)
    local nearby = this.include("openmw.nearby")
    local nearbyDoors = nearby and nearby.doors or doors

    local DOOR = types.Door
    local possibleDoors =
    aux_util.mapFilter(
        nearbyDoors,
        function(door)
            return (DOOR.isTeleport(door) and DOOR.destCell(door).name == cell)
        end
    )
    return aux_util.findMinScore(
        possibleDoors,
        function(door)
            return (pos - door.position):length()
        end
    )
end

--find nearest door to the target
--accounts current target distance to the door destination
--i.e if there are multiple doors leading to a cell, find the door that is nearest to the target (on the other side)
--DEPRECATED. KEPT FOR REFS
--[[this.getBestDoor = function(actor, cell, target, position, doors)
    local bestDoor

    doors =
    aux_util.mapFilter(
        doors,
        function(door)
            return (types.Door.isTeleport(door) and types.Door.destCell(door).name == cell)
        end
    )

    if not target then
        target = { position = position }
        bestDoor =
        aux_util.findMinScore(
            doors,
            function(door)
                return (actor.position - door.position):length()
            end
        )
    else
        bestDoor =
        aux_util.findMinScore(
            doors,
            function(door)
                return ((actor.position - door.position):length() +
                    (target.position - types.Door.destPosition(door)):length())
            end
        )
    end

    return bestDoor
end]]

return this
