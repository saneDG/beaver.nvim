local M = {}

local state
local messages = {
  'Request completed',
  'Worker started',
  'Cache refreshed',
}

local function close_client(client)
  if client and not client:is_closing() then
    client:close()
  end
end

function M.start(port, interval_ms)
  if state then
    return false, 'mock server is already running'
  end

  local server = vim.uv.new_tcp()
  local timer = vim.uv.new_timer()
  local clients = {}
  local lines = {}
  local count = 0

  local function add_line()
    count = count + 1
    lines[#lines + 1] = vim.json.encode({
      level = ({ 'INFO', 'WARN', 'ERROR' })[(count - 1) % 3 + 1],
      message = messages[(count - 1) % #messages + 1],
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    })
  end

  local bound, bind_err = server:bind('127.0.0.1', port)
  if not bound then
    server:close()
    timer:close()
    return false, bind_err
  end

  local listening, listen_err = server:listen(128, function(err)
    if err then
      return
    end

    local client = vim.uv.new_tcp()
    if server:accept(client) ~= 0 then
      close_client(client)
      return
    end
    clients[client] = true

    client:read_start(function(read_err, data)
      if read_err then
        clients[client] = nil
        close_client(client)
        return
      end
      if not data then
        return
      end

      client:read_stop()
      local body = table.concat(lines, '\n') .. '\n'
      local response = table.concat({
        'HTTP/1.1 200 OK',
        'Content-Type: application/x-ndjson',
        'Content-Length: ' .. #body,
        'Connection: close',
        '',
        body,
      }, '\r\n')
      client:write(response, function()
        clients[client] = nil
        client:shutdown(function()
          close_client(client)
        end)
      end)
    end)
  end)

  if not listening then
    server:close()
    timer:close()
    return false, listen_err
  end

  add_line()
  timer:start(interval_ms, interval_ms, add_line)
  state = {
    server = server,
    timer = timer,
    clients = clients,
    port = port,
  }
  return true
end

function M.stop()
  if not state then
    return false
  end

  state.timer:stop()
  state.timer:close()
  for client in pairs(state.clients) do
    close_client(client)
  end
  if not state.server:is_closing() then
    state.server:close()
  end
  state = nil
  return true
end

function M.is_running()
  return state ~= nil
end

return M
