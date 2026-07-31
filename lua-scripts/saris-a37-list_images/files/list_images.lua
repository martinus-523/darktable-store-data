--[[

LIST IMAGE
a simple add-on to export a list of images in current collection to text file

AUTHOR
สาริศ ธนาโสภณ (t.saris@live.com)

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "list_images"

USAGE
* select the output string format
* select the seperator between each image's entry in the output text file
* set the target directory and output text file name
* click 'export'

LICENSE
GPLv2

]]

local dt = require "darktable"
local debug = require "darktable.debug"

local dt_enum = {}
dt_enum.dt_lib_collect_mode_t = {
	['DT_LIB_COLLECT_MODE_AND'] = "AND",
	['DT_LIB_COLLECT_MODE_OR'] = "OR",
	['DT_LIB_COLLECT_MODE_AND_NOT'] = "EXCEPT"
}
dt_enum.dt_collection_properties_t = {
	['DT_COLLECTION_PROP_FILMROLL'] = "film roll",
	['DT_COLLECTION_PROP_FOLDERS'] = "folder",
	['DT_COLLECTION_PROP_CAMERA'] = "camera",
	['DT_COLLECTION_PROP_TAG'] = "tag",
	['DT_COLLECTION_PROP_DAY'] = "capture date",
	['DT_COLLECTION_PROP_TIME'] = "capture time",
	['DT_COLLECTION_PROP_IMPORT_TIMESTAMP'] = "import time",
	['DT_COLLECTION_PROP_CHANGE_TIMESTAMP'] = "modification time",
	['DT_COLLECTION_PROP_EXPORT_TIMESTAMP'] = "export time",
	['DT_COLLECTION_PROP_PRINT_TIMESTAMP'] = "print time",
	['DT_COLLECTION_PROP_HISTORY'] = "history",
	['DT_COLLECTION_PROP_COLORLABEL'] = "color label",
	['DT_COLLECTION_PROP_TITLE'] = "title",
	['DT_COLLECTION_PROP_DESCRIPTION'] = "description",
	['DT_COLLECTION_PROP_CREATOR'] = "creator",
	['DT_COLLECTION_PROP_PUBLISHER'] = "publisher",
	['DT_COLLECTION_PROP_RIGHTS'] = "rights",
	['DT_COLLECTION_PROP_LENS'] = "lens",
	['DT_COLLECTION_PROP_FOCAL_LENGTH'] = "focal length",
	['DT_COLLECTION_PROP_ISO'] = "ISO",
	['DT_COLLECTION_PROP_APERTURE'] = "aperture",
	['DT_COLLECTION_PROP_FILENAME'] = "filename",
	['DT_COLLECTION_PROP_GEOTAGGING'] = "geotagging"
}

local li = {}

li.widgets = {}
li.configurations = {}

--tag selector disabled as the collection module should be used instead

--[[

li.widgets.tag_list = dt.new_widget("combobox"){
	label = "select a tag"
}

for _,tag in ipairs(dt.tags) do
	table.insert(li.widgets.tag_list,tag.name)
end

]]

--configure output

----image range

li.widgets.selected_only = dt.new_widget("check_button"){
	label = "include only selected image(s)",
	value = false,
	reset_callback = function(self) self.value = false end
}

----string format

li.widgets.string = dt.new_widget("combobox"){
	label = "string",
	[1] = "file name",
	[2] = "path and file name",
	selected = 0,
	reset_callback = function(self) self.selected = 0 end
}

------custom seperator

li.widgets.custom_string_seperator = dt.new_widget("entry"){
	placeholder = "custom string seperator",
	visible = false,
	editable = false,
	reset_callback = function(self) self.text = "" end
}

----seperator

li.widgets.seperator = dt.new_widget("combobox"){
	label = "seperator",
	[1] = "new line",
	[2] = "custom string",
	selected = 0,
	reset_callback = function(self) self.selected = 0 end,
	changed_callback = function(self)
		if(self.value == "custom string") then
			li.widgets.custom_string_seperator.editable = true
			li.widgets.custom_string_seperator.visible = true
		else
			li.widgets.custom_string_seperator.editable = false
			li.widgets.custom_string_seperator.visible = false
		end
	end
}

--destination

----use common parent directory as destination

li.widgets.common_parent_directory_destination = dt.new_widget("check_button"){
	label = "use common parent directory of selected filmroll(s) as destination",
	value = false,
	reset_callback = function(self) self.value = false end,
	clicked_callback = function(self)
		local filmroll_directories = {}
		for _,rule in ipairs(dt.gui.libs.collect.filter()) do
			if (rule.item == "DT_COLLECTION_PROP_FILMROLL" and rule.data ~= nil and rule.data ~= "") then table.insert(filmroll_directories, rule.data) end
		end
		local common_parent_directory_length
		if (#filmroll_directories == 0) then
			for _,filmroll in ipairs(dt.films) do table.insert(filmroll_directories, filmroll.path) end
		end
		if (#filmroll_directories == 1) then common_parent_directory_length = #filmroll_directories[1]
		elseif (#filmroll_directories > 1) then common_parent_directory_length = findCommonParentDirectoryLength(filmroll_directories, #filmroll_directories, '/') end
		if(self.value == true) then
			li.widgets.destination.value = filmroll_directories[1]:sub(1, common_parent_directory_length)
			li.widgets.common_parent_directory_destination_label.visible = true
			li.widgets.common_parent_directory_destination_label.label = filmroll_directories[1]:sub(1, common_parent_directory_length)
			li.widgets.destination.visible = false
		else
			li.widgets.common_parent_directory_destination_label.visible = false
			li.widgets.destination.visible = true
		end
	end
}

------find common parent directory length (adapted from https://rosettacode.org/wiki/Find_common_directory_path#C)

function findCommonParentDirectoryLength(directories, n, sep)
    local i, pos
    for pos = 1, #directories[1] do
        for i = 1, n do
            if directories[i]:sub(pos, pos) ~= "" and directories[i]:sub(pos, pos) == directories[1]:sub(pos, pos) then
                goto continue
            else
                -- backtrack
                repeat
                    pos = pos - 1
                until pos == 0 or directories[1]:sub(pos, pos) == sep
                return pos
            end
            ::continue::
        end
    end
    return 0
end

------show common parent directory if checked

li.widgets.common_parent_directory_destination_label = dt.new_widget("label"){
	visible = false
}

----destination folder

li.widgets.destination = dt.new_widget("file_chooser_button"){
	title = "Select a Folder",
	is_directory = true,
	visible = true,
	reset_callback = function(self) self.value = "" end
}

----file name

li.widgets.file_name = dt.new_widget("entry"){
	placeholder = "file name",
	editable = true,
	reset_callback = function(self) self.text = "" end
}

--export

li.widgets.export_button = dt.new_widget("button"){
	label = "export",
	clicked_callback = function()
		
		--checks for error(s)
		li.configurations.errors = "ERROR"
		if(li.widgets.seperator.value == "" or li.widgets.seperator.value == nil) then li.configurations.errors = li.configurations.errors.."\nseperator not set" end
		if(li.widgets.selected_only.value == true and next(dt.gui.selection()) == nil) then li.configurations.errors = li.configurations.errors.."\nset to include only selected photo(s) but no photo is selected" end
		if(li.configurations.errors ~= "ERROR") then
			dt.print(li.configurations.errors)
			return
		end

		--checks where default options could be applied
		li.configurations.default_options_applied = "APPLYING DEFAULT OPTION(S)"
		if(li.widgets.string.value == "" or li.widgets.string.value == nil) then
			local filmroll_directories = {}
			for _,rule in ipairs(dt.gui.libs.collect.filter()) do
				if (rule.item == "DT_COLLECTION_PROP_FILMROLL" and rule.data ~= nil and rule.data ~= "") then table.insert(filmroll_directories, rule.data) end
			end
			if(#filmroll_directories == 0 or #filmroll_directories > 1) then
				li.widgets.string.value = 2
				li.configurations.default_options_applied = li.configurations.default_options_applied.."\noutput string format not selected, defaulting to path and file name"
			elseif(#filmroll_directories == 1) then
				li.widgets.string.value = 1
				li.configurations.default_options_applied = li.configurations.default_options_applied.."\noutput string format not selected, defaulting to file name"
			end
		end
		if(li.widgets.destination.value == "" or li.widgets.destination.value == nil) then
			li.widgets.common_parent_directory_destination.value = true
			li.configurations.default_options_applied = li.configurations.default_options_applied.."\ndestination folder not set, defaulting to common parent directory"
		end
		if(li.widgets.file_name.text == "" or li.widgets.file_name.text == nil) then
			li.widgets.file_name.text = "list-images_"..os.date("%Y%m%d%H%M%S")
			li.configurations.default_options_applied = li.configurations.default_options_applied.."\nfile name not set, defaulting to list-images_datetime"
		end
		if(li.configurations.default_options_applied ~= "APPLYING DEFAULT OPTION(S)") then
			dt.print(li.configurations.default_options_applied)
		end

		--refresh common parent directory if checked
		if(li.widgets.common_parent_directory_destination.value == true) then
			li.widgets.common_parent_directory_destination.value = false
			li.widgets.common_parent_directory_destination.value = true
		end
		
		--writes output file
		output = io.open(li.widgets.destination.value.."/"..li.widgets.file_name.text,"w")
		
		----writes current collection module rules as header
		dt.print_log(tostring(output:write("COLLECTION RULES")))
		for _,rule in ipairs(dt.gui.libs.collect.filter()) do dt.print_log(tostring(output:write("\n"..dt_enum.dt_lib_collect_mode_t[rule.mode].."\t"..dt_enum.dt_collection_properties_t[rule.item]..":\t\""..rule.data.."\""))) end
		
		----writes list of photos
		dt.print_log(tostring(output:write("\rLIST OF PHOTOS\n")))
		li.configurations.seperator = {
			['new line'] = "\n",
			['custom string'] = li.widgets.custom_string_seperator.text
		}
		if(li.widgets.selected_only.value == false) then
			if(li.widgets.string.value == "path and file name") then
				for _,photo in ipairs(dt.collection) do dt.print_log(tostring(output:write(tostring(photo)..li.configurations.seperator[li.widgets.seperator.value]))) end
			elseif(li.widgets.string.value == "file name") then
				for _,photo in ipairs(dt.collection) do dt.print_log(tostring(output:write(tostring(photo.filename)..li.configurations.seperator[li.widgets.seperator.value]))) end
			else return
			end
		elseif(li.widgets.selected_only.value == true) then
			dt.print_log(tostring(output:write("(selected only)\n")))
			if(li.widgets.string.value == "path and file name") then
				for _,photo in ipairs(dt.gui.selection()) do dt.print_log(tostring(output:write(tostring(photo)..li.configurations.seperator[li.widgets.seperator.value]))) end
			elseif(li.widgets.string.value == "file name") then
				for _,photo in ipairs(dt.gui.selection()) do dt.print_log(tostring(output:write(tostring(photo.filename)..li.configurations.seperator[li.widgets.seperator.value]))) end
			else return
			end
		end
		
		--finishes task
		output:close()
		dt.print("exported to "..li.widgets.destination.value.."/"..li.widgets.file_name.text)
		
	end
}

--main

li.widgets.main_box = dt.new_widget("box"){
	orientation = "vertical",
	--li.widgets.tag_list,
	dt.new_widget("label"){ label = "output configuration" },
	li.widgets.selected_only,
	li.widgets.string,
	li.widgets.seperator,
	li.widgets.custom_string_seperator,
	dt.new_widget("label"){ label = "export destination" },
	li.widgets.common_parent_directory_destination,
	li.widgets.common_parent_directory_destination_label,
	li.widgets.destination,
	li.widgets.file_name,
	li.widgets.export_button
}

dt.register_lib("li","list images",true,true,{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_BOTTOM",20}},li.widgets.main_box)
