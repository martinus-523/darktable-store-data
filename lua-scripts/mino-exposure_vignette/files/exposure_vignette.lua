local dt = require "darktable"

local function exposure_vignette(event, shortcut)

-- Go to Active modules page
dt.gui.action("lib/modulegroups/active modules", "", "on", 1.000)

-- Create new instance, add preset and activate ellipse mask
dt.gui.action("iop/exposure", "instance", "new", 1.000, 1)
dt.gui.action("iop/exposure/preset/vignette", 1.000, 2)
dt.gui.action("iop/blend/shapes/add ellipse", "", "toggle", 1.000)

end

dt.register_event("exposure_vignette",
                  "shortcut",
                  exposure_vignette,
                  "Create new exposure instance, apply vignette preset and select ellipse mask")
