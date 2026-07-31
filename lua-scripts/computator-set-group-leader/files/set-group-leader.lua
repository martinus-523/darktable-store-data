local MODULE = "set-group-leader"

local dt = require "darktable"

local function toggle_global_toolbox_grouping()
	dt.gui.libs.global_toolbox.grouping = false
	dt.gui.libs.global_toolbox.grouping = true
end

local function set_leader(images)
	for _, image in ipairs(images) do
		if string.lower(string.sub(image.filename, -3)) == "dng" then
			image:make_group_leader()
		end
	end
	if dt.gui.libs.global_toolbox.grouping then
		-- toggle the grouping to make the new leader show
		toggle_global_toolbox_grouping()
	end
end

dt.register_event(MODULE .. "_active", "shortcut",
	function(event, shortcut)
		set_leader(dt.gui.action_images)
	end,
	"set dng files as group leaders"
)
