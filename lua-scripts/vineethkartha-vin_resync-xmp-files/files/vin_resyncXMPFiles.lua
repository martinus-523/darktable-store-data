local dt = require "darktable"
local du = require "lib/dtutils"
local dsys = require "lib/dtutils.system"

local MODULE_NAME = "ResyncXMPFiles" -- make sure this is unique, no spaces, no special characters   
local EVENT_NAME = "resyncxmpfiles" -- must be unique for this script
local EVENT_TYPE = "shortcut" -- the event we want (keyboard shortcut)

du.check_min_api_version("9.5.0", MODULE_NAME)

local separator = dt.configuration.running_os == "windows" and "\\" or "/"

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager
local script_data = {}

script_data.metadata = {
    name = "Resync XMP Files",
    purpose = "This script will help in syncing rating changes from XMP files",
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

local function readXMPFile(xmpFile)
    local file = io.open(xmpFile, "r")
    if not file then
        dt.print_log("Failed to open XMP file: " .. xmpFile)
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function extractRating(xmpText)
    if not xmpText then
        return nil
    end
    -- Format 1: <xmp:Rating>4</xmp:Rating>
    local rating = xmpText:match("<xmp:Rating>%s*(%d)%s*</xmp:Rating>")
    if rating then
        return rating
    end

    -- Format 2: xmp:Rating="4"
    rating = xmpText:match('xmp:Rating%s*=%s*"(%d)"')
    if rating then
        return rating
    end

    return nil
end

local function readRatingFromXMPAndSetOnImage(images)
    if #images == 0 then
        dt.print_log("No images provided for XMP reading.")
        return
    end
    for _, image in ipairs(images) do
        dt.print_log("Reading XMP for image: " .. image.filename)
        local xmpFile = image.path .. separator .. image.filename .. ".XMP"
	local f = io.open(xmpFile, "r")
	if f then
    	   f:close() -- Uppercase file exists, keep it
	else
	   -- Fallback to lowercase if uppercase is missing
    	   xmpFile = image.path .. separator .. image.filename .. ".xmp"
	end
        dt.print_log("XMP file path: " .. xmpFile)
        local xmpText = readXMPFile(xmpFile)
        local rating = extractRating(xmpText) or 0
        image.rating = rating
        dt.print_log("Image: " .. image.filename .. " Rating: " .. rating)
        dt.print_toast("Image: " .. image.filename .. " Rating: " .. rating)
    end
end

-- defensive cleanup: remove any previous registration with the same name/type
pcall(dt.destroy_event, EVENT_TYPE, EVENT_NAME)

-- register the event correctly
dt.register_event(EVENT_NAME, -- event name (unique id)
EVENT_TYPE, -- event type
function(event, shortcut)
    readRatingFromXMPAndSetOnImage(dt.gui.selection())
end, _("Resync rating from XMP") -- label shown in Shortcuts prefs
)

return script_data

