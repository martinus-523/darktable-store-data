local dt = require "darktable"
local du = require "lib/dtutils"
local dsys = require "lib/dtutils.system"

local MODULE_NAME = "LaunchFastRawViewer" -- make sure this is unique, no spaces, no special characters   
local EVENT_NAME = "launchfastrawviewer" -- must be unique for this script
local EVENT_TYPE = "shortcut" -- the event we want (keyboard shortcut)

du.check_min_api_version("9.5.0", MODULE_NAME)

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager
local script_data = {}

script_data.metadata = {
    name = "Launch FastRawViewer",
    purpose = "Launch fastrawviewer on selected film",
    author = "Vineeth Kartha",
    help = "abcd" -- this seems important
}

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    pcall(dt.destroy_event, EVENT_NAME, EVENT_TYPE)
    dt.print("Destroyed" .. EVENT_NAME)
end

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
script_data.destroy = destroy

local function launchfastrawviwer()
    local images = dt.gui.action_images

    if #images == 0 then
        dt.print_log("No images visible in the current film roll.")
        return
    end

    local film = images[1].film
    if not film then
        dt.print("Unable to determine current film roll.")
        return
    end
    dt.print_log("Film path: " .. film.path)
    dt.print_toast("Launching FastRawViewer for film: " .. film.path)

    -- 1. Detect the operating system using official API
    local is_windows = (dt.configuration.running_os == "windows")
    local command
    
    if is_windows then
        -- 2. Windows path execution
        command = '"C:\\Program Files\\LibRaw\\FastRawViewer\\FastRawViewer.exe" "' .. film.path .. '"'
        
        dt.print_log("Executing Windows command: " .. command)
        local result = dsys.windows_command(command)
    else
        -- 3. Linux path execution (via Wine)
        local home = os.getenv("HOME")
        command = 'wine "' .. home .. '/.wine/drive_c/Program Files/LibRaw/FastRawViewer/FastRawViewer.exe" "' .. film.path .. '" &'
        
        dt.print_log("Executing Linux command: " .. command)
        local result = os.execute(command)
    end
    
end

-- defensive cleanup: remove any previous registration with the same name/type
pcall(dt.destroy_event, EVENT_TYPE, EVENT_NAME)

-- register the event correctly
dt.register_event(EVENT_NAME, -- event name (unique id)
EVENT_TYPE, -- event type
function(event, shortcut)
    launchfastrawviwer()
end, _("Launch fast raw viewer") -- label shown in Shortcuts prefs
)

return script_data

