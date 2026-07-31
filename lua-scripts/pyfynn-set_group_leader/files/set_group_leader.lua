local dt = require "darktable"

local function set_selected_as_group_leaders(event, shortcut)
  local images = dt.gui.selection()

  for _, image in ipairs(images) do
    if #image:get_group_members() > 1 then
      image:make_group_leader()
    end
  end

end

-- Register the shortcut and action
dt.register_event(
  "set_selected_as_group_leaders",
  "shortcut",
  set_selected_as_group_leaders,
  "Set Selected Images as Group Leaders"
)
