-- FAILS TODO
local dt = require "darktable"
local du = require "lib/dtutils"
local cqueues = require "cqueues"
local http_server = require "http.server"
local http_headers = require "http.headers"

du.check_min_api_version("2.0.0", "http_server_darkroom_modules")

local gettext = dt.gettext.gettext
local function _(msg)
  return gettext(msg)
end

local server = nil
local server_running = false
local host, port = "localhost", 8083

local function get_darkroom_modules_info()
  local status, result = pcall(function()
    local images = dt.gui.action_images
    if #images == 0 then
      return nil, "No image selected"
    end
    
    local image = images[1]
    local modules_info = {}
    
    -- Check if we're in darkroom view
    if dt.gui.current_view().id ~= "darkroom" then
      return {}, "Not in darkroom view"
    end
    
    -- Try to access the pixelpipe modules through dt.gui.libs
    local success, err = pcall(function()
      -- Attempt to iterate through darkroom modules
      if dt.gui.libs and dt.gui.libs.darkroom then
        for _, module in ipairs(dt.gui.libs.darkroom.modules) do
          local module_data = {
            name = module.name or "unknown",
            enabled = module.enabled or false,
            operation = module.operation or "unknown",
            params = {}
          }
          
          table.insert(modules_info, module_data)
        end
      end
    end)
    
    if not success then
      -- Fallback: try alternative method to get module information
      -- Try accessing through the image's development history
      local alt_success = pcall(function()
        -- Get number of history items
        local num_history = #image
        for i = 1, num_history do
          local item = image[i]
          if item then
            local module_data = {
              name = item.name or "unknown",
              enabled = item.enabled or false,
              operation = item.operation or "unknown",
              num = i,
              params = {}
            }
            table.insert(modules_info, module_data)
          end
        end
      end)
      
      if not alt_success then
        return {}, "Unable to access module information"
      end
    end
    
    return modules_info, nil
  end)
  
  if not status then
    local error_msg = tostring(result)
    dt.print(string.format(_("Error getting modules info: %s"), error_msg))
    return {}, error_msg
  end
  
  return result
end

local function format_modules_info(modules_info, error_msg)
  if error_msg then
    return string.format("data: Error: %s\n\n", error_msg)
  end
  
  if not modules_info then
    return "data: No image in darkroom\n\n"
  end
  
  if #modules_info == 0 then
    return "data: No modules active (or unable to read modules)\n\n"
  end
  
  local lines = {}
  table.insert(lines, string.format("data: Active Darkroom Modules (%d total):", #modules_info))
  table.insert(lines, "data: ")
  
  for i, module in ipairs(modules_info) do
    local status = module.enabled and "ENABLED" or "disabled"
    local op_info = module.operation ~= "unknown" and string.format(" [%s]", module.operation) or ""
    local num_info = module.num and string.format(" #%d", module.num) or ""
    table.insert(lines, string.format("data: [%d] %s (%s)%s%s", i, module.name, status, op_info, num_info))
    
    if next(module.params) then
      for param_name, param_value in pairs(module.params) do
        table.insert(lines, string.format("data:   - %s: %s", param_name, param_value))
      end
    end
    table.insert(lines, "data: ")
  end
  
  return table.concat(lines, "\n") .. "\n"
end

local function serialize_modules(modules_info)
  if not modules_info then
    return "none"
  end
  
  local parts = {}
  for _, module in ipairs(modules_info) do
    local enabled_flag = module.enabled and "1" or "0"
    local params_str = ""
    local param_keys = {}
    for k in pairs(module.params) do
      table.insert(param_keys, k)
    end
    table.sort(param_keys)
    for _, k in ipairs(param_keys) do
      params_str = params_str .. k .. "=" .. tostring(module.params[k]) .. ";"
    end
    local num = module.num or 0
    table.insert(parts, string.format("%s:%s:%d:%s:%s", module.name, enabled_flag, num, module.operation, params_str))
  end
  return table.concat(parts, "|")
end

local function reply(myserver, stream)
  -- Read in headers
  local req_headers = assert(stream:get_headers())
  local req_method = req_headers:get(":method")

  -- Build response headers
  local res_headers = http_headers.new()
  if req_method ~= "GET" and req_method ~= "HEAD" then
    res_headers:upsert(":status", "405")
    assert(stream:write_headers(res_headers, true))
    return
  end
  
  if req_headers:get(":path") == "/" then
    res_headers:append(":status", "200")
    res_headers:append("content-type", "text/html")
    -- Send headers to client; end the stream immediately if this was a HEAD request
    assert(stream:write_headers(res_headers, req_method == "HEAD"))
    if req_method ~= "HEAD" then
      assert(stream:write_chunk([[
<!DOCTYPE html>
<html>
<head>
	<title>Darktable Darkroom Modules Monitor</title>
	<style>
		body { 
			font-family: Arial, sans-serif; 
			margin: 20px;
			background: #1a1a1a;
			color: #e0e0e0;
		}
		h1 { color: #4a9eff; }
		#modules { 
			background: #2a2a2a; 
			padding: 20px; 
			border-radius: 8px;
			white-space: pre-wrap;
			font-family: 'Courier New', monospace;
			font-size: 14px;
			line-height: 1.6;
			border: 1px solid #3a3a3a;
		}
		.enabled { color: #4ade80; font-weight: bold; }
		.disabled { color: #888; }
		.module-name { color: #fbbf24; }
		.param { color: #60a5fa; }
		.error { color: #ef4444; font-weight: bold; }
		a { color: #4a9eff; }
	</style>
</head>
<body>
	<h1>Darktable Darkroom Modules Monitor</h1>
	<p>This page uses <a href="https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events">server-sent events</a> to show the currently active darkroom modules and their parameters:</p>
	<div id="modules">Waiting for data...</div>
	<script type="text/javascript">
		var events = new EventSource("/event-stream");
		var el = document.getElementById("modules");
		events.onmessage = function(e) {
			var html = e.data
				.replace(/Error: ([^\n]+)/g, '<span class="error">Error: $1</span>')
				.replace(/\[(\d+)\] ([^\(]+) \(ENABLED\)/g, '[$1] <span class="module-name">$2</span> (<span class="enabled">ENABLED</span>)')
				.replace(/\[(\d+)\] ([^\(]+) \(disabled\)/g, '[$1] <span class="module-name">$2</span> (<span class="disabled">disabled</span>)')
				.replace(/  - ([^:]+):/g, '  - <span class="param">$1</span>:')
				.replace(/\n/g, '<br>');
			el.innerHTML = html;
		}
		events.onerror = function(e) {
			el.innerHTML = '<span class="error">Connection error. Please check if the server is running.</span>';
		}
	</script>
</body>
</html>
]], true))
    end
  elseif req_headers:get(":path") == "/event-stream" then
    res_headers:append(":status", "200")
    res_headers:append("content-type", "text/event-stream")
    res_headers:append("cache-control", "no-cache")
    res_headers:append("connection", "keep-alive")
    -- Send headers to client; end the stream immediately if this was a HEAD request
    assert(stream:write_headers(res_headers, req_method == "HEAD"))
    if req_method ~= "HEAD" then
      -- Send initial modules info
      local info, err = get_darkroom_modules_info()
      local msg = format_modules_info(info, err)
      local ok, send_err = pcall(function()
        assert(stream:write_chunk(msg, false))
      end)
      
      if ok then
        local last_serialized = serialize_modules(info)
        
        -- Start a loop that checks for module changes and sends updates
        while server_running do
          local current_info, current_err = get_darkroom_modules_info()
          local current_serialized = serialize_modules(current_info)
          
          -- Only send update if the modules have changed
          if current_serialized ~= last_serialized then
            local update_msg = format_modules_info(current_info, current_err)
            local send_ok, send_err = pcall(function()
              assert(stream:write_chunk(update_msg, false))
            end)
            if not send_ok then
              -- Client disconnected or error occurred
              dt.print(string.format(_("Stream write error: %s"), tostring(send_err)))
              break
            end
            last_serialized = current_serialized
          end
          
          cqueues.sleep(0.5) -- check for changes every 500ms
        end
      else
        dt.print(string.format(_("Initial stream write error: %s"), tostring(send_err)))
      end
    end
  else
    res_headers:append(":status", "404")
    assert(stream:write_headers(res_headers, true))
  end
end

local function poll_server_loop()
  while server_running and not dt.control.ending do
    if server then
      local ok, err = server:step(0.1)
      if not ok and err then
        dt.print(string.format(_("http server darkroom modules error: %s"), tostring(err)))
      end
    end
    dt.control.sleep(100)
  end
end

local function start_http_server()
  if server then
    return
  end

  local myserver, err = http_server.listen {
    host = host;
    port = port;
    onstream = reply;
    onerror = function(myserver, context, op, err, errno)
      local msg = op .. " on " .. tostring(context) .. " failed"
      if err then
        msg = msg .. ": " .. tostring(err)
      end
      dt.print(string.format(_("http server darkroom modules error: %s"), msg))
    end;
  }

  if not myserver then
    dt.print(string.format(_("http server darkroom modules failed: %s"), err or _("unknown error")))
    return
  end

  -- Manually call :listen() so that we are bound before getting port info
  local ok, listen_err = myserver:listen()
  if not ok then
    dt.print(string.format(_("http server darkroom modules failed to listen: %s"), listen_err or _("unknown error")))
    return
  end

  server = myserver
  server_running = true

  local bound_port = select(3, server:localname())
  
  dt.control.dispatch(poll_server_loop)

  dt.print(string.format(_("http server darkroom modules listening on http://%s:%d"), host, bound_port))
end

local function stop_http_server()
  server_running = false

  if server then
    server:close()
    server = nil
    dt.print(_("http server darkroom modules stopped"))
  end
end

start_http_server()

local script_data = {}
script_data.metadata = {
  name = _("http server darkroom modules WIP"),
  purpose = _("broadcast active darkroom modules and their parameters via SSE on port 8083"),
  author = "jasalt",
  help = "https://example.com"
}
script_data.destroy = stop_http_server

return script_data
