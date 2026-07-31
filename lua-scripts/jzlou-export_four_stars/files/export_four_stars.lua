--[[
--This script solves a problem that I have of shooting both raw and jpg images in my workflow.
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"

local function destroy()
   -- nothing to destroy
end

-- debug function
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function filter_images_by_rating(collection, target_rating)
   local selected_images = {}

   for k, v in pairs(collection) do
      -- nothing for now... TODO
   end -- iterating over selection
end

function get_file_name(fname) -- from something like DSCF0001.RAF
   for substr in string.gmatch(fname, "([^.]+)") do
      return substr
   end
end

local script_data = {}
script_data.destroy = destroy

dt.print_log('.................. script call STARTS .................. ')
local collection = dt.collection
dt.print_log("DEBUG: Working with this object: " .. dump(collection))

dt.print_log("DEBUG: Creating export directory....")
local this_dir = collection[1].path
local export_dir = this_dir .. "\\four_star_jpgs"

-- NOTE that the following command does not work out of the box.
-- It required a change to the file lua-scripts/lib/dtutils/file.lua to enable
-- string literals-based mkdir because I use folders with spaces in them to make
-- them more readable for me.
df.mkdir(export_dir)

dt.print_log("DEBUG: Looking for four star images in this collection.")
for i, image in ipairs(collection) do
   if image.rating == 4 then
      local this_filename = get_file_name(image.filename)
      dt.print_log("DEBUG: Found a four star: " .. this_filename)
      jpg_path = image.path .. "\\" .. this_filename .. ".jpg"
      dt.print_log("--DEBUG: Moving this file: " .. jpg_path)
      new_jpg_path = export_dir .. "\\" .. this_filename .. ".jpg"
      dt.print_log("--DEBUG: To this location: " .. new_jpg_path)
      if df.file_move(jpg_path, new_jpg_path) then -- this is the magic
         dt.print_log("DEBUG: Moved " .. this_filename .. " successfully")
      else
         dt.print_log("DEBUG: Whoopsies on " .. this_filename)
      end
   end -- found a 4
end -- searching this collection

dt.print_log("DEBUG: All set!")
dt.print_log('.................. script call ENDS .................. ')

return script_data