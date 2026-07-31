local dt = require "darktable"
local du = require "lib/dtutils"
local dsys = require "lib/dtutils.system"

local MODULE_NAME = "LoadFastRawViewer" -- make sure this is unique, no spaces, no special characters   
local EVENT_NAME = "fastrawviewer" -- must be unique for this script
local EVENT_TYPE = "post-import-film" -- the event we want (keyboard shortcut)

du.check_min_api_version("7.0.0", MODULE_NAME)

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager
local script_data = {}

script_data.metadata = {
    name = "FastRawViewer On Import",
    purpose = "Launch fastrawviewer on import",
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

local function on_post_import_film(film)
    dt.print_log("Post-import callback triggered.")
    dt.print_log("Film path: " .. film.path)
    local command = '"C:\\Program Files\\LibRaw\\FastRawViewer\\FastRawViewer.exe" "' .. film.path .. '"'
    dt.print_log("Executing command: " .. command)
    local result = dsys.windows_command(command)

end

-- defensive cleanup: remove any previous registration with the same name/type
pcall(dt.destroy_event, EVENT_TYPE, EVENT_NAME)

-- register the event correctly
dt.register_event(EVENT_NAME, -- unique name
EVENT_TYPE, -- e.g. "post-import-film"
function(event, film)
    dt.print_log("Registering post-import callback.")
    on_post_import_film(film)
end)

dt.print_log("post_import_film.lua loaded — will run after each film import.")

return script_data
