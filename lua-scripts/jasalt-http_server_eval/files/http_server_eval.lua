local dt = require "darktable"
local du = require "lib/dtutils"
local http_server = require "http.server"
local http_headers = require "http.headers"
local http_util = require "http.util"

du.check_min_api_version("2.0.0", "http_server_eval")

local gettext = dt.gettext.gettext
local function _(msg)
  return gettext(msg)
end

local server = nil
local server_running = false
local host, port = "localhost", 8083

local function escape_html(str)
  if not str then return "" end
  str = tostring(str)
  str = string.gsub(str, "&", "&amp;")
  str = string.gsub(str, "<", "&lt;")
  str = string.gsub(str, ">", "&gt;")
  str = string.gsub(str, '"', "&quot;")
  str = string.gsub(str, "'", "&#39;")
  return str
end

local function serialize_value(val, depth)
  depth = depth or 0
  if depth > 3 then
    return tostring(val)
  end
  
  local val_type = type(val)
  
  if val_type == "nil" then
    return "nil"
  elseif val_type == "boolean" then
    return tostring(val)
  elseif val_type == "number" then
    return tostring(val)
  elseif val_type == "string" then
    return string.format("%q", val)
  elseif val_type == "table" then
    local parts = {}
    local is_array = true
    local max_index = 0
    
    for k, v in pairs(val) do
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
        is_array = false
        break
      end
      max_index = math.max(max_index, k)
    end
    
    if is_array then
      for i = 1, max_index do
        table.insert(parts, serialize_value(val[i], depth + 1))
      end
      return "{" .. table.concat(parts, ", ") .. "}"
    else
      for k, v in pairs(val) do
        local key_str = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
        table.insert(parts, key_str .. " = " .. serialize_value(v, depth + 1))
      end
      return "{" .. table.concat(parts, ", ") .. "}"
    end
  else
    return tostring(val)
  end
end

local function eval_lua_code(code)
  if not code or code == "" then
    return false, "No code provided"
  end
  
  local func, load_err = load("return " .. code, "eval", "t")
  if not func then
    func, load_err = load(code, "eval", "t")
  end
  
  if not func then
    return false, "Syntax error: " .. tostring(load_err)
  end
  
  local success, result = pcall(func)
  
  if not success then
    return false, "Runtime error: " .. tostring(result)
  end
  
  return true, serialize_value(result)
end

local function parse_post_body(body)
  local params = {}
  for key, value in http_util.query_args(body) do
    params[key] = value
  end
  return params
end

local function reply(myserver, stream)
  local req_headers = assert(stream:get_headers())
  local req_method = req_headers:get(":method")
  local req_path = req_headers:get(":path")

  local res_headers = http_headers.new()
  
  if req_method ~= "GET" and req_method ~= "POST" and req_method ~= "HEAD" then
    res_headers:upsert(":status", "405")
    assert(stream:write_headers(res_headers, true))
    return
  end
  
  if req_path == "/" then
    res_headers:append(":status", "200")
    res_headers:append("content-type", "text/html; charset=utf-8")
    assert(stream:write_headers(res_headers, req_method == "HEAD"))
    
    if req_method ~= "HEAD" then
      assert(stream:write_chunk([[
<!DOCTYPE html>
<html>
<head>
	<title>Darktable Lua REPL</title>
	<style>
		body { 
			font-family: 'Courier New', monospace; 
			margin: 20px;
			background: #1e1e1e;
			color: #d4d4d4;
		}
		h1 { 
			color: #4ec9b0;
			border-bottom: 2px solid #4ec9b0;
			padding-bottom: 10px;
		}
		.container {
			max-width: 1200px;
			margin: 0 auto;
		}
		.input-section {
			margin: 20px 0;
		}
		label {
			display: block;
			margin-bottom: 5px;
			color: #9cdcfe;
			font-weight: bold;
		}
		textarea {
			width: 100%;
			min-height: 150px;
			padding: 10px;
			font-family: 'Courier New', monospace;
			font-size: 14px;
			background: #252526;
			color: #d4d4d4;
			border: 1px solid #3e3e42;
			border-radius: 4px;
			box-sizing: border-box;
		}
		textarea:focus {
			outline: none;
			border-color: #007acc;
		}
		button {
			background: #0e639c;
			color: white;
			border: none;
			padding: 10px 20px;
			font-size: 14px;
			cursor: pointer;
			border-radius: 4px;
			font-family: 'Courier New', monospace;
			margin-top: 10px;
		}
		button:hover {
			background: #1177bb;
		}
		button:active {
			background: #0d5a8f;
		}
		.output-section {
			margin: 20px 0;
		}
		.output {
			background: #252526;
			border: 1px solid #3e3e42;
			border-radius: 4px;
			padding: 15px;
			min-height: 100px;
			white-space: pre-wrap;
			word-wrap: break-word;
		}
		.success {
			color: #4ec9b0;
		}
		.error {
			color: #f48771;
		}
		.info {
			color: #9cdcfe;
			font-style: italic;
		}
		.examples {
			margin: 20px 0;
			padding: 15px;
			background: #252526;
			border: 1px solid #3e3e42;
			border-radius: 4px;
		}
		.examples h3 {
			color: #4ec9b0;
			margin-top: 0;
		}
		.example {
			margin: 10px 0;
			padding: 8px;
			background: #1e1e1e;
			border-left: 3px solid #007acc;
			cursor: pointer;
		}
		.example:hover {
			background: #2d2d30;
		}
		.example code {
			color: #ce9178;
		}
	</style>
</head>
<body>
	<div class="container">
		<h1>🌙 Darktable Lua REPL</h1>
		<p class="info">Evaluate Lua code in the Darktable runtime. Type your code below and click "Evaluate" or press Ctrl+Enter.</p>
		
		<div class="input-section">
			<label for="code">Lua Code:</label>
			<textarea id="code" placeholder="Enter Lua code here... (e.g., dt.configuration.version)"></textarea>
			<button onclick="evaluateCode()">Evaluate (Ctrl+Enter)</button>
			<button onclick="clearAll()" style="background: #666;">Clear</button>
		</div>
		
		<div class="output-section">
			<label>Output:</label>
			<div id="output" class="output info">Ready to evaluate code...</div>
		</div>
		
		<div class="examples">
			<h3>Example Commands:</h3>
			<div class="example" onclick="setCode('dt = require &quot;darktable&quot;')">
				<code>dt = require "darktable"</code> - Load darktable module (required for other examples)
			</div>
			<div class="example" onclick="setCode('dt.configuration.version')">
				<code>dt.configuration.version</code> - Get Darktable version
			</div>
			<div class="example" onclick="setCode('dt.database')">
				<code>dt.database</code> - Inspect database object
			</div>
			<div class="example" onclick="setCode('#dt.gui.action_images')">
				<code>#dt.gui.action_images</code> - Count selected images
			</div>
			<div class="example" onclick="setCode('for k, v in pairs(dt) do print(k) end')">
				<code>for k, v in pairs(dt) do print(k) end</code> - List dt module contents
			</div>
			<div class="example" onclick="setCode('local img = dt.gui.action_images[1]\nif img then return {filename = img.filename, rating = img.rating} end')">
				<code>local img = dt.gui.action_images[1]...</code> - Get current image info
			</div>
		</div>
	</div>
	
	<script>
		function evaluateCode() {
			const code = document.getElementById('code').value;
			const output = document.getElementById('output');
			
			if (!code.trim()) {
				output.className = 'output error';
				output.textContent = 'Error: No code provided';
				return;
			}
			
			output.className = 'output info';
			output.textContent = 'Evaluating...';
			
			fetch('/eval', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/x-www-form-urlencoded',
				},
				body: 'code=' + encodeURIComponent(code)
			})
			.then(response => response.text())
			.then(data => {
				try {
					const result = JSON.parse(data);
					if (result.success) {
						output.className = 'output success';
						output.textContent = '✓ Result:\n' + result.result;
					} else {
						output.className = 'output error';
						output.textContent = '✗ ' + result.error;
					}
				} catch (e) {
					output.className = 'output error';
					output.textContent = '✗ Failed to parse response: ' + e.message;
				}
			})
			.catch(error => {
				output.className = 'output error';
				output.textContent = '✗ Network error: ' + error.message;
			});
		}
		
		function setCode(code) {
			document.getElementById('code').value = code;
			document.getElementById('code').focus();
		}
		
		function clearAll() {
			document.getElementById('code').value = '';
			document.getElementById('output').className = 'output info';
			document.getElementById('output').textContent = 'Ready to evaluate code...';
			document.getElementById('code').focus();
		}
		
		document.getElementById('code').addEventListener('keydown', function(e) {
			if (e.ctrlKey && e.key === 'Enter') {
				e.preventDefault();
				evaluateCode();
			}
		});
		
		document.getElementById('code').focus();
	</script>
</body>
</html>
]], true))
    end
    
  elseif req_path == "/eval" and req_method == "POST" then
    local body = assert(stream:get_body_as_string())
    local params = parse_post_body(body)
    local code = params.code or ""
    
    local success, result = eval_lua_code(code)
    
    local response_data
    if success then
      response_data = string.format('{"success": true, "result": %q}', result)
    else
      response_data = string.format('{"success": false, "error": %q}', result)
    end
    
    res_headers:append(":status", "200")
    res_headers:append("content-type", "application/json; charset=utf-8")
    assert(stream:write_headers(res_headers, false))
    assert(stream:write_chunk(response_data, true))
    
  else
    res_headers:append(":status", "404")
    res_headers:append("content-type", "text/plain")
    assert(stream:write_headers(res_headers, req_method == "HEAD"))
    if req_method ~= "HEAD" then
      assert(stream:write_chunk("Not Found", true))
    end
  end
end

local function poll_server_loop()
  while server_running and not dt.control.ending do
    if server then
      local ok, err = server:step(0.1)
      if not ok and err then
        dt.print(string.format(_("http server eval error: %s"), err))
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
      dt.print(string.format(_("http server eval error: %s"), msg))
    end;
  }

  if not myserver then
    dt.print(string.format(_("http server eval failed: %s"), err or _("unknown error")))
    return
  end

  local ok, listen_err = myserver:listen()
  if not ok then
    dt.print(string.format(_("http server eval failed to listen: %s"), listen_err or _("unknown error")))
    return
  end

  server = myserver
  server_running = true

  local bound_port = select(3, server:localname())
  
  dt.control.dispatch(poll_server_loop)

  dt.print(string.format(_("http server eval listening on http://%s:%d"), host, bound_port))
end

local function stop_http_server()
  server_running = false

  if server then
    server:close()
    server = nil
    dt.print(_("http server eval stopped"))
  end
end

start_http_server()

local script_data = {}
script_data.metadata = {
  name = _("http server eval"),
  purpose = _("REPL web interface for evaluating Lua code in Darktable runtime on port 8083"),
  author = "jasalt",
  help = "https://example.com"
}
script_data.destroy = stop_http_server

return script_data
