local M = {}

function M.validate()
  local token = vim.env.BEAVER_PAPERTRAIL_TOKEN
  if not token or token == '' then
    return 'missing BEAVER_PAPERTRAIL_TOKEN'
  end
  return nil
end

function M.fetch(url, cursor, cfg, callback)
  local endpoint = 'https://papertrailapp.com/api/v1/events/search.json'
  if cursor then
    endpoint = endpoint .. '?min_id=' .. tostring(cursor + 1)
  end
  local command = {
    'curl', '-sS', endpoint,
    '-H', 'X-Papertrail-Token: ' .. vim.env.BEAVER_PAPERTRAIL_TOKEN,
  }

  vim.system(command, { text = true }, function(result)
    if result.code ~= 0 then
      callback(result.stderr ~= '' and result.stderr or 'Papertrail request failed', {}, cursor)
      return
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok then
      callback('invalid Papertrail response', {}, cursor)
      return
    end

    local lines = {}
    local new_cursor = cursor
    for _, event in ipairs(decoded.events or {}) do
      lines[#lines + 1] = event.message
      if not new_cursor or event.id > new_cursor then
        new_cursor = event.id
      end
    end
    callback(nil, lines, new_cursor)
  end)
end

return M
