-- FXLM (Film eXperience Look Manager) - Darktable Lua Plugin
-- Main initialization file

local dt = require "darktable"
local fxlm = {}

-- Load core modules
fxlm.ui = require "fxlm.ui"
fxlm.presets = require "fxlm.presets"
fxlm.recipes = require "fxlm.recipes"
fxlm.core = require "fxlm.core"

-- Plugin metadata
fxlm.name = "FXLM Film Looks"
fxlm.version = "0.1.0"
fxlm.author = "FXLM Project"
fxlm.description = "Create and manage film-inspired looks in Darktable"

-- Register the main module
function fxlm.register()
    -- Register the main UI panel
    dt.register_module(
        "fxlm",
        "FXLM Film Looks",
        fxlm.ui.show_panel
    )
    
    -- Register menu items
    dt.register_event(
        "main-ui",
        function()
            -- Add FXLM to the main menu
            dt.register_menu(
                "fxlm_menu",
                "FXLM Film Looks",
                "Open FXLM panel",
                function()
                    fxlm.ui.show_panel()
                end
            )
        end
    )
    
    -- Register keyboard shortcut
    dt.register_keyboard_shortcut(
        "fxlm_panel",
        "Show FXLM Panel",
        "f",
        function()
            fxlm.ui.show_panel()
        end
    )
    
    dt.print("FXLM Plugin loaded successfully!")
end

-- Initialize the plugin
fxlm.register()

return fxlm