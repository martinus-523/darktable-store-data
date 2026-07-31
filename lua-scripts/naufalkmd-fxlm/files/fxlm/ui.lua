-- FXLM UI Module
-- Implements the Progressive Skill Tiers UI

local dt = require "darktable"
local ui = {}

-- Current UI state
ui.current_tier = 1
ui.selected_preset = "Soft Portrait"
ui.intensity = 80
ui.show_expert = false

-- Preset definitions (based on the mockup)
ui.presets = {
    {
        name = "Soft Portrait",
        description = "Gentle skin tones with soft contrast",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.1, saturation = 0.9 },
            color_balance_rgb = { saturation = 0.85, warmth = 0.1 },
            grain = { amount = 0.1, size = 0.5 },
            vignette = { amount = 0.1 }
        }
    },
    {
        name = "Vintage Warm",
        description = "Warm, aged film look",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.2, saturation = 0.8 },
            color_balance_rgb = { saturation = 0.7, warmth = 0.3 },
            grain = { amount = 0.2, size = 0.7 },
            vignette = { amount = 0.15 }
        }
    },
    {
        name = "Cinematic Cool",
        description = "Cool, dramatic film look",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.3, saturation = 0.9 },
            color_balance_rgb = { saturation = 0.85, warmth = -0.1 },
            grain = { amount = 0.15, size = 0.6 },
            vignette = { amount = 0.2 }
        }
    },
    {
        name = "Soft Chrome",
        description = "Smooth metallic tones",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.0, saturation = 0.7 },
            color_balance_rgb = { saturation = 0.6, warmth = 0.0 },
            grain = { amount = 0.05, size = 0.4 },
            vignette = { amount = 0.05 }
        }
    },
    {
        name = "Desert Warm",
        description = "Warm, sandy tones",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.15, saturation = 0.85 },
            color_balance_rgb = { saturation = 0.75, warmth = 0.25 },
            grain = { amount = 0.12, size = 0.55 },
            vignette = { amount = 0.1 }
        }
    },
    {
        name = "Neon Nights",
        description = "Vibrant night scene look",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.4, saturation = 1.1 },
            color_balance_rgb = { saturation = 1.0, warmth = 0.0 },
            grain = { amount = 0.08, size = 0.5 },
            vignette = { amount = 0.25 }
        }
    },
    {
        name = "Faded Memories",
        description = "Soft, faded vintage look",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 0.9, saturation = 0.6 },
            color_balance_rgb = { saturation = 0.5, warmth = 0.15 },
            grain = { amount = 0.18, size = 0.65 },
            vignette = { amount = 0.12 }
        }
    },
    {
        name = "High Contrast B&W",
        description = "Dramatic black and white",
        icon = "🎞",
        parameters = {
            filmic_rgb = { contrast = 1.5, saturation = 0.0 },
            color_balance_rgb = { saturation = 0.0, warmth = 0.0 },
            grain = { amount = 0.25, size = 0.7 },
            vignette = { amount = 0.3 }
        }
    }
}

-- Show the main panel
function ui.show_panel()
    if ui.panel_window then
        ui.panel_window:show()
        return
    end
    
    -- Create the main window
    ui.panel_window = dt.new_widget("window") {
        title = "FXLM Film Looks",
        width = 600,
        height = 400,
        resizable = true,
        ui.create_tier1_ui()
    }
    
    ui.panel_window:show()
end

-- Create Tier 1 UI (One-click looks)
function ui.create_tier1_ui()
    local preset_dropdown = dt.new_widget("dropdown") {
        items = ui.get_preset_names(),
        value = ui.selected_preset,
        changed_callback = function(self)
            ui.selected_preset = self.value
            ui.update_preview()
        end
    }
    
    local intensity_slider = dt.new_widget("slider") {
        label = "Intensity",
        min = 0,
        max = 100,
        step = 1,
        value = ui.intensity,
        changed_callback = function(self)
            ui.intensity = self.value
            ui.update_preview()
        end
    }
    
    local import_button = dt.new_widget("button") {
        label = "📥 Import Recipe →",
        clicked_callback = function()
            ui.show_import_wizard()
        end
    }
    
    local randomize_button = dt.new_widget("button") {
        label = "🎲 Randomize",
        clicked_callback = function()
            ui.randomize_preset()
        end
    }
    
    local save_button = dt.new_widget("button") {
        label = "💾 Save Look",
        clicked_callback = function()
            ui.save_current_look()
        end
    }
    
    local expert_button = dt.new_widget("button") {
        label = "🔒 Expert →",
        clicked_callback = function()
            ui.show_expert_ui()
        end
    }
    
    local preview_text = dt.new_widget("label") {
        label = "💡 Tip: Drag Intensity to make the effect stronger or more subtle.",
        wrap = true
    }
    
    local preset_info = dt.new_widget("label") {
        label = "Selected: " .. ui.selected_preset,
        wrap = true
    }
    
    -- Main layout
    local main_box = dt.new_widget("box") {
        orientation = "vertical",
        spacing = 10,
        dt.new_widget("label") {
            label = "🎞 FXLM Film Looks",
            halign = "center"
        },
        dt.new_widget("box") {
            orientation = "horizontal",
            spacing = 5,
            dt.new_widget("label") { label = "Preset:" },
            preset_dropdown
        },
        intensity_slider,
        dt.new_widget("box") {
            orientation = "horizontal",
            spacing = 5,
            import_button,
            randomize_button,
            save_button,
            expert_button
        },
        dt.new_widget("separator") {},
        preview_text,
        preset_info
    }
    
    return main_box
end

-- Get preset names for dropdown
function ui.get_preset_names()
    local names = {}
    for _, preset in ipairs(ui.presets) do
        table.insert(names, preset.name)
    end
    return names
end

-- Update preview text
function ui.update_preview()
    local preset_info = ui.panel_window:find_child("preset_info")
    if preset_info then
        preset_info.label = "Selected: " .. ui.selected_preset .. " (Intensity: " .. ui.intensity .. "%)"
    end
end

-- Randomize preset selection
function ui.randomize_preset()
    local random_index = math.random(1, #ui.presets)
    ui.selected_preset = ui.presets[random_index].name
    ui.intensity = math.random(20, 90)
    
    -- Update UI
    local preset_dropdown = ui.panel_window:find_child("preset_dropdown")
    if preset_dropdown then
        preset_dropdown.value = ui.selected_preset
    end
    
    local intensity_slider = ui.panel_window:find_child("intensity_slider")
    if intensity_slider then
        intensity_slider.value = ui.intensity
    end
    
    ui.update_preview()
end

-- Show import wizard (Tier 2)
function ui.show_import_wizard()
    dt.print("Import wizard would open here. This would parse Fujifilm or Mood Camera recipes.")
end

-- Save current look
function ui.save_current_look()
    local filename = dt.gui.dialogs.save_file("Save FXLM Look", "", ".fxlm")
    if filename then
        -- Save the current preset configuration
        local preset_data = ui.get_preset_by_name(ui.selected_preset)
        if preset_data then
            -- Create FXLM file content
            local content = string.format([[
-- FXLM Preset File
-- Generated by FXLM Plugin
-- Preset: %s
-- Intensity: %d%%

return {
    name = "%s",
    intensity = %d,
    parameters = %s
}
]], ui.selected_preset, ui.intensity, ui.selected_preset, ui.intensity, 
                require("serpent").block(preset_data.parameters))
            
            -- Write to file
            local file = io.open(filename, "w")
            if file then
                file:write(content)
                file:close()
                dt.print("Look saved to: " .. filename)
            else
                dt.print("Error: Could not save file")
            end
        end
    end
end

-- Show expert UI (Tier 3)
function ui.show_expert_ui()
    dt.print("Expert UI would show full module controls. This is Tier 3 from the mockup.")
end

-- Get preset by name
function ui.get_preset_by_name(name)
    for _, preset in ipairs(ui.presets) do
        if preset.name == name then
            return preset
        end
    end
    return nil
end

-- Apply preset to current image
function ui.apply_preset_to_image()
    local image = dt.gui_actions.get_current_image()
    if not image then
        dt.print("No image selected")
        return
    end
    
    local preset = ui.get_preset_by_name(ui.selected_preset)
    if not preset then
        dt.print("Preset not found")
        return
    end
    
    -- Apply intensity scaling
    local intensity_factor = ui.intensity / 100
    
    -- Apply to image modules
    for module_name, params in pairs(preset.parameters) do
        -- This would apply the parameters to the appropriate Darktable modules
        -- For now, just print what would be applied
        dt.print("Would apply " .. module_name .. " with intensity " .. intensity_factor)
    end
    
    dt.print("Applied preset: " .. ui.selected_preset .. " at " .. ui.intensity .. "% intensity")
end

-- Register keyboard shortcuts
function ui.register_shortcuts()
    dt.register_keyboard_shortcut(
        "fxlm_apply",
        "Apply Current FXLM Preset",
        "a",
        function()
            ui.apply_preset_to_image()
        end
    )
end

-- Initialize UI
ui.register_shortcuts()

return ui