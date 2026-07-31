--[[
title: My Utility Module
description: Internal helper functions for other scripts
hidden: true
]] local dt = require "darktable"

local UTILS = {}
--- Converts the given image to a temporary JPEG file.
-- This function creates a temporary file with a ".jpg" extension,
-- exports the provided image to this file in JPEG format using Darktable's export functionality,
-- and logs the export process. The path to the temporary JPEG file is returned.
-- @param image The image object to be exported as a JPEG.
-- @return string The file path to the temporary JPEG image.
function UTILS.convert_to_temp_jpg(image)
    local temp_file = os.tmpname() .. ".jpg"
    local jpeg_exporter = dt.new_format("jpeg")
    jpeg_exporter.quality = 50
    -- the image size setting was done to fix a hang in darktable 5.6
    jpeg_exporter.max_width = image.width
    jpeg_exporter.max_height = image.height
    dt.print_log("Exporting: " .. temp_file)
    jpeg_exporter:write_image(image, temp_file, true)
    dt.print_log("Exported to: " .. temp_file)
    return temp_file
end

--[[
  Sanitizes a given tag string by performing the following operations:
  1. Converts all characters in the tag to lowercase.
  2. Removes all special characters, retaining only alphanumeric characters and underscores.
  3. Trims leading and trailing whitespace from the tag.

  @param tag (string): The input tag string to be sanitized.
  @return (string): The sanitized tag string, suitable for use as a standardized identifier.
]]
function UTILS.sanitize_text(tag)
    -- Convert to lowercase
    tag = tag:lower()
    -- Remove special characters, keep only alphanumeric and underscores
    tag = tag:gsub("[^%w_]", "")
    -- Trim whitespace
    tag = tag:match("^%s*(.-)%s*$")
    return tag
end

-- Detect OS type
local function is_windows()
    local path_sep = package.config:sub(1, 1)
    return path_sep == "\\"
end

--- Checks if the Ollama application is installed on the system.
-- This function attempts to execute the `ollama --version` command and suppresses its output.
-- It determines the appropriate null device based on the operating system.
-- @return boolean Returns true if Ollama is installed (command executes successfully), false otherwise.
-- Return true if Ollama is installed, false otherwise
local function is_ollama_installed()
    local null_device = is_windows() and "nul" or "/dev/null"
    local cmd = "ollama --version > " .. null_device .. " 2>&1"

    local success, _, code = os.execute(cmd)
    -- Lua 5.1: returns status code (0 = success)
    -- Lua 5.2+: returns true/nil and "exit"/"signal" with code
    if type(success) == "number" then
        return success == 0
    else
        return success == true and code == 0
    end
end

--- Retrieves the version string of the installed Ollama application.
-- Executes the "ollama --version" command and returns its output as a string,
-- with any newline characters removed. If the command fails or no output is
-- available, returns nil.
-- @return string|nil The Ollama version string, or nil if not available.
-- Return version string if available
local function get_ollama_version()
    local cmd = "ollama --version"
    local handle = io.popen(cmd)
    if not handle then
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    if result and #result > 0 then
        return result:gsub("\n", "")
    end
    return nil
end

--- Calls the Ollama command-line tool with the specified model, prompt, and attachment.
-- Checks if Ollama is installed before attempting to run the command.
-- Logs the command execution and prints status messages to the user.
-- @param model string: The name of the Ollama model to use.
-- @param prompt string: The prompt to send to the model.
-- @param attachment string: Additional attachment or argument for the command.
-- @return string|nil: The result from the Ollama command, or nil if Ollama is not installed.
function UTILS.call_ollama(model, prompt, attachment)
    if is_ollama_installed() == false then
        dt.print("Ollama is not installed. Please install Ollama to use this feature.")
        return nil
    end

    local cmd = "ollama run " .. model .. " " .. prompt .. " " .. attachment
    dt.print_log("Running command: " .. cmd)
    dt.print_hinter("Running ollama...")
    local handle = io.popen(cmd)
    dt.print_log("Command executed")
    local result = handle:read("*a")
    handle:close()
    return result
end

return UTILS
