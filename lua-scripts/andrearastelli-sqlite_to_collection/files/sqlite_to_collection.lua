--[[
Darktable plugin to export, import and categorize images into specific tags.
Copyright (C) 2026  Andrea Rastelli

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

local Darktable <const> = require "darktable"
local DarktableUtilsFile <const> = require "lib/dtutils.file"

---@type table
local wg = {}


---@param MessageID string
---@return string
local function _(MessageID)
    return Darktable.gettext.gettext(MessageID)
end


---@param ExifDatetime string
---@return string, string, string, string, string, string
local function ExtractDateFromImageExif(ExifDatetime)
    local Year, Month, Day, Hour, Minute, Second = string.match(
	ExifDatetime, "(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
    return Year, Month, Day, Hour, Minute, Second
end


---@param FilePath string
---@return table
local function RetrieveFileData(FilePath)
    local FileDescriptor, Error = io.open(FilePath, "r")
    if not FileDescriptor then
        print("Unable to open the file "..FilePath.." to scan it's content.")
        print("Error: "..Error)
        return
    end

    local FileImages = {}
    for Line in FileDescriptor:lines() do
        table.insert(FileImages, Line)
    end

    FileDescriptor:close()

    return FileImages
end


---@param FileImages table
---@return table
local function FileDataToMapping(FileImages)
    local DateTimeMap = {}

    for _, DateTime in ipairs(FileImages) do
        IYear, IMonth, IDay, IHour, IMin, ISec = ExtractDateFromImageExif(DateTime)
        local ImageTime = os.time{
	    year=IYear, month=IMonth, day=IDay, hour=IHour, min=IMin, sec=ISec}
        ImageMonth = os.date("%Y:%m:%d %H:%M:%S", ImageTime)

        if DateTimeMap[ImageMonth] == nil then
            DateTimeMap[ImageMonth] = {}
        end

        table.insert(DateTimeMap[ImageMonth], DateTime)
    end

    return DateTimeMap
end


-- @param ImageDictionary table A table with DateTime keys mapping to lists of dates
-- @return table ImageFilters A table containing Darktable rule objects, each with:
--                            - item: "DT_COLLECTION_PROP_TIME"
--                            - data: "=" .. DateTime value
--                            - mode: "DT_LIB_COLLECT_MODE_OR"
--
-- @usage
-- local images = { ["2024-01-15"] = {...}, ["2024-01-16"] = {...} }
-- local filters = BuildFiltersFromImages(images)
-- -- filters now contains rule objects for each DateTime
local function BuildFiltersFromImages(ImageDictionary)
    local ImageFilters = {}
    
    for DateTime, ListOfDates in pairs(ImageDictionary) do
	local YearRule = Darktable.gui.libs.collect.new_rule()
	YearRule.item = "DT_COLLECTION_PROP_TIME"
	YearRule.data = "="..DateTime
	YearRule.mode = "DT_LIB_COLLECT_MODE_OR"
	table.insert(ImageFilters, YearRule)
    end

    return ImageFilters
end


---@param FilePath string
---@class BackgroundJob Darktable.types.dt_lua_backgroundjob_t
local function ScanFile(FilePath, BackgroundJob)
    wg.ProgressStatus.text = "Scanning ..."

    BackgroundJob.percent = 0.1

    local FileImages = RetrieveFileData(FilePath)
    local ImageDictionary = FileDataToMapping(FileImages)

    local ImageFilters = BuildFiltersFromImages(ImageDictionary)

    local AllFoundImages = {}

    local progress_increment = 1.0 / #ImageFilters
    local progress = 0.0

    local PreviousCollectionFilter = Darktable.gui.libs.collect.filter()
    
    for Idx, YearFilter in ipairs(ImageFilters) do
	Darktable.gui.libs.collect.filter({YearFilter})
	for ImageIdx, Image in ipairs(Darktable.collection) do
	    progress = progress + progress_increment
	    BackgroundJob.percent = progress
	    table.insert(AllFoundImages, Image)
	end
    end

    Darktable.gui.libs.collect.filter(PreviousCollectionFilter)

    wg.ProgressStatus.text = "Scanning Done!"
    wg.ProgressIndicator.text = "Finished Scanning Images"

    local Album2024Tag = Darktable.tags.find(wg.AlbumTagSelection.value)
    Darktable.print_log("Album tag: "..Album2024Tag.name)

    wg.ProgressStatus.text = "Assigning tag "..Album2024Tag.name

    for _, Image in ipairs(AllFoundImages) do
	Darktable.tags.attach(Album2024Tag, Image)
    end
    
    wg.ProgressStatus.text = "All images have been tagged!"

    BackgroundJob.percent = 1.0
    BackgroundJob.valid = false
end


local function CancelBackgroundJob(BackgroundJob)
    StopProcessing = true
    BackgroundJob.valid = false
end


local function GetAllAlbumTags()
    local AllAlbumTags = {}
    for idx, Tag in ipairs(Darktable.tags) do
        table.insert(AllAlbumTags, Tag.name)
    end

    return AllAlbumTags
end


local function GetAllYears()
    local Years = {}
    local CurrentYear = tonumber(os.date("%Y", os.time()))
    -- Saving original filter
    local PrevFilter = Darktable.gui.libs.collect.filter()
    for Year = 2000, CurrentYear do
	-- Build a filter to identify if there's
	-- any image for the selected year
	local YearRule = Darktable.gui.libs.collect.new_rule()
	YearRule.item = "DT_COLLECTION_PROP_TIME"
	YearRule.data = "="..Year
	YearRule.mode = "DT_LIB_COLLECT_MODE_AND"

	Darktable.gui.libs.collect.filter({YearRule})

	if #Darktable.collection > 0 then
	    table.insert(Years, Year)
	end
    end
    -- Restoring original filter
    Darktable.gui.libs.collect.filter(PrevFilter)
    return Years
end


local function ExportYearDataset(OutputFolder)
   local OutputFilename = string.format("%s/%s", OutputFolder, "test.csv")
   local BackgroundJob = Darktable.gui.create_job("Exporting CSV...", 0)
   print("Exporting data into: "..OutputFilename)

   local FileImageDB = io.open(OutputFilename, "w")
   for ImageIdx, Image in pairs(Darktable.collection) do
      BackgroundJob.percent = BackgroundJob.percent + ImageIdx / #Darktable.collection
      local LOG = string.format(
	 "%d,%s/%s,%s", Image.id, Image.path, Image.filename, Image.exif_datetime_taken)
      FileImageDB:write(LOG.."\n")
   end
   FileImageDB:close()
   BackgroundJob.valid = false

   print("Data Exported Successfully.")
end



local ScriptData = {}


ScriptData.metadata = {
   name = _("txt2Album"),
   purpose = _("Creates a tag with the name specified and collects all the images matching the ones in the input text file"),
   author = "Andrea Rastelli",
   help="TODO"
}


wg.LoadFileAction = Darktable.new_widget("file_chooser_button")
{
   title = _("Load TXT Source File"),
   value = "/home/",
   is_directory = false,
   tooltip = _("Enter the path to the file containing the image paths to build the album with"),
   changed_callback = function (self)
      local FileExtension = DarktableUtilsFile.get_filetype(self.value)
      if FileExtension ~= "txt" and FileExtension ~= "csv" then
	 Darktable.print("File type "..FileExtension.." is not valid. Please load a TXT or a CSV file.")
	 self.value = ""
	 return
      end
      local FileName = DarktableUtilsFile.get_filename(self.value)
      Darktable.print("Valid file: "..FileName)
   end
}


wg.ProgressIndicator = Darktable.new_widget("entry")
{
   text = "",
   editable = false
}


wg.ProgressStatus = Darktable.new_widget("entry")
{
   text = "...",
   editable = false
}


wg.StopProcessingButton = Darktable.new_widget("button")
{
   label = "Stop processing",
   clicked_callback = function(self)
      StopProcessing = true
      Darktable.print("Stopping image processing")
   end
}


wg.AlbumTagSelection = Darktable.new_widget("combobox")
{
   label = "Select Album",
   editable = false,
   table.unpack(GetAllAlbumTags())
}


wg.ExportFolderAction = Darktable.new_widget("file_chooser_button")
{
   title = _("Output CSV Folder"),
   value = "/home/",
   is_directory = true,
   tooltip = _("The path to the folder into which store the output CSV export"),
}


wg.ExportYearDataset = Darktable.new_widget("button")
{
   label = "Export CSV For selected year",
   clicked_callback = function(_)
      ExportYearDataset(wg.ExportFolderAction.value)
   end
}


TXT2ALBUM_Widget = Darktable.new_widget("box")
{
   orientation = "vertical",

   Darktable.new_widget("section_label")
   { 
      label = "IMPORT",
   },

   Darktable.new_widget("box")
   {
      orientation = "horizontal",

      Darktable.new_widget("label")
      {
	 label = _("File path"),
	 halign = "start"
      },

      wg.LoadFileAction
   },

   wg.AlbumTagSelection,

   wg.ProgressIndicator,
   wg.ProgressStatus,

   Darktable.new_widget("button")
   {
      label = _("Scan and Import"),
      tooltip = _("Execute the scan of the file and import the data to build the album"),
      clicked_callback = function(_)
	 local FilePath = wg.LoadFileAction.value
	 Darktable.print("Text path: "..FilePath)
	 local BackgroundJob = Darktable.gui.create_job("Scan and Import", 0, CancelBackgroundJob)
	 ScanFile(FilePath, BackgroundJob)
      end
   },

   wg.StopProcessingButton,

   Darktable.new_widget("separator"),

   Darktable.new_widget("section_label")
   {
      label = "EXPORT",
   },

   Darktable.new_widget("box")
   {
      orientation = "horizontal",
      
      Darktable.new_widget("label")
      {
	 label = _("Export CSV Folder"),
	 halign = "start"
      },
      
      wg.ExportFolderAction,
   },
   wg.ExportYearDataset,
}


Darktable.register_lib(
   "txt2Album",
   _("TXT 2 ALBUM"),
   true,			-- not expandable
   true,			-- resettable
   {
      [Darktable.gui.views.lighttable] = {
	 "DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100},
   },
   TXT2ALBUM_Widget
)


local function restart()
   Darktable.print_log("SQLite To Collection started.")
   Darktable.gui.libs["txt2Album"].visible = true
end

---@
local function destroy()
   Darktable.gui.libs["txt2Album"].visible = false
end

ScriptData.destroy = destroy
ScriptData.destroy_method = "hide"
ScriptData.restart = restart
ScriptData.show = restart

return ScriptData
