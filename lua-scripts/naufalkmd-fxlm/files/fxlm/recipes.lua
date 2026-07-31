-- FXLM Recipe Conversion Module
-- Handles conversion of Fujifilm and Mood Camera recipes to FXLM format

local dt = require "darktable"
local recipes = {}

-- Recipe source types
recipes.source_types = {
    FUJIFILM = "fujifilm",
    MOOD_CAMERA = "mood_camera",
    UNKNOWN = "unknown"
}

-- Fujifilm recipe field mappings
recipes.fuji_mappings = {
    -- Film Simulation
    ["PROVIA/Standard"] = { film_sim = "provia", lut = "standard" },
    ["Velvia/Vivid"] = { film_sim = "velvia", lut = "vivid" },
    ["ASTIA/Soft"] = { film_sim = "astia", lut = "soft" },
    ["Classic Chrome"] = { film_sim = "classic_chrome", lut = "classic" },
    ["PRO Neg.Hi"] = { film_sim = "pro_neg_hi", lut = "pro_neg_hi" },
    ["PRO Neg.Std"] = { film_sim = "pro_neg_std", lut = "pro_neg_std" },
    ["Classic Neg"] = { film_sim = "classic_neg", lut = "classic_neg" },
    ["Eterna/Cinema"] = { film_sim = "eterna", lut = "cinema" },
    ["Eterna Bleach Bypass"] = { film_sim = "eterna_bleach", lut = "bleach" },
    ["Acros"] = { film_sim = "acros", lut = "acros" },
    ["Monochrome"] = { film_sim = "mono", lut = "mono" },
    ["Sepia"] = { film_sim = "sepia", lut = "sepia" },
    
    -- Dynamic Range
    ["DR100"] = { dr = 100 },
    ["DR200"] = { dr = 200 },
    ["DR400"] = { dr = 400 },
    
    -- Highlight/Shadow
    ["-2"] = { highlight = -2 },
    ["-1"] = { highlight = -1 },
    ["0"] = { highlight = 0 },
    ["+1"] = { highlight = 1 },
    ["+2"] = { highlight = 2 },
    
    -- White Balance
    ["Daylight"] = { wb_mode = "daylight", wb_shift_r = 0, wb_shift_b = 0 },
    ["Shade"] = { wb_mode = "shade", wb_shift_r = 0, wb_shift_b = 0 },
    ["Fluorescent"] = { wb_mode = "fluorescent", wb_shift_r = 0, wb_shift_b = 0 },
    ["Incandescent"] = { wb_mode = "incandescent", wb_shift_r = 0, wb_shift_b = 0 },
    ["Underwater"] = { wb_mode = "underwater", wb_shift_r = 0, wb_shift_b = 0 },
    ["Custom"] = { wb_mode = "custom", wb_shift_r = 0, wb_shift_b = 0 },
    ["Kelvin"] = { wb_mode = "kelvin", wb_shift_r = 0, wb_shift_b = 0 }
}

-- Mood Camera recipe field mappings
recipes.mood_mappings = {
    -- Intensity
    intensity = { min = 0, max = 100, default = 50 },
    
    -- Fade
    fade = { min = 0, max = 100, default = 0 },
    
    -- Contrast
    contrast = { min = 0, max = 100, default = 50 },
    
    -- Warmth
    warmth = { min = -100, max = 100, default = 0 },
    
    -- Tint
    tint = { min = -100, max = 100, default = 0 },
    
    -- Grain
    grain = { min = 0, max = 100, default = 0 },
    
    -- Glow
    glow = { min = 0, max = 100, default = 0 },
    
    -- Halation
    halation = { min = 0, max = 100, default = 0 }
}

-- Parse a Fujifilm recipe string
function recipes.parse_fujifilm_recipe(recipe_string)
    local recipe = {
        source = recipes.source_types.FUJIFILM,
        fields = {},
        raw_data = recipe_string
    }
    
    -- Split recipe into lines
    local lines = {}
    for line in recipe_string:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Parse each line
    for _, line in ipairs(lines) do
        -- Look for key-value pairs
        local key, value = line:match("^%s*([^:]+):%s*(.+)$")
        if key and value then
            key = key:lower():gsub("%s+", "_")
            recipe.fields[key] = value
        end
    end
    
    return recipe
end

-- Parse a Mood Camera recipe string
function recipes.parse_mood_camera_recipe(recipe_string)
    local recipe = {
        source = recipes.source_types.MOOD_CAMERA,
        fields = {},
        raw_data = recipe_string
    }
    
    -- Split recipe into lines
    local lines = {}
    for line in recipe_string:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Parse each line
    for _, line in ipairs(lines) do
        -- Look for key-value pairs (Mood Camera format)
        local key, value = line:match("^%s*([^=]+)%s*=%s*(.+)$")
        if key and value then
            key = key:lower():gsub("%s+", "_")
            recipe.fields[key] = value
        end
    end
    
    return recipe
end

-- Detect recipe source type
function recipes.detect_source_type(recipe_string)
    -- Check for Fujifilm indicators
    if recipe_string:find("Film Simulation") or recipe_string:find("Dynamic Range") then
        return recipes.source_types.FUJIFILM
    end
    
    -- Check for Mood Camera indicators
    if recipe_string:find("Intensity") or recipe_string:find("Fade") or recipe_string:find("Warmth") then
        return recipes.source_types.MOOD_CAMERA
    end
    
    return recipes.source_types.UNKNOWN
end

-- Convert parsed recipe to FXLM Internal Representation (IR)
function recipes.to_internal_representation(recipe)
    local ir = {
        tone = {},
        color = {},
        texture = {},
        optical = {},
        finishing = {},
        metadata = {
            source = recipe.source,
            raw_data = recipe.raw_data
        }
    }
    
    if recipe.source == recipes.source_types.FUJIFILM then
        recipes.convert_fuji_to_ir(recipe.fields, ir)
    elseif recipe.source == recipes.source_types.MOOD_CAMERA then
        recipes.convert_mood_to_ir(recipe.fields, ir)
    end
    
    return ir
end

-- Convert Fujifilm fields to IR
function recipes.convert_fuji_to_ir(fields, ir)
    -- Film Simulation (maps to LUT selection)
    if fields.film_simulation then
        local fuji_info = recipes.fuji_mappings[fields.film_simulation]
        if fuji_info then
            ir.metadata.film_simulation = fuji_info.film_sim
            ir.metadata.lut = fuji_info.lut
        end
    end
    
    -- Dynamic Range (maps to exposure and tone mapping)
    if fields.dynamic_range then
        local dr_info = recipes.fuji_mappings[fields.dynamic_range]
        if dr_info then
            -- DR100 = standard, DR200 = +1 stop, DR400 = +2 stops
            local dr_value = dr_info.dr
            if dr_value == 100 then
                ir.tone.exposure_adjustment = 0
            elseif dr_value == 200 then
                ir.tone.exposure_adjustment = 1
            elseif dr_value == 400 then
                ir.tone.exposure_adjustment = 2
            end
        end
    end
    
    -- Highlight/Shadow (maps to filmic RGB parameters)
    if fields.highlight then
        local highlight_value = tonumber(fields.highlight)
        if highlight_value then
            -- Negative values = more highlight roll-off
            ir.tone.highlight_rolloff = 0.5 + (highlight_value * 0.1)
        end
    end
    
    if fields.shadow then
        local shadow_value = tonumber(fields.shadow)
        if shadow_value then
            -- Negative values = more shadow compression
            ir.tone.shadow_compression = 0.5 + (shadow_value * 0.1)
        end
    end
    
    -- Color (maps to saturation)
    if fields.color then
        local color_value = tonumber(fields.color)
        if color_value then
            -- Fuji color: -2 to +2, map to 0.5 to 1.5
            ir.color.saturation = 1.0 + (color_value * 0.25)
        end
    end
    
    -- Grain
    if fields.grain then
        local grain_value = tonumber(fields.grain)
        if grain_value then
            -- Fuji grain: -2 to +4, map to 0.0 to 1.0
            ir.texture.grain_amount = math.max(0, math.min(1, (grain_value + 2) / 6))
        end
    end
    
    -- White Balance (maps to warmth/tint)
    if fields.white_balance then
        local wb_info = recipes.fuji_mappings[fields.white_balance]
        if wb_info then
            ir.color.wb_mode = wb_info.wb_mode
        end
    end
    
    -- WB Shift (maps to warmth/tint)
    if fields.wb_shift_r then
        local r_shift = tonumber(fields.wb_shift_r)
        if r_shift then
            -- Red shift affects warmth
            ir.color.warmth = r_shift * 0.1
        end
    end
    
    if fields.wb_shift_b then
        local b_shift = tonumber(fields.wb_shift_b)
        if b_shift then
            -- Blue shift affects warmth (negative)
            ir.color.warmth = (ir.color.warmth or 0) - (b_shift * 0.1)
        end
    end
end

-- Convert Mood Camera fields to IR
function recipes.convert_mood_to_ir(fields, ir)
    -- Intensity (maps to overall effect strength)
    if fields.intensity then
        local intensity_value = tonumber(fields.intensity)
        if intensity_value then
            ir.metadata.intensity = intensity_value
        end
    end
    
    -- Fade (maps to contrast reduction and saturation)
    if fields.fade then
        local fade_value = tonumber(fields.fade)
        if fade_value then
            -- Fade reduces contrast and saturation
            ir.tone.contrast = 1.0 - (fade_value / 100 * 0.5)
            ir.color.saturation = 1.0 - (fade_value / 100 * 0.3)
        end
    end
    
    -- Contrast (maps to filmic RGB contrast)
    if fields.contrast then
        local contrast_value = tonumber(fields.contrast)
        if contrast_value then
            -- Map 0-100 to 0.5-1.5
            ir.tone.contrast = 0.5 + (contrast_value / 100)
        end
    end
    
    -- Warmth (maps to color balance warmth)
    if fields.warmth then
        local warmth_value = tonumber(fields.warmth)
        if warmth_value then
            -- Map -100 to 100 to -1.0 to 1.0
            ir.color.warmth = warmth_value / 100
        end
    end
    
    -- Tint (maps to color balance tint)
    if fields.tint then
        local tint_value = tonumber(fields.tint)
        if tint_value then
            -- Map -100 to 100 to -1.0 to 1.0
            ir.color.tint = tint_value / 100
        end
    end
    
    -- Grain
    if fields.grain then
        local grain_value = tonumber(fields.grain)
        if grain_value then
            -- Map 0-100 to 0.0-1.0
            ir.texture.grain_amount = grain_value / 100
        end
    end
    
    -- Glow (maps to bloom/halation)
    if fields.glow then
        local glow_value = tonumber(fields.glow)
        if glow_value then
            -- Map 0-100 to 0.0-1.0
            ir.optical.bloom_amount = glow_value / 100
        end
    end
    
    -- Halation
    if fields.halation then
        local halation_value = tonumber(fields.halation)
        if halation_value then
            -- Map 0-100 to 0.0-1.0
            ir.optical.halation_amount = halation_value / 100
        end
    end
end

-- Convert IR to FXLM preset format
function recipes.ir_to_fxlm_preset(ir, preset_name)
    local preset = {
        name = preset_name or "Converted Recipe",
        description = "Converted from " .. (ir.metadata.source or "unknown"),
        version = "1.0",
        author = "FXLM Recipe Converter",
        intensity = ir.metadata.intensity or 100,
        parameters = {}
    }
    
    -- Map IR to Darktable module parameters
    -- Base Tone Mapping
    preset.parameters.filmic_rgb = {
        contrast = ir.tone.contrast or 1.0,
        saturation = ir.color.saturation or 1.0,
        highlight_compression = ir.tone.highlight_rolloff or 0.5,
        shadow_compression = ir.tone.shadow_compression or 0.5
    }
    
    -- Color Science
    preset.parameters.color_balance_rgb = {
        saturation = ir.color.saturation or 1.0,
        warmth = ir.color.warmth or 0.0,
        tint = ir.color.tint or 0.0
    }
    
    -- Texture
    if ir.texture.grain_amount then
        preset.parameters.grain = {
            amount = ir.texture.grain_amount,
            size = ir.texture.grain_size or 0.5,
            roughness = ir.texture.grain_roughness or 0.5
        }
    end
    
    -- Optical Effects
    if ir.optical.bloom_amount or ir.optical.halation_amount then
        preset.parameters.vignette = {
            amount = ir.optical.vignette_amount or 0.1,
            radius = 0.5,
            strength = 0.5
        }
    end
    
    return preset
end

-- Convert recipe string to FXLM preset
function recipes.convert_recipe(recipe_string, preset_name)
    -- Detect source type
    local source_type = recipes.detect_source_type(recipe_string)
    
    if source_type == recipes.source_types.UNKNOWN then
        return nil, "Could not detect recipe source type"
    end
    
    -- Parse recipe
    local recipe
    if source_type == recipes.source_types.FUJIFILM then
        recipe = recipes.parse_fujifilm_recipe(recipe_string)
    elseif source_type == recipes.source_types.MOOD_CAMERA then
        recipe = recipes.parse_mood_camera_recipe(recipe_string)
    end
    
    if not recipe then
        return nil, "Failed to parse recipe"
    end
    
    -- Convert to IR
    local ir = recipes.to_internal_representation(recipe)
    
    -- Convert to FXLM preset
    local preset = recipes.ir_to_fxlm_preset(ir, preset_name)
    
    return preset, nil
end

-- Generate preview of conversion
function recipes.generate_conversion_preview(recipe_string)
    local source_type = recipes.detect_source_type(recipe_string)
    local preview = {
        source_type = source_type,
        fields = {},
        estimated_fxlm_modules = {}
    }
    
    -- Parse and show fields
    local recipe
    if source_type == recipes.source_types.FUJIFILM then
        recipe = recipes.parse_fujifilm_recipe(recipe_string)
    elseif source_type == recipes.source_types.MOOD_CAMERA then
        recipe = recipes.parse_mood_camera_recipe(recipe_string)
    end
    
    if recipe then
        preview.fields = recipe.fields
        
        -- Estimate which Darktable modules will be affected
        if recipe.fields.film_simulation then
            table.insert(preview.estimated_fxlm_modules, "LUT (Film Simulation)")
        end
        
        if recipe.fields.dynamic_range or recipe.fields.highlight or recipe.fields.shadow then
            table.insert(preview.estimated_fxlm_modules, "Filmic RGB")
        end
        
        if recipe.fields.color or recipe.fields.warmth or recipe.fields.tint then
            table.insert(preview.estimated_fxlm_modules, "Color Balance RGB")
        end
        
        if recipe.fields.grain then
            table.insert(preview.estimated_fxlm_modules, "Grain")
        end
        
        if recipe.fields.glow or recipe.fields.halation then
            table.insert(preview.estimated_fxlm_modules, "Vignette (for optical effects)")
        end
    end
    
    return preview
end

-- Validate recipe string
function recipes.validate_recipe(recipe_string)
    local source_type = recipes.detect_source_type(recipe_string)
    
    if source_type == recipes.source_types.UNKNOWN then
        return false, "Unknown recipe format"
    end
    
    -- Try to parse
    local recipe
    if source_type == recipes.source_types.FUJIFILM then
        recipe = recipes.parse_fujifilm_recipe(recipe_string)
    elseif source_type == recipes.source_types.MOOD_CAMERA then
        recipe = recipes.parse_mood_camera_recipe(recipe_string)
    end
    
    if not recipe then
        return false, "Failed to parse recipe"
    end
    
    return true, "Valid " .. source_type .. " recipe"
end

-- Export recipe as FXLM file
function recipes.export_as_fxlm(recipe_string, output_path)
    local preset, error = recipes.convert_recipe(recipe_string)
    
    if not preset then
        return false, error
    end
    
    -- Save to file
    local file = io.open(output_path, "w")
    if not file then
        return false, "Could not open output file"
    end
    
    -- Convert to FXLM format
    local content = recipes.preset_to_fxlm_format(preset)
    
    file:write(content)
    file:close()
    
    return true, "Recipe converted and saved to " .. output_path
end

-- Convert preset to FXLM file format
function recipes.preset_to_fxlm_format(preset)
    local lines = {}
    
    table.insert(lines, "-- FXLM Preset File (Converted from Recipe)")
    table.insert(lines, "-- Generated by FXLM Recipe Converter")
    table.insert(lines, "-- Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "")
    
    table.insert(lines, "return {")
    table.insert(lines, "    name = \"" .. preset.name .. "\",")
    table.insert(lines, "    description = \"" .. preset.description .. "\",")
    table.insert(lines, "    version = \"" .. preset.version .. "\",")
    table.insert(lines, "    author = \"" .. preset.author .. "\",")
    table.insert(lines, "    intensity = " .. preset.intensity .. ",")
    table.insert(lines, "    parameters = {")
    
    -- Add parameters
    if preset.parameters then
        for module_name, params in pairs(preset.parameters) do
            table.insert(lines, "        " .. module_name .. " = {")
            for param_name, param_value in pairs(params) do
                if type(param_value) == "string" then
                    table.insert(lines, "            " .. param_name .. " = \"" .. param_value .. "\",")
                else
                    table.insert(lines, "            " .. param_name .. " = " .. tostring(param_value) .. ",")
                end
            end
            table.insert(lines, "        },")
        end
    end
    
    table.insert(lines, "    },")
    table.insert(lines, "}")
    
    return table.concat(lines, "\n")
end

-- Sample recipe strings for testing
recipes.sample_fuji_recipe = [[
Film Simulation: Classic Chrome
Dynamic Range: DR200
Highlight: -1
Shadow: -1
Color: +1
Grain: Weak
White Balance: Daylight
WB Shift R: +1
WB Shift B: -2
]]

recipes.sample_mood_recipe = [[
Intensity = 75
Fade = 20
Contrast = 65
Warmth = 15
Tint = -5
Grain = 25
Glow = 10
Halation = 5
]]

return recipes