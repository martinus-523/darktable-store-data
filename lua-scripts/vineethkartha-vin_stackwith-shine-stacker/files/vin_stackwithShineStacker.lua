local dt = require "darktable"

-- 1. Create the UI Widgets
local name_entry = dt.new_widget("entry") {
    tooltip = "Enter the desired final name",
    text = "stacked_result"
}

local stack_button = dt.new_widget("button") {
    label = "Focus Stack",
    tooltip = "Stack the selected images using Shine Stacker",
    clicked_callback = function(widget)
        -- Get currently selected images in the lighttable
        local images = dt.gui.action_images
        
        if #images < 2 then
            dt.print_error("Shine Stacker: Please select at least 2 images to stack.")
            return
        end

        local desired_name = name_entry.text
        if desired_name == "" then
            desired_name = "stacked_result"
        end

        -- Determine the output directory (defaulting to the folder of the first image)
        local out_dir = images[1].path
        
        -- PATH CONFIGURATION: Update this if your python script is saved somewhere else
        local PYTHON_BIN = "/home/vineeth/shinestacker_env/env/bin/python3.12"
        local PYTHON_SCRIPT_PATH = "/home/vineeth/.config/darktable/lua/darktableluascripts/lib/shinestackscript.py" 

        -- Build the list of file paths to pass to python
        local file_args = ""
        for _, img in ipairs(images) do
            -- Enclose paths in quotes to handle folder names with spaces
            local full_path = img.path .. "/" .. img.filename
            file_args = file_args .. string.format(' "%s"', full_path)
        end

        -- Construct the terminal command
        local cmd = string.format('%s %s --name "%s" --outdir "%s" %s', 
                                  PYTHON_BIN, PYTHON_SCRIPT_PATH, desired_name, out_dir, file_args)
        
        dt.print("Shine Stacker started... Darktable may pause while processing.")
        
        -- Execute the Python script
        local result = os.execute(cmd)
        
        if result == 0 or result == true then
            dt.print("Shine Stacker: Successfully stacked into " .. desired_name .. ".tif!")
        else
            dt.print_error("Shine Stacker: Failed. Please check the terminal/console for Python errors.")
        end
    end
}

-- 2. Register the module in the Lighttable UI
dt.register_lib(
    "shinestacker_gui",          -- unique module name
    "Shine Stacker",             -- title shown in the Darktable UI
    true,                        -- expandable
    false,                       -- resettable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}}, -- place in right panel
    dt.new_widget("box") {
        orientation = "vertical",
        name_entry,
        stack_button
    },
    nil, -- view_enter callback
    nil  -- view_leave callback
)