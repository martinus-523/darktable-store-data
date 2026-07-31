-- FXLM Core Module
-- Handles film simulation logic and Darktable module orchestration

local dt = require "darktable"
local core = {}

-- Film simulation parameters based on coreelement.txt
core.film_characteristics = {
    -- Tone Mapping & Density Behavior
    tone_mapping = {
        base_tone_curve = true,
        shadow_compression = true,
        highlight_roll_off = true,
        midtone_contrast = true,
        dynamic_range_mapping = true,
        toe_shoulder_shaping = true,
        exposure_latitude = true
    },
    
    -- Color Science & Dye Behavior
    color_science = {
        color_response_curves = true,
        non_linear_red_response = true,
        green_dominance = true,
        blue_shadow_bias = true,
        cross_channel_interaction = true,
        white_balance_bias = true,
        channel_mixer_behavior = true,
        hue_dependent_saturation = true,
        saturation_falloff_highlights = true,
        warm_highlight_bias = true
    },
    
    -- Spectral Sensitivity (High-Level Approximation)
    spectral_sensitivity = {
        channel_curve_shaping = true,
        hue_warping = true,
        selective_color_shifts = true
    }
}

-- Module mapping based on pipeline.txt
core.module_mapping = {
    -- Base Tone Mapping
    filmic_rgb = {
        description = "Base tone mapping",
        parameters = {
            contrast = { min = 0.5, max = 2.0, default = 1.0 },
            saturation = { min = 0.0, max = 2.0, default = 1.0 },
            highlight_compression = { min = 0.0, max = 1.0, default = 0.5 },
            shadow_compression = { min = 0.0, max = 1.0, default = 0.5 }
        }
    },
    
    exposure = {
        description = "Exposure adjustment",
        parameters = {
            exposure = { min = -3.0, max = 3.0, default = 0.0 },
            black = { min = 0.0, max = 1.0, default = 0.0 }
        }
    },
    
    tone_equalizer = {
        description = "Tone equalizer",
        parameters = {
            shadows = { min = -2.0, max = 2.0, default = 0.0 },
            midtones = { min = -2.0, max = 2.0, default = 0.0 },
            highlights = { min = -2.0, max = 2.0, default = 0.0 }
        }
    },
    
    -- Color Science Layer
    color_balance_rgb = {
        description = "Color balance RGB",
        parameters = {
            saturation = { min = 0.0, max = 2.0, default = 1.0 },
            warmth = { min = -1.0, max = 1.0, default = 0.0 },
            tint = { min = -1.0, max = 1.0, default = 0.0 }
        }
    },
    
    rgb_curve = {
        description = "RGB curve adjustments",
        parameters = {
            red = { min = 0.0, max = 2.0, default = 1.0 },
            green = { min = 0.0, max = 2.0, default = 1.0 },
            blue = { min = 0.0, max = 2.0, default = 1.0 }
        }
    },
    
    channel_mixer = {
        description = "Channel mixer",
        parameters = {
            red_red = { min = -1.0, max = 2.0, default = 1.0 },
            red_green = { min = -1.0, max = 2.0, default = 0.0 },
            red_blue = { min = -1.0, max = 2.0, default = 0.0 },
            green_red = { min = -1.0, max = 2.0, default = 0.0 },
            green_green = { min = -1.0, max = 2.0, default = 1.0 },
            green_blue = { min = -1.0, max = 2.0, default = 0.0 },
            blue_red = { min = -1.0, max = 2.0, default = 0.0 },
            blue_green = { min = -1.0, max = 2.0, default = 0.0 },
            blue_blue = { min = -1.0, max = 2.0, default = 1.0 }
        }
    },
    
    -- Film Character Layer
    grain = {
        description = "Film grain simulation",
        parameters = {
            amount = { min = 0.0, max = 1.0, default = 0.1 },
            size = { min = 0.1, max = 2.0, default = 0.5 },
            roughness = { min = 0.0, max = 1.0, default = 0.5 }
        }
    },
    
    vignette = {
        description = "Vignette effect",
        parameters = {
            amount = { min = 0.0, max = 1.0, default = 0.1 },
            radius = { min = 0.0, max = 1.0, default = 0.5 },
            strength = { min = 0.0, max = 1.0, default = 0.5 }
        }
    },
    
    -- Finishing Layer
    contrast_eq = {
        description = "Contrast equalizer",
        parameters = {
            contrast = { min = 0.0, max = 2.0, default = 1.0 },
            brightness = { min = -1.0, max = 1.0, default = 0.0 }
        }
    },
    
    local_contrast = {
        description = "Local contrast",
        parameters = {
            radius = { min = 0.0, max = 10.0, default = 1.0 },
            amount = { min = 0.0, max = 2.0, default = 0.5 }
        }
    }
}

-- Apply preset to current image
function core.apply_preset(preset_name, intensity, preset_data)
    local image = dt.gui_actions.get_current_image()
    if not image then
        dt.print("No image selected")
        return false
    end
    
    local intensity_factor = intensity / 100
    
    -- Apply each module parameter
    for module_name, params in pairs(preset_data.parameters) do
        if core.module_mapping[module_name] then
            -- Scale parameters by intensity
            local scaled_params = {}
            for param_name, param_value in pairs(params) do
                if type(param_value) == "number" then
                    -- Scale the parameter based on intensity
                    scaled_params[param_name] = core.scale_parameter(
                        module_name, param_name, param_value, intensity_factor
                    )
                else
                    scaled_params[param_name] = param_value
                end
            end
            
            -- Apply to Darktable module
            core.apply_module_params(image, module_name, scaled_params)
        end
    end
    
    dt.print("Applied preset: " .. preset_name .. " at " .. intensity .. "% intensity")
    return true
end

-- Scale parameter based on intensity
function core.scale_parameter(module_name, param_name, value, intensity_factor)
    local module_info = core.module_mapping[module_name]
    if not module_info or not module_info.parameters[param_name] then
        return value
    end
    
    local param_info = module_info.parameters[param_name]
    local min_val = param_info.min
    local max_val = param_info.max
    local default_val = param_info.default or 0
    
    -- For values that should be scaled (like contrast, saturation)
    if param_name == "contrast" or param_name == "saturation" then
        -- Scale from default towards the target value
        local range = max_val - min_val
        local target_range = value - default_val
        return default_val + (target_range * intensity_factor)
    elseif param_name == "amount" or param_name == "strength" then
        -- Direct scaling for amount parameters
        return value * intensity_factor
    elseif param_name == "warmth" or param_name == "tint" then
        -- Scale color adjustments
        return value * intensity_factor
    else
        -- For other parameters, use linear interpolation
        return min_val + (value - min_val) * intensity_factor
    end
end

-- Apply parameters to a specific Darktable module
function core.apply_module_params(image, module_name, params)
    -- This is a simplified implementation
    -- In a real implementation, you would use Darktable's API
    -- to set module parameters
    
    local module = dt.gui_actions.get_module(module_name)
    if not module then
        -- Module might not be enabled, try to enable it
        dt.print("Module " .. module_name .. " not found, would need to enable it")
        return false
    end
    
    -- Apply each parameter
    for param_name, param_value in pairs(params) do
        if module[param_name] then
            module[param_name] = param_value
        end
    end
    
    return true
end

-- Get film simulation characteristics for a preset
function core.get_film_characteristics(preset_name)
    -- Return the film characteristics that this preset simulates
    -- Based on the preset name and parameters
    
    local characteristics = {
        tone_mapping = {},
        color_science = {},
        spectral_sensitivity = {}
    }
    
    -- Analyze preset to determine characteristics
    if preset_name:find("Portrait") then
        characteristics.tone_mapping = {
            "soft_highlight_roll_off",
            "gentle_shadow_compression"
        }
        characteristics.color_science = {
            "warm_skin_tones",
            "reduced_saturation"
        }
    elseif preset_name:find("Vintage") then
        characteristics.tone_mapping = {
            "strong_highlight_roll_off",
            "lifted_blacks"
        }
        characteristics.color_science = {
            "warm_tint",
            "faded_colors"
        }
    elseif preset_name:find("Cinematic") then
        characteristics.tone_mapping = {
            "high_contrast",
            "sharp_highlight_roll_off"
        }
        characteristics.color_science = {
            "cool_tint",
            "enhanced_saturation"
        }
    end
    
    return characteristics
end

-- Convert parameters to FXLM Internal Representation (IR)
function core.to_internal_representation(preset_data)
    local ir = {
        tone = {},
        color = {},
        texture = {},
        optical = {},
        finishing = {},
        metadata = {}
    }
    
    -- Map module parameters to IR fields
    for module_name, params in pairs(preset_data.parameters) do
        if module_name == "filmic_rgb" then
            ir.tone.contrast = params.contrast or 1.0
            ir.tone.saturation = params.saturation or 1.0
            ir.tone.highlight_rolloff = params.highlight_compression or 0.5
            ir.tone.shadow_compression = params.shadow_compression or 0.5
        elseif module_name == "color_balance_rgb" then
            ir.color.saturation = params.saturation or 1.0
            ir.color.warmth = params.warmth or 0.0
            ir.color.tint = params.tint or 0.0
        elseif module_name == "grain" then
            ir.texture.grain_amount = params.amount or 0.1
            ir.texture.grain_size = params.size or 0.5
            ir.texture.grain_roughness = params.roughness or 0.5
        elseif module_name == "vignette" then
            ir.optical.vignette_amount = params.amount or 0.1
        end
    end
    
    -- Add metadata
    ir.metadata.source = "FXLM Preset"
    ir.metadata.version = "1.0"
    
    return ir
end

-- Convert from Internal Representation to module parameters
function core.from_internal_representation(ir)
    local parameters = {}
    
    -- Map IR fields back to module parameters
    if ir.tone then
        parameters.filmic_rgb = {
            contrast = ir.tone.contrast or 1.0,
            saturation = ir.tone.saturation or 1.0,
            highlight_compression = ir.tone.highlight_rolloff or 0.5,
            shadow_compression = ir.tone.shadow_compression or 0.5
        }
    end
    
    if ir.color then
        parameters.color_balance_rgb = {
            saturation = ir.color.saturation or 1.0,
            warmth = ir.color.warmth or 0.0,
            tint = ir.color.tint or 0.0
        }
    end
    
    if ir.texture then
        parameters.grain = {
            amount = ir.texture.grain_amount or 0.1,
            size = ir.texture.grain_size or 0.5,
            roughness = ir.texture.grain_roughness or 0.5
        }
    end
    
    if ir.optical then
        parameters.vignette = {
            amount = ir.optical.vignette_amount or 0.1
        }
    end
    
    return parameters
end

-- Validate preset parameters
function core.validate_preset(preset_data)
    local errors = {}
    
    if not preset_data.name then
        table.insert(errors, "Preset must have a name")
    end
    
    if not preset_data.parameters then
        table.insert(errors, "Preset must have parameters")
        return false, errors
    end
    
    -- Validate each module parameter
    for module_name, params in pairs(preset_data.parameters) do
        if not core.module_mapping[module_name] then
            table.insert(errors, "Unknown module: " .. module_name)
        else
            -- Validate individual parameters
            for param_name, param_value in pairs(params) do
                local module_info = core.module_mapping[module_name]
                if module_info and module_info.parameters[param_name] then
                    local param_info = module_info.parameters[param_name]
                    if type(param_value) == "number" then
                        if param_value < param_info.min or param_value > param_info.max then
                            table.insert(errors, string.format(
                                "Parameter %s.%s out of range: %f (min: %f, max: %f)",
                                module_name, param_name, param_value, param_info.min, param_info.max
                            ))
                        end
                    end
                end
            end
        end
    end
    
    return #errors == 0, errors
end

-- Generate preview of what will be applied
function core.generate_preview(preset_name, intensity, preset_data)
    local preview = {
        modules = {},
        characteristics = {}
    }
    
    -- List modules that will be affected
    for module_name, params in pairs(preset_data.parameters) do
        preview.modules[module_name] = {
            params = params,
            intensity = intensity
        }
    end
    
    -- Get film characteristics
    preview.characteristics = core.get_film_characteristics(preset_name)
    
    return preview
end

return core