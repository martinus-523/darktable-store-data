local dt = require "darktable"
local du = require "lib/dtutils"
local cqueues = require "cqueues"
local http_server = require "http.server"
local http_headers = require "http.headers"

du.check_min_api_version("2.0.0", "http_server_sse")

local gettext = dt.gettext.gettext
local function _(msg)
  return gettext(msg)
end

local server = nil
local server_running = false
local host, port = "localhost", 8081

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
	<title>EventSource demo</title>
</head>
<body>
	<p>This page uses <a href="https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events">server-sent_events</a> to show the live server time:</p>
	<div id="time"></div>
	<script type="text/javascript">
		var events = new EventSource("/event-stream");
		var el = document.getElementById("time");
		events.onmessage = function(e) {
			el.innerHTML = e.data;
		}
	</script>
</body>
</html>
]], true))
    end
  elseif req_headers:get(":path") == "/event-stream" then
    res_headers:append(":status", "200")
    res_headers:append("content-type", "text/event-stream")
    -- Send headers to client; end the stream immediately if this was a HEAD request
    assert(stream:write_headers(res_headers, req_method == "HEAD"))
    if req_method ~= "HEAD" then
      -- Start a loop that sends the current time to the client each second
      while server_running do
        local msg = string.format("data: The time is now %s.\n\n", os.date())
        local ok, err = pcall(function()
          assert(stream:write_chunk(msg, false))
        end)
        if not ok then
          -- Client disconnected or error occurred
          break
        end
        cqueues.sleep(1) -- yield the current thread for a second
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
        dt.print(string.format(_("http server sse error: %s"), err))
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
      dt.print(string.format(_("http server sse error: %s"), msg))
    end;
  }

  if not myserver then
    dt.print(string.format(_("http server sse failed: %s"), err or _("unknown error")))
    return
  end

  -- Manually call :listen() so that we are bound before getting port info
  local ok, listen_err = myserver:listen()
  if not ok then
    dt.print(string.format(_("http server sse failed to listen: %s"), listen_err or _("unknown error")))
    return
  end

  server = myserver
  server_running = true

  local bound_port = select(3, server:localname())
  
  dt.control.dispatch(poll_server_loop)

  dt.print(string.format(_("http server sse listening on http://%s:%d"), host, bound_port))
end

local function stop_http_server()
  server_running = false

  if server then
    server:close()
    server = nil
    dt.print(_("http server sse stopped"))
  end
end

start_http_server()

local script_data = {}
script_data.metadata = {
  name = _("http server sse"),
  purpose = _("run http server with server-sent events at 8081"),
  author = "jasalt",
  help = "https://example.com"
}
script_data.destroy = stop_http_server

return script_data
