local core = require('openmw.core')
local async = require('openmw.async')
local input = require('openmw.input')
local ui = require('openmw.ui')
local camera = require('openmw.camera')
local util = require('openmw.util')
local nearby = require('openmw.nearby')
local self = require('openmw.self')
local storage = require('openmw.storage')
local time = require('openmw_aux.time')
local aux = require('scripts.pursuit_for_omw.auxiliary')
local I = require('openmw.interfaces')
local getL = core.l10n("pursuit_for_omw")
local hotkeySetting = storage.globalSection('Settings_Pursuit_Blacklist_Key_KINDI')
local function messageBox(_, ...) ui.showMessage(tostring(_):format(...)) end

local BL = {}
local BL_LIST = nil -- blacklist menu element
local BL_ACTOR_LIST = {} -- array of blacklisted actor objects
local CURSOR_INDEX = 1
local CURRENT_PAGE = 1
local MAX_ROWS = 18 -- max lines to show in menu
local NAVIGATION_DELAY = 0.05
local PIXEL = 24 -- for image and interval
local BL_PAGE = {}
local lastActionID = nil
local controlsDisabled = false
local deleteList = {}
local masa = 0
local navigationKeys = {
    [input.ACTION.MoveForward] = {
        name = 'navigation_key_info_up',
        icon = 'textures/menu_scroll_up.dds',
        text = "Up"},
    [input.ACTION.MoveBackward] = {
        name = 'navigation_key_info_down',
        icon = 'textures/menu_scroll_down.dds',
        text = "Down"
    },
    [input.ACTION.ToggleSpell] = {
        name = 'navigation_key_info_remo',
        icon = 'Icons/a/Tx_Wolf2_Gauntlet.dds',
        text = "Remo"
    },
    [input.ACTION.MoveRight] = {
        name = 'navigation_key_info_next',
        icon = 'textures/menu_scroll_right.dds',
        text = "Next"
    },
    [input.ACTION.MoveLeft] = {
        name = 'navigation_key_info_prev',
        icon = 'textures/menu_scroll_left.dds',
        text = "Prev"
    }
}

-- or maybe just set visible to false?
local function destroyMenu()
    if BL_LIST then
        BL_LIST:destroy()
        BL_LIST = nil
    end
end

local function updateMenu()
    local i = 1
    while i <= #BL_ACTOR_LIST do
        local text = tostring(BL_ACTOR_LIST[i])
        if deleteList[text] then
            core.sendGlobalEvent('Pursuit_updateBlacklistedActors_eqnx', {BL_ACTOR_LIST[i], nil})
            table.remove(BL_ACTOR_LIST, i)
        else
            i = i + 1
        end
    end

    -- if current page is empty set to previous page
    while CURRENT_PAGE > math.ceil(#BL_ACTOR_LIST / MAX_ROWS) and CURRENT_PAGE > 1 do
        CURRENT_PAGE = CURRENT_PAGE - 1
    end

    --if current cursor points to invalid location set to previous cursor
    while CURSOR_INDEX > #BL_ACTOR_LIST % MAX_ROWS and CURSOR_INDEX > 1 do
        CURSOR_INDEX = CURSOR_INDEX - 1
    end

    deleteList = {}
end

local function getTarget()
    local CAMERA_POS = camera.getPosition()
    local VIEWPORT_WORLD_VECTOR = camera.viewportToWorldVector(util.vector2(0.5, 0.5))
    local VIEW_DISTANCE = camera.getViewDistance()
    local RAY_RESULT = nearby.castRay(CAMERA_POS, CAMERA_POS + VIEWPORT_WORLD_VECTOR * VIEW_DISTANCE,
                                      {collisionType = nearby.COLLISION_TYPE.Actor, ignore = self})
    return RAY_RESULT.hitObject
end

-- TODO
-- store objects as keys instead of value
-- remove tostring usage
local function addRemoveShow_Blacklist(e, T)
    local openList_hk = hotkeySetting:get("List Hotkey")
    local blackList_hk = hotkeySetting:get("Add-To-Blacklist Hotkey")
    local whiteList_hk = hotkeySetting:get("Remove-From-Blacklist Hotkey")

    if e.code == tonumber(blackList_hk) and T then
        core.sendGlobalEvent('Pursuit_updateBlacklistedActors_eqnx', {T, true})
        if not aux.find(BL_ACTOR_LIST, T) then BL_ACTOR_LIST[#BL_ACTOR_LIST + 1] = T end
        messageBox("%s added to pursuit blacklist", T)
    elseif e.code == tonumber(whiteList_hk) and T then
        core.sendGlobalEvent('Pursuit_updateBlacklistedActors_eqnx', {T, nil})
        aux.remove(BL_ACTOR_LIST, T)
        messageBox("%s removed from pursuit blacklist", T)
    elseif e.code == tonumber(openList_hk) then
        -- show list of blacklisted actors
        if BL_LIST then
            destroyMenu()
            updateMenu()
        else
            BL.showBlacklist()
        end
    end
end

local createNewContent = function(name)
    return {
        name = name,
        type = ui.TYPE.Flex,
        props = {horizontal = true, align = ui.ALIGNMENT.Center, arrange = ui.ALIGNMENT.Center, alpha = 1},
        content = ui.content {}
    }
end

local createNewImage = function(name, texturePath, offset)
    return {
        name = name,
        type = ui.TYPE.Image,
        props = {
            resource = ui.texture {path = texturePath, offset = offset or util.vector2(-6, -6)},
            size = util.vector2(PIXEL, PIXEL),
            visible = false,
            autoSize = false
        }
    }
end

local createNewText = function(name, text, callback)
    return {
        name = name,
        type = ui.TYPE.Text,
        template = I.MWUI.templates.textNormal,
        props = {
            text = tostring(text),
            textSize = 16,
            textAlignH = ui.ALIGNMENT.Center,
            textAlignV = ui.ALIGNMENT.Center
        },
        events = {mouseClick = async:callback(callback or function() end)}
    }
end

local createNewButton = function(name, text, callback, path, offset)
    -- local buttonText = createNewText(name, text, callback)
    local image = createNewImage(name, path, offset)
    image.props.visible = true

    local buttonBlock = createNewContent("")
    local buttonBorder = {
        name = "nil",
        template = I.MWUI.templates.interval,
        props = {size = util.vector2(PIXEL, 0)},
        content = ui.content {}
    }
    buttonBlock.content:add(buttonBorder)
    buttonBlock.content:add({
        name = name,
        template = I.MWUI.templates.boxThick,
        props = {horizontal = true, align = ui.ALIGNMENT.Center, arrange = ui.ALIGNMENT.Center, alpha = 1},
        events = {mouseClick = async:callback(callback)},
        content = ui.content {{template = I.MWUI.templates.padding, content = ui.content {image}}}
    })
    buttonBlock.content:add(buttonBorder)

    return buttonBlock
end

BL.updateHeader = function()
    aux.findChild(BL_LIST.layout, "blackListed_header_text").props.text =
        string.format("%s [%s/%s]", getL("blackListed_header_text"), math.min(CURRENT_PAGE * MAX_ROWS, #BL_ACTOR_LIST),
                      #BL_ACTOR_LIST)
end

BL.showBlacklist = function()
    -- element
    BL_LIST = ui.create {
        name = "BL_LIST",
        template = I.MWUI.templates.boxTransparent,
        layer = 'Windows',
        props = {relativePosition = util.vector2(.5, .5), anchor = util.vector2(.5, .5), alpha = 1},
        content = ui.content {}
    }

    local mainBlock = createNewContent("mainBlock")
    mainBlock.props.horizontal = false

    local blackListed_header_block = createNewContent("blackListed_header")
    blackListed_header_block.props.size = util.vector2(0, 50)
    blackListed_header_block.content:add(createNewText("blackListed_header_text",
                                                       string.format("%s [%s/%s]", getL("blackListed_header_text"),
                                                                     math.min(CURRENT_PAGE * MAX_ROWS, #BL_ACTOR_LIST),
                                                                     #BL_ACTOR_LIST)))

    BL_PAGE = {}
    for n = 1, math.ceil(math.max(1, #BL_ACTOR_LIST / MAX_ROWS)) do
        local block_for_list = createNewContent("PAGE_" .. n)
        block_for_list.props.size = util.vector2(512, 256)
        block_for_list.props.anchor = util.vector2(.5, .5)
        block_for_list.props.relativeSize = util.vector2(.5, .5)
        block_for_list.props.position = util.vector2(.5, .5)
        block_for_list.props.align = ui.ALIGNMENT.Start
        block_for_list.props.arrange = ui.ALIGNMENT.Start
        block_for_list.props.horizontal = false
        block_for_list.template = I.MWUI.templates.bordersThick

        for i = 1, MAX_ROWS do
            local actorID = BL_ACTOR_LIST[(n - 1) * MAX_ROWS + i]
            if not actorID then break end
            local row_block = createNewContent("ROW_" .. i)
            row_block.props.size = util.vector2(128, 0)
            row_block.props.align = ui.ALIGNMENT.Start
            row_block.props.arrange = ui.ALIGNMENT.Start
            row_block.props.horizontal = true
            row_block.props.userData = actorID
            block_for_list.content:add(row_block)

            -- cursor block
            local cursor_block = createNewContent("CURSOR_" .. i)
            cursor_block.props.size = util.vector2(64, 0)
            cursor_block.props.align = ui.ALIGNMENT.Center
            cursor_block.props.arrange = ui.ALIGNMENT.Center
            cursor_block.props.horizontal = false
            cursor_block.content:add(createNewImage("pointerArrow_image_" .. i, 'textures/menu_scroll_right.dds'))
            row_block.content:add(cursor_block)
            ----------------------------------------

            -- ids block
            local idNames_block = createNewContent(tostring(actorID))
            idNames_block.props.size = util.vector2(64, 0)
            idNames_block.props.align = ui.ALIGNMENT.Start
            idNames_block.props.arrange = ui.ALIGNMENT.Start
            idNames_block.props.horizontal = false
            if require("scripts.pursuit_for_omw.blacklist")[actorID] then
                actorID = string.format("[%s]", actorID)
            else
                actorID = tostring(actorID)
            end

            local blacklisted_actorId = createNewText("idNames_" .. i, actorID,
                                                      function()
                BL.menuNavigation(input.ACTION.ToggleSpell, i)
            end)
            blacklisted_actorId.props.userData = {object = BL_ACTOR_LIST[(n - 1) * MAX_ROWS + i], delete = false}
            idNames_block.content:add(blacklisted_actorId, i)
            row_block.content:add(idNames_block)
            ------------------------------------------

            if i == CURSOR_INDEX and n == CURRENT_PAGE then
                cursor_block.content[1].props.visible = true
                idNames_block.content[1].props.textColor = ui.CONSOLE_COLOR.Info
            end
        end
        table.insert(BL_PAGE, block_for_list)
    end

    local button_block = createNewContent("navigation_key_info_block")
    button_block.props.size = util.vector2(300, 100)
    for inp, button in pairs(navigationKeys) do
        button_block.content:add(createNewButton(button.name, button.text, function()
            messageBox(inp)
            BL.menuNavigation(inp)
        end, button.icon))
    end

    mainBlock.content:add(blackListed_header_block)
    mainBlock.content:add(BL_PAGE[CURRENT_PAGE] or {})
    mainBlock.content:add(button_block)
    BL_LIST.layout.content:add(mainBlock)

    BL_LIST:update()
end

BL.menuNavigation = function(actionID, i)

    if not navigationKeys[actionID] then return end

    local last_CURSOR_INDEX = CURSOR_INDEX
    local last_CURRENT_PAGE = CURRENT_PAGE
    CURSOR_INDEX = i or CURSOR_INDEX -- i comes from ui event
    
    if actionID == input.ACTION.MoveForward then
        if CURSOR_INDEX <= 1 then
            CURSOR_INDEX = 1
            return
        end
        CURSOR_INDEX = CURSOR_INDEX - 1
    elseif actionID == input.ACTION.MoveBackward then
        if CURSOR_INDEX >= #BL_PAGE[CURRENT_PAGE].content then return end
        CURSOR_INDEX = CURSOR_INDEX + 1
    elseif actionID == input.ACTION.MoveRight then
        if CURRENT_PAGE >= #BL_PAGE then
            CURRENT_PAGE = #BL_PAGE
            return
        end
        local mainBlock = aux.findChild(BL_LIST.layout, 'mainBlock')
        mainBlock.content["PAGE_" .. CURRENT_PAGE] = BL_PAGE[CURRENT_PAGE + 1]
        CURRENT_PAGE = CURRENT_PAGE + 1
        if CURSOR_INDEX > #BL_PAGE[CURRENT_PAGE].content then CURSOR_INDEX = #BL_PAGE[CURRENT_PAGE].content end
    elseif actionID == input.ACTION.MoveLeft then
        if CURRENT_PAGE <= 1 then
            CURRENT_PAGE = 1
            return
        end
        local mainBlock = aux.findChild(BL_LIST.layout, 'mainBlock')
        mainBlock.content["PAGE_" .. CURRENT_PAGE] = BL_PAGE[CURRENT_PAGE - 1]
        CURRENT_PAGE = CURRENT_PAGE - 1
        if CURSOR_INDEX > #BL_PAGE[CURRENT_PAGE].content then CURSOR_INDEX = #BL_PAGE[CURRENT_PAGE].content end
    elseif actionID == input.ACTION.ToggleSpell then
        local textLayout = aux.findChild(BL_PAGE[CURRENT_PAGE], "idNames_" .. CURSOR_INDEX)
        local text = textLayout.props.text
        local actorID = textLayout.props.userData.object

        -- cannot delete if from file
        if require("scripts.pursuit_for_omw.blacklist")[text:gsub('[%[%]]', '')] then
            messageBox("?!")
        else
            if textLayout.props.userData.delete then
                textLayout.props.text = text:gsub(' %[Delete%]', '')
                textLayout.props.userData.delete = false
                deleteList[tostring(actorID)] = nil
            else
                textLayout.props.text = text .. ' [Delete]'
                textLayout.props.userData.delete = true
                deleteList[tostring(actorID)] = true
            end
        end

        --otherwise too fast
        masa = -NAVIGATION_DELAY
    end

    aux.findChild(BL_PAGE[last_CURRENT_PAGE], "pointerArrow_image_" .. last_CURSOR_INDEX).props.visible = false
    aux.findChild(BL_PAGE[last_CURRENT_PAGE], "idNames_" .. last_CURSOR_INDEX).props.textColor = nil

    aux.findChild(BL_PAGE[CURRENT_PAGE], "pointerArrow_image_" .. CURSOR_INDEX).props.visible = true
    aux.findChild(BL_PAGE[CURRENT_PAGE], "idNames_" .. CURSOR_INDEX).props.textColor = ui.CONSOLE_COLOR.Info

    BL.updateHeader()
    BL_LIST:update()

end

-- replace with proper menumode function later to disable controls
time.runRepeatedly(function()
    if BL_LIST and controlsDisabled == false then
        input.setControlSwitch(input.CONTROL_SWITCH.Controls, false)
        controlsDisabled = true
    elseif not BL_LIST and controlsDisabled == true then
        input.setControlSwitch(input.CONTROL_SWITCH.Controls, true)
        controlsDisabled = false
    end
end, 0.1)

return {
    engineHandlers = {
        onFrame = function(dt)
            if not lastActionID then return end

            if masa > NAVIGATION_DELAY then
                masa = 0
            else
                masa = masa + dt
                return
            end

            if input.isActionPressed(lastActionID) and BL_LIST then
                BL.menuNavigation(lastActionID)
            else
                lastActionID = nil
            end
        end,
        onInputAction = function(actionID) if BL_LIST then lastActionID = actionID end end,
        onKeyPress = function(e)
            --[[if e.symbol == 'i' then
                for k, v in pairs(nearby.actors) do
                    if not aux.find(BL_ACTOR_LIST, v) then
                        table.insert(BL_ACTOR_LIST, v)
                        core.sendGlobalEvent('Pursuit_updateBlacklistedActors_eqnx', {v, true})
                    end
                end
            end]]
            if not e.withShift or not hotkeySetting:get('BlackList Pursuit') then return end
            addRemoveShow_Blacklist(e, getTarget())
        end,
        onLoad = function(savedData)
            BL_ACTOR_LIST = {}
            for _ in pairs(require("scripts.pursuit_for_omw.blacklist")) do
                table.insert(BL_ACTOR_LIST, _)
                core.sendGlobalEvent('Pursuit_updateBlacklistedActors_eqnx', {_, true})
            end
            if savedData.blackListActors then
                for k, v in pairs(savedData.blackListActors) do
                    if not aux.find(BL_ACTOR_LIST, v) then
                        table.insert(BL_ACTOR_LIST, v)
                        core.sendGlobalEvent('Pursuit_updateBlacklistedActors_eqnx', {v, true})
                    end
                end
            end
        end,
        onSave = function() return {blackListActors = BL_ACTOR_LIST} end,
        onActive = function() self:sendEvent("Pursuit_IsInstalled_eqnx", {isInstalled = true}) end
    },
    eventHandlers = {
        Pursuit_Debug_Pursuer_Details_eqnx = function(e)
            messageBox("%s chases %s from %s to %s", e.actor, e.target, e.actor.cell.name, e.target.cell.name)
        end
    }
}
