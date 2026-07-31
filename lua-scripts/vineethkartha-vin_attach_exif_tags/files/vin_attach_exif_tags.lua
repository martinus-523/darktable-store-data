local dt = require "darktable"
local du = require "lib/dtutils"

local MODULE_NAME = "ExifTAGAndCopyrightGenerator" -- make sure this is unique, no spaces, no special characters   
local EVENT_NAME = "exiftagandcopyrightgenerator" -- must be unique for this script
local EVENT_TYPE = "shortcut" -- the event we want (keyboard shortcut)

du.check_min_api_version("7.0.0", MODULE_NAME)

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager
local script_data = {}

script_data.metadata = {
    name = _("Generate tags from EXIF"),
    purpose = _("Generate appropriate tags for images based on exif "),
    author = "Vineeth Kartha",
    help = "abcd" -- this seems important
}

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    dt.destroy_event(EVENT_NAME, EVENT_TYPE)
    dt.print_log("Cleaned up " .. EVENT_NAME)
end

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
script_data.destroy = destroy

--- Generates a list of tags from the EXIF data of an image.
-- Extracts the camera model, lens information, and a folder identifier from the image's path and EXIF metadata.
-- All spaces in the generated tags are replaced with underscores.
-- @param image table: An image object containing EXIF metadata and a file path.
-- @return table: A list of tags (strings) derived from the image's EXIF model, lens, and folder.
local function generate_tags_from_exif(image)

    -- Get location/occasion based on the folder name to be added as tag
    -- This is possible because I use a naming convention for my folders
    -- Extract the last folder name from the image path
    local job_name = image.path:match("([^/\\]+)[/\\]?$")
    -- Remove the leading two digits and underscore if present (e.g., "12_foldername" -> "foldername")
    local folder = job_name and job_name:match("^%d%d_(.+)$") or ""
    -- I use the location of the place as my folder names
    -- if you use something else, modify this line
    local location = folder or ""

    -- Get camera model and lens information from EXIF data
    local full_lens_name = image.exif_lens
    local exif_model = image.exif_model or ""
    local short_lens_name = full_lens_name and (full_lens_name:match("^(.-)mm") or full_lens_name) or ""

    local camera_maker = image.exif_maker or ""
    -- Create tags list based on the information extracted
    local tags = {camera_maker, exif_model, short_lens_name, location}
    -- replace all spaces with _
    -- replace all spaces with _
    for index, tag in ipairs(tags) do
        if tag ~= nil then
            tags[index] = tag:gsub("%s+", "_")
        else
            tags[index] = ""
        end
    end
    for index, tag in ipairs(tags) do
        tags[index] = tag:gsub("%s+", "_")
    end
    return tags
end

local function add_copyright_to_image(image)
    local exif_date_time = image.exif_datetime_taken
    if not exif_date_time then
        image.rights = " Vineeth Kartha. All rights reserved."
    end
    local _, _, _, _, yy = string.find(exif_date_time, "(%d%d)/(%d%d)/(%d%d)")
    if yy then
        -- assuming this will be run on images taken after 2000
        yy = tostring(tonumber(yy) + 2000)
    else
        yy = os.date("%Y") -- fallback to current year if EXIF date is not available      
    end
    local copyright_info = "Copyright " .. yy .. " Vineeth Kartha. All rights reserved."
    dt.print_log("Image rights " .. copyright_info)
    image.rights = copyright_info
end

local function generate_exif_tags_and_attach(image)
    local tags = generate_tags_from_exif(image)
    for _, tag in ipairs(tags) do
        dt.print_log("Attaching tag " .. tag .. " to image " .. image.filename)
        local dt_tag = dt.tags.create(tag) -- create or fetch existing tag    
        dt.tags.attach(dt_tag, image) -- attach tag object to image
    end
end

local function attach_tags_and_copyright(images)
    local job = dt.gui.create_job('Attaching tags and copyright to ' .. #images .. " images", true)
    for index, image in ipairs(images) do
        job.percent = index / #images
        dt.print_log(job.percent)
        generate_exif_tags_and_attach(image)
        add_copyright_to_image(image)
    end
    job.valid = false
    dt.print("Attached tags to " .. #images .. " images")
    dt.print_log("Attached tags to " .. #images .. " images")

end
-- remove this code after debugging
-- attach_tags_and_copyright(dt.gui.selection())

-- defensive cleanup: remove any previous registration with the same name/type
pcall(dt.destroy_event, EVENT_NAME, EVENT_TYPE)

dt.register_event(EVENT_NAME, -- event name (unique id)
EVENT_TYPE, -- event type
function(event, shortcut)
    attach_tags_and_copyright(dt.gui.selection())
end, _("attach tags from exif and copyright") -- label shown in Shortcuts prefs
)

return script_data
