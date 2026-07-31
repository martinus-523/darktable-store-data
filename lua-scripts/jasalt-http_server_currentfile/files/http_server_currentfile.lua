local dt = require "darktable"
local du = require "lib/dtutils"
local cqueues = require "cqueues"
local http_server = require "http.server"
local http_headers = require "http.headers"

du.check_min_api_version("2.0.0", "http_server_currentfile")

local gettext = dt.gettext.gettext
local function _(msg)
  return gettext(msg)
end

local server = nil
local server_running = false
local host, port = "localhost", 8082
local current_image_id = nil

local function get_current_file_info()
  local images = dt.gui.action_images
  if #images > 0 then
    local image = images[1]
    local info = {
      id = image.id,
      filename = image.filename,
      path = image.path,
      exif_datetime_taken = image.exif_datetime_taken,
      rating = image.rating,
      width = image.width,
      height = image.height
    }
    return info
  end
  return nil
end

local function format_file_info(info)
  if not info then
    return "data: No image selected\n\n"
  end
  
  local msg = string.format(
    "data: File: %s\ndata: Path: %s\ndata: ID: %d\ndata: Size: %dx%d\ndata: Rating: %d\ndata: Taken: %s\n\n",
    info.filename or "unknown",
    info.path or "unknown",
    info.id or 0,
    info.width or 0,
    info.height or 0,
    info.rating or 0,
    info.exif_datetime_taken or "unknown"
  )
  return msg
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
	<title>Darktable Current File Monitor</title>
	<style>
		body { font-family: Arial, sans-serif; margin: 20px; }
		h1 { color: #333; }
		#fileinfo { 
			background: #f4f4f4; 
			padding: 15px; 
			border-radius: 5px;
			white-space: pre-wrap;
			font-family: monospace;
		}
		.label { font-weight: bold; color: #666; }
	</style>
</head>
<body>
	<h1>Darktable Current File Monitor</h1>
	<p>This page uses <a href="https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events">server-sent events</a> to show the currently selected file in darktable:</p>
	<div id="fileinfo">Waiting for data...</div>
	<script type="text/javascript">
		var events = new EventSource("/event-stream");
		var el = document.getElementById("fileinfo");
		events.onmessage = function(e) {
			el.innerHTML = e.data.replace(/\n/g, '<br>');
		}
		events.onerror = function(e) {
			el.innerHTML = "Connection error. Please check if the server is running.";
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
      -- Send initial file info
      local info = get_current_file_info()
      local msg = format_file_info(info)
      local ok, err = pcall(function()
        assert(stream:write_chunk(msg, false))
      end)
      
      if ok then
        local last_image_id = info and info.id or nil
        
        -- Start a loop that checks for file changes and sends updates
        while server_running do
          local current_info = get_current_file_info()
          local current_id = current_info and current_info.id or nil
          
          -- Only send update if the image has changed
          if current_id ~= last_image_id then
            local update_msg = format_file_info(current_info)
            local send_ok, send_err = pcall(function()
              assert(stream:write_chunk(update_msg, false))
            end)
            if not send_ok then
              -- Client disconnected or error occurred
              break
            end
            last_image_id = current_id
          end
          
          cqueues.sleep(0.5) -- check for changes every 500ms
        end
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
        dt.print(string.format(_("http server currentfile error: %s"), err))
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
      dt.print(string.format(_("http server currentfile error: %s"), msg))
    end;
  }

  if not myserver then
    dt.print(string.format(_("http server currentfile failed: %s"), err or _("unknown error")))
    return
  end

  -- Manually call :listen() so that we are bound before getting port info
  local ok, listen_err = myserver:listen()
  if not ok then
    dt.print(string.format(_("http server currentfile failed to listen: %s"), listen_err or _("unknown error")))
    return
  end

  server = myserver
  server_running = true

  local bound_port = select(3, server:localname())
  
  dt.control.dispatch(poll_server_loop)

  dt.print(string.format(_("http server currentfile listening on http://%s:%d"), host, bound_port))
end

local function stop_http_server()
  server_running = false

  if server then
    server:close()
    server = nil
    dt.print(_("http server currentfile stopped"))
  end
end

start_http_server()

local script_data = {}
script_data.metadata = {
  name = _("http server currentfile"),
  purpose = _("broadcast current file information via SSE on port 8082"),
  author = "jasalt",
  help = "https://example.com"
}
script_data.destroy = stop_http_server

return script_data
