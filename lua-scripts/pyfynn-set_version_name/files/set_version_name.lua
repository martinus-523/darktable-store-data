-- set_version_name.lua
-- Darktable 5.2.1: side panel module with entry + apply button
local dt = require "darktable"
local MODULE = "fynn_set_version_name"

-- Cleanup on reload
pcall(function() dt.destroy_event(MODULE .. "_sel", "selection-changed") end)

-- Entry field
local entry = dt.new_widget("entry"){
    text = "",
    tooltip = "Enter version name here"
}

-- Button to apply version name to selection
local apply_button = dt.new_widget("button"){
    label = "Apply to selection",
    clicked_callback = function(self)
    local sel = dt.gui.selection()
    if not sel or #sel == 0 then
        dt.print("No images selected.")
        return
        end
        local name = entry.text or ""
        for _, img in ipairs(sel) do
            img.version_name = name
            end
            dt.print("Set version name to: \"" .. name .. "\" for " .. tostring(#sel) .. " image(s)")
            end
}

-- Layout box
local container = dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){ label = "Version name:" },
    entry,
    apply_button
}

-- Keep entry in sync with first selected image
local function selection_changed(event)
local sel = dt.gui.selection()
if sel and #sel > 0 then
    entry.text = sel[1].version_name or ""
    else
        entry.text = ""
        end
        end
        dt.register_event(MODULE .. "_sel", "selection-changed", selection_changed)

        -- Register dockable module in right panel of lighttable
        dt.register_lib(
            MODULE,
            "Set version name",   -- module title
            true,                 -- expandable
            false,                -- resettable
            {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},
            container
        )

        -- Initialize entry once
        selection_changed()
