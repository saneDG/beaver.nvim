local M = {}

local state = {}
local messages = {
  "Request completed",
  "Worker started",
  "Cache refreshed",
}

function M.start(bufnr, file_path, interval_ms)
  if state[file_path] then
    return false
  end

  local file = io.open(file_path, "a")
  if not file then
    return false
  end
  file:close()

  local timer = vim.uv.new_timer()
  local count = 0
  state[file_path] = timer

  timer:start(0, interval_ms, function()
    count = count + 1
    local level = ({ "INFO", "WARN", "ERROR" })[(count - 1) % 3 + 1]
    local message = messages[(count - 1) % #messages + 1]
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local line

    if count % 2 == 1 then
      line = vim.json.encode({
        level = level,
        message = message,
        timestamp = timestamp,
      })
    else
      line = string.format("[%s] %s - %s", timestamp, level, message)
    end

    local output = io.open(file_path, "a")
    if output then
      output:write(line, "\n")
      output:close()
    end
  end)

  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    once = true,
    callback = function()
      M.stop(file_path)
    end,
  })

  return true
end

function M.stop(file_path)
  local timer = state[file_path]
  if not timer then
    return false
  end

  if not timer:is_closing() then
    timer:stop()
    timer:close()
  end
  state[file_path] = nil
  return true
end

function M.is_running(file_path)
  return state[file_path] ~= nil
end

return M
