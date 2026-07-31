--[[

    uncrop.lua - plugin for Darktable

    Copyright (C) 2026 andhet.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
    uncrop - uncrop selected image(s)

    This shortcut uncrops the selected images.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * exiftool
]]

local dt = require("darktable")
local du = require("lib/dtutils")

local gettext = dt.gettext.gettext

local exiftool = "/usr/bin/vendor_perl/exiftool"

local function _(msgid)
	return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
	name = _("uncrop"),
	purpose = _("uncrop Ricoh / Pentax images"),
	author = "andhet",
	help = "none",
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

du.check_min_api_version("7.0.0", "uncrop")

local function is_vertical(file)
	local cmd = string.format('%s -Orientation "%s"', exiftool, file)
	local f = assert(io.popen(cmd, "r"))
	local s = assert(f:read("*a"))
	f:close()
	return string.find(s, "Rotate") ~= nil
end

local function uncrop_pentax_k1(image)
	local filename = image.path .. "/" .. image.filename
	image.exif_crop = 1.0
	local cmd = string.format(
		'%s -overwrite_original -DefaultCropOrigin="8 10" -DefaultCropSize="7360 4912" "%s"',
		exiftool,
		filename
	)
	local ok = os.execute(cmd)
	if ok then
		dt.print("exiftool finished")
		dt.database.duplicate(image)
		dt.database.delete(image)
	else
		dt.print_error("exiftool command failed")
	end
end

local function uncrop_ricoh_gr3s(image)
	local filename = image.path .. "/" .. image.filename
	-- local vertical = is_vertical(filename)
	-- dt.print(tostring(vertical))

	image.exif_crop = 1.5
	local cmd = string.format(
		'%s -overwrite_original -DefaultCropOrigin="10 12" -DefaultCropSize="6000 4000" "%s"',
		exiftool,
		filename
	)
	local ok = os.execute(cmd)
	if ok then
		dt.print("exiftool finished")
		dt.database.duplicate(image)
		dt.database.delete(image)
	else
		dt.print_error("exiftool command failed")
	end
end

local function uncrop(images)
	for _, image in ipairs(images) do
		local camera = image.exif_model

		if string.find(camera, "K-1") then
			uncrop_pentax_k1(image)
		elseif string.find(camera, "GR III") then
			uncrop_ricoh_gr3s(image)
		else
			dt.print(camera .. " not supported")
		end
	end
end

local function destroy()
	dt.destroy_event("uncrop", "shortcut")
	dt.gui.libs.image.destroy_action("uncrop")
end

script_data.destroy = destroy

dt.gui.libs.image.register_action("uncrop", _("uncrop"), function(event, images)
	uncrop(images)
end, _("uncrop"))

dt.register_event("uncrop", "shortcut", function(event, shortcut)
	uncrop(dt.gui.action_images)
end, _("uncrop"))

return script_data
