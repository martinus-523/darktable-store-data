--[[
  darktable is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  darktable is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
  DESCRIPTION
    nind_denoise_rl.lua - NIND-denoise then Richardson-Lucy output sharpening using GMic

    This script provides a new target storage "NIND-denoise RL".
    Images exported will be denoised with NIND-denoise then sharpened with GMic's RL deblur

  REQUIRED SOFTWARE
    NIND-denoise: https://github.com/trougnouf/nind-denoise
    GMic command line interface (CLI) https://gmic.eu/download.shtml
    exiftool to copy EXIF to the final image

  USAGE
    * start the script "nind_denoise_rl" from Script Manager
    * in lua preferences:
      - select the nind_denoise directory (containing src/denoise.py)
      - select GMic cli executable (for RL-deblur)
      - select the exiftool cli executable (optional, to copy EXIF to final image)
    * from "export selected", choose "nind-denoise RL" as target storage
    * for "format options", either TIFF 8-bit or 16-bit is recommended
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"
local ds = require "lib/dtutils.string"

-- module name
local MODULE_NAME = "nind_denoise_rl"

-- Error codes
local NDERR = {
  CMD_FAILURE = 1001,
  MISSING_BINARY = 1002,
  TEMP_FILE = 1003,
  VAR_SUBSTITUTION = 1004,
  METADATA_FAILURE = 1005  -- Test-visible error code
}

-- check API version
du.check_min_api_version("7.0.0", MODULE_NAME)

-- translation
local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
  end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = "Nind Denoise + RL",
  purpose = "AI denoise of RAW images with optional Richardson-Lucy output sharpening using GMic."
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

-- OS compatibility
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"
local USER = os.getenv("USERNAME")
local HOME = os.getenv(dt.configuration.running_os == "windows" and "HOMEPATH" or "HOME")
local PICTURES = HOME .. PS .. dt.configuration.running_os == "windows" and _("My Pictures") or _("Pictures")
local DESKTOP = HOME .. PS .. "Desktop"

-- read preferences with default value
if not dt.preferences.read(MODULE_NAME, "initialized", "bool") then
  dt.preferences.write(MODULE_NAME, "output_pattern", "string", "$(FILE_FOLDER)/$(FILE_NAME)_denoised")
  dt.preferences.write(MODULE_NAME, "output_format", "integer", 1)
  dt.preferences.write(MODULE_NAME, "jpg_quality", "integer", 95)
  dt.preferences.write(MODULE_NAME, "rl_deblur_enabled", "bool", false)
  dt.preferences.write(MODULE_NAME, "sigma", "float", 1)
  dt.preferences.write(MODULE_NAME, "iterations", "integer", 10)
  dt.preferences.write(MODULE_NAME, "denoise_only_import_to_dt_switch", "bool", true)

  dt.preferences.write(MODULE_NAME, "initialized", "bool", true)
end

-- Auto-detect gmic executable
local function find_executable(name)
  local possible_paths = {
    PS.."usr"..PS.."bin",
    PS.."usr"..PS.."local"..PS.."bin",
    PS.."opt"..PS.."local"..PS.."bin",
    HOME..PS..".local"..PS.."bin"
  }

  for _, path in ipairs(possible_paths) do
    local full_bin = path..PS..name
    local f = io.open(full_bin, "r")
    if f then
      f:close()
      return full_bin
    end
  end

  -- Try using 'which' command as fallback
  local handle = io.popen("which "..name.." 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result ~= "" then
      return result:gsub("%s+$", "")  -- trim whitespace
    end
  end

  return name -- fallback to just the command name, hoping it's in PATH
end

-- namespace variable
local NDRL = {};

-- update configuration widget
local function output_format_changed()
  if not NDRL.output_format or NDRL.output_format.selected == nil then
    return true
  end

  if NDRL.jpg_quality_slider then
    if NDRL.output_format.value == "JPG" then
      NDRL.jpg_quality_slider.visible = true
    else
      NDRL.jpg_quality_slider.visible = false
    end
  end

  dt.preferences.write(MODULE_NAME, "output_format", "integer", NDRL.output_format.selected)
end

local function rl_deblur_changed()
  if not NDRL.rl_deblur_switch then
    return true
  end
  local val = NDRL.rl_deblur_switch.value
  if NDRL.sigma_slider then
      NDRL.sigma_slider.visible = val
  end
  if NDRL.iterations_slider then
      NDRL.iterations_slider.visible = val
  end

  dt.preferences.write(MODULE_NAME, "rl_deblur_enabled", "bool", val)
end

local function denoise_only_changed()
  if not NDRL.denoise_only_import_to_dt_switch then
    return true
  end
  local val = NDRL.denoise_only_import_to_dt_switch.value
  if NDRL.rl_deblur_switch then
      NDRL.rl_deblur_switch.sensitive = not val
  end
  if NDRL.sigma_slider then
      NDRL.sigma_slider.sensitive = not val
  end
  if NDRL.iterations_slider then
      NDRL.iterations_slider.sensitive = not val
  end
  if NDRL.jpg_quality_slider then
	NDRL.jpg_quality_slider.sensitive = not val
  end
  dt.preferences.write(MODULE_NAME, "denoise_only_import_to_dt_switch", "bool", val)
end


-- Helper function to check if file exists
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Forward declaration - will be defined after widgets
local check_environment

NDRL.output_pattern = dt.new_widget("entry") {
    tooltip = ds.get_substitution_tooltip(),
    placeholder = _("enter pattern") .. " $(FILE_FOLDER)/$(FILE_NAME)",
    editable = true,
  }

NDRL.output_format = dt.new_widget("combobox") {
    label = _("output format"),
    editable = false,
    _("JPG"),
    _("TIF (16-bit)"),
    _("TIFF (32-bit)"),
    changed_callback = function(self)
      output_format_changed()
    end
  }

NDRL.jpg_quality_slider = dt.new_widget("slider") {
    label = _("output jpg quality"),
    tooltip = _("Quality of the output JPEG file (70-100)"),
    soft_min = 70,
    soft_max = 100,
    hard_min = 70,
    hard_max = 100,
    step = 1,
    digits = 0,
  }

NDRL.rl_deblur_switch = dt.new_widget("check_button") {
    label = _("apply RL deblur"),
    tooltip = _("enable Richardson-Lucy sharpening"),
    clicked_callback = function(self)
      rl_deblur_changed()
    end
  }

NDRL.sigma_slider = dt.new_widget("slider") {
    label = _("sigma"),
    tooltip = _("controls the width of the blur that's applied"),
    soft_min = 0.3,
    soft_max = 2.0,
    hard_min = 0.0,
    hard_max = 3.0,
    step = 0.05,
    digits = 2,
    sensitive = NDRL.rl_deblur_switch.value
  }

NDRL.iterations_slider = dt.new_widget("slider") {
    label = _("iterations"),
    tooltip = _("increase for better sharpening, but slower"),
    soft_min = 0,
    soft_max = 100,
    hard_min = 0,
    hard_max = 100,
    step = 5,
    digits = 0,
    sensitive = NDRL.rl_deblur_switch.value
  }

NDRL.denoise_only_import_to_dt_switch = dt.new_widget("check_button") {
    label = _("Only denoise + import & stack image"),
    tooltip = _("Only apply denoising and automatically import denoised image back into darktable library and group with original"),
    clicked_callback = function(self)
      denoise_only_changed()
    end
  }

-- Environment status label
NDRL.env_status = dt.new_widget("label") {
    label = _("Environment: Checking...")
}

-- Define check_environment function (was forward declared earlier)
check_environment = function()
    local denoise_dir = dt.preferences.read(MODULE_NAME, "nind_denoise_dir", "string")

    if denoise_dir == "" or denoise_dir == nil then
        NDRL.env_status.label = _("Environment: Not configured")
        return false
    end

    -- Check if venv exists by checking for the directory
    local venv_python = denoise_dir .. "/.venv/bin/python"

    if not file_exists(venv_python) then
        NDRL.env_status.label = _("Environment: ⚠ Not set up")
        return false
    end

    -- Check if torch is installed
    local torch_check = string.format("%s -c 'import torch' 2>/dev/null", venv_python)
    local result = dtsys.external_command(torch_check)

    if result == 0 then
        NDRL.env_status.label = _("Environment: ✓ Ready")
        return true
    else
        NDRL.env_status.label = _("Environment: ⚠ Incomplete")
        return false
    end
end

-- Supported export formats
local function supported(storage, img_format)
  -- we don't use the exported file at all
  return false
end

-- Helper function to escape shell arguments
local function escape_shell_arg(arg)
  if dt.configuration.running_os == "windows" then
    -- Windows escaping: wrap in quotes and escape internal quotes
    return '"' .. arg:gsub('"', '""') .. '"'
  else
    -- Unix/Linux escaping: wrap in single quotes and escape single quotes
    return "'" .. arg:gsub("'", "'\\''") .. "'"
  end
end

-- Fallback implementations for dtsys.* functions
if not dtsys.escape_shell_arg then
  dtsys.escape_shell_arg = escape_shell_arg
end

if not dtsys.external_command then
  dtsys.external_command = function(cmd)
    return os.execute(cmd)
  end
end

-- Fallback for dt.log_error if it doesn't exist
if not dt.log_error then
  dt.log_error = function(msg)
    dt.print_log("ERROR: " .. msg)
    dt.print("ERROR: " .. msg)
  end
end

if not dt.log_info then
  dt.log_info = function(msg)
    dt.print(msg)
    dt.print_log("INFO: " .. msg)
  end
end


local function store(storage, image, img_format, temp_name, img_num, total, hq, extra)
  local sidecar = image.sidecar
  local image_path = image.path..PS..image.filename
  dt.print_log('exporting image: '..image_path)

  -- Determine output file extension based on format choice
  local file_ext
  if not extra.output_format then
    dt.log_error(string.format("[NDERR-%d] Invalid output format configuration", NDERR.CMD_FAILURE))
    return false
  end
  if extra.output_format == 1 then
    file_ext = "jpg"
  elseif extra.output_format == 2 then
    file_ext = "tif"
  else
    file_ext = "tiff"
  end

  -- Determine output path - use same directory as source image by default
  local new_name
  if extra.output_pattern ~= "" then
    ds.build_substitute_list(image, img_num, extra.output_pattern, USER, PICTURES, HOME, DESKTOP)
    new_name = ds.substitute_list(extra.output_pattern)
    if new_name == -1 then
      dt.log_error(string.format("[NDERR-%d] Variable substitution failed", NDERR.VAR_SUBSTITUTION))
      return false
    end
    ds.clear_substitute_list()
    new_name = new_name.."."..file_ext
  else
    -- Default: output to same directory as source image
    new_name = image.path..PS..df.get_basename(temp_name).."."..file_ext
  end

  dt.print_log('new_name: '..new_name)

  -- Error handler for command execution
  local function handle_command_error(err)
    dt.log_error(string.format("[NDERR-%d] Command failed: %s", NDERR.CMD_FAILURE, err))
    if extra.debug_mode then
      dt.log_error(debug.traceback())
    end
    return false
  end

  -- Log processing options for debugging
  dt.print_log("RL deblur enabled: " .. tostring(extra.rl_deblur_enabled))
  dt.print_log("Only denoise and import image: " .. tostring(extra.denoise_only_import_to_dt_switch))

  -- Step 3: Build denoise.py command - pass full filepath
  local denoise_cmd = extra.nind_denoise.." -o " .. dtsys.escape_shell_arg(new_name) ..
                        " --sidecar "..dtsys.escape_shell_arg(sidecar)..
                        " --extension "..file_ext..
                        " --quality "..extra.jpg_quality_str

  -- Add RL deblur parameters if enabled
  if extra.rl_deblur_enabled then
    denoise_cmd = denoise_cmd.." --sigma="..extra.sigma_str..
                               " --iterations="..extra.iterations_str
  else
    denoise_cmd = denoise_cmd.." --no_deblur"
  end

  if extra.denoise_only_import_to_dt then
    denoise_cmd = denoise_cmd.." --only-denoise --keep-denoised"
  end

  if extra.debug_mode then
    denoise_cmd = denoise_cmd.." --debug"
  end

  -- Add input file
  denoise_cmd = denoise_cmd.." "..dtsys.escape_shell_arg(image_path)

  dt.print_log("Denoise command: "..denoise_cmd)

  local success, result = xpcall(function()
    return dtsys.external_command(denoise_cmd)
  end, handle_command_error)

  if not success or result ~= 0 then
    dt.log_error(_("[NDERR-1001] Denoise/deblur processing failed"))
    return false
  end

  if not file_exists(new_name) then
    dt.log_error(_("Python output not found: ") .. new_name)
    return false
  end

  dt.print_log("Python output verified at: " .. new_name)

  -- Import to darktable and group with original
  if extra.denoise_only_import_to_dt then
    local denoised_image = new_name
    if not file_exists(denoised_image) then
        dt.log_error(_("Denoised output not found: ") .. denoised_image)
        return false
    end

    local success, imported_or_err = pcall(function()
      return dt.database.import(denoised_image)
    end)

    if success then
      local imported_img = imported_or_err
      -- Group with original image
      local group_success, group_err = pcall(function()
        imported_img:group_with(image)
        image:make_group_leader()
      end)

      if group_success then
        dt.log_info(_("Imported and grouped: ")..denoised_image)
      else
        dt.log_error(_("Import succeeded but grouping failed: ")..tostring(group_err))
      end
    else
      dt.log_error(_("Failed to import to darktable: ")..tostring(imported_or_err))
      -- Don't fail the entire export if import fails
    end
  end

  dt.log_info(_("Successfully exported image: ")..new_name)
end

-- script_manager integration

local function destroy()
  dt.destroy_storage(MODULE_NAME)
end

-- UI widgets
local storage_widget = dt.new_widget("box") {
  orientation = "vertical",
  dt.new_widget("section_label") { label = _("Processing Options") },
  NDRL.rl_deblur_switch,
  NDRL.sigma_slider,
  NDRL.iterations_slider,
  dt.new_widget("section_label") { label = _("Output Settings") },
  NDRL.output_pattern,
  NDRL.output_format,
  NDRL.jpg_quality_slider,
  NDRL.denoise_only_import_to_dt_switch,
  dt.new_widget("section_label") { label = _("Environment Setup") },
  NDRL.env_status,
}

-- Setup export
local function initialize(storage, img_format, image_table, high_quality, extra)
  -- write preferences (that are not written on every change)
  dt.preferences.write(MODULE_NAME, "output_pattern", "string", NDRL.output_pattern.text)
  dt.preferences.write(MODULE_NAME, "jpg_quality", "integer", NDRL.jpg_quality_slider.value)
  dt.preferences.write(MODULE_NAME, "sigma", "float", NDRL.sigma_slider.value)
  dt.preferences.write(MODULE_NAME, "iterations", "integer", NDRL.iterations_slider.value)

  -- Read preferences (validation removed to prevent initialization failures)
  local denoise_dir = dt.preferences.read(MODULE_NAME, "nind_denoise_dir", "string")
  local dt_exe = dt.preferences.read(MODULE_NAME, "darktable_cli_exe", "string")
  local gmic_exe = dt.preferences.read(MODULE_NAME, "gmic_exe", "string")

  -- Build venv activation command based on OS
  local activate_cmd = ""
  if dt.configuration.running_os == "windows" then
    activate_cmd = "call \"" .. denoise_dir .. "\\.venv\\Scripts\\activate.bat\" && "
  else
    activate_cmd = "source \"" .. denoise_dir .. "/.venv/bin/activate\" && "
  end

  local cmd = activate_cmd .. "python3 \"" .. denoise_dir .. "/src/denoise.py\""
  extra.nind_denoise  = cmd .. " --dt=\""..dt_exe.."\" --gmic=\""..gmic_exe.."\""

  -- output options
  extra.output_format = NDRL.output_format.selected
  extra.output_pattern = NDRL.output_pattern.text
  extra.jpg_quality_str = tostring(NDRL.jpg_quality_slider.value)
  extra.rl_deblur_enabled = NDRL.rl_deblur_switch.value
  extra.sigma_str = tostring(NDRL.sigma_slider.value)
  extra.iterations_str = tostring(NDRL.iterations_slider.value)
  extra.denoise_only_import_to_dt = NDRL.denoise_only_import_to_dt_switch.value
  extra.debug_mode = dt.preferences.read(MODULE_NAME, "debug_mode", "bool")

end

-- Register storage
dt.register_storage(MODULE_NAME, _("Nind+RL"), store, nil, supported, initialize, storage_widget)

-- Register preferences
dt.preferences.register(MODULE_NAME, "nind_denoise_dir", "string",
 _ ("NindRL: nind_denoise directory"),
 _ ("directory containing the nind-denoise repository"), "")

dt.preferences.register(MODULE_NAME, "darktable_cli_exe", "file",
 _ ("NindRL: darktable-cli executable"),
 _ ("select executable for darktable command line "), find_executable("darktable-cli"))

dt.preferences.register(MODULE_NAME, "gmic_exe", "file",
 _ ("NindRL: GMic executable"),
 _ ("select executable for GMic command line "), find_executable("gmic"))

dt.preferences.register(MODULE_NAME, "debug_mode", "bool",
 _ ("NindRL: Enable debug mode"),
 _ ("Enable verbose logging and stack traces"), false)

-- Initialize UI from conf keys
NDRL.output_pattern.text = dt.preferences.read(MODULE_NAME, "output_pattern", "string")
NDRL.output_format.selected = dt.preferences.read(MODULE_NAME, "output_format", "integer")
NDRL.jpg_quality_slider.value = dt.preferences.read(MODULE_NAME, "jpg_quality", "integer")
NDRL.rl_deblur_switch.value = dt.preferences.read(MODULE_NAME, "rl_deblur_enabled", "bool")
NDRL.sigma_slider.value = dt.preferences.read(MODULE_NAME, "sigma", "float")
NDRL.iterations_slider.value = dt.preferences.read(MODULE_NAME, "iterations", "integer")
NDRL.denoise_only_import_to_dt_switch.value =  dt.preferences.read(MODULE_NAME, "denoise_only_import_to_dt_switch", "bool")
output_format_changed()
rl_deblur_changed()
denoise_only_changed()

-- Check environment health on startup
check_environment()

-- script_manager integration
script_data.destroy = destroy

return script_data

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
