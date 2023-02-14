local I = require('openmw.interfaces')
local input = require('openmw.input')
local async = require('openmw.async')
local ui = require('openmw.ui')


local function paddedBox(layout)
    return {
        template = I.MWUI.templates.box,
        content = ui.content {
            {
                template = I.MWUI.templates.padding,
                content = ui.content { layout },
            },
        }
    }

end

I.Settings.registerRenderer(
    'Pursuit_hotkey', function(value, set)
    return paddedBox {
        template = I.MWUI.templates.textEditLine,
        props = {
            text = tostring(value and input.getKeyName(value) or ''),
        },
        events = {
            keyPress = async:callback(function(e)
                set(e.code)
            end)
        }
    }
end
)

I.Settings.registerPage {
    key = 'Pursuit_KINDI',
    l10n = 'pursuit_for_omw',
    name = 'settings_modName',
    description = 'settings_modDesc'
}
