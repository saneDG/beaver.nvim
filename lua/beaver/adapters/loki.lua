local M = {}

local function timestamp_after(left, right)
  return not right or #left > #right or (#left == #right and left > right)
end

function M.validate()
  return nil
end

function M.fetch(url, cursor, cfg, callback)
  local now = tostring(os.time()) .. '000000000'
  local start = cursor or (tostring(os.time() - 300) .. '000000000')
  local command = {
    'curl', '-sS', '-G', url,
    '--data-urlencode', 'start=' .. start,
    '--data-urlencode', 'end=' .. now,
  }

  local user = vim.env.BEAVER_LOKI_USER
  local password = vim.env.BEAVER_LOKI_PASSWORD
  if user and user ~= '' and password and password ~= '' then
    vim.list_extend(command, { '-u', user .. ':' .. password })
  end
  local org_id = vim.env.BEAVER_LOKI_ORG_ID
  if org_id and org_id ~= '' then
    vim.list_extend(command, { '-H', 'X-Scope-OrgID: ' .. org_id })
  end

  vim.system(command, { text = true }, function(result)
    if result.code ~= 0 then
      callback(result.stderr ~= '' and result.stderr or 'Loki request failed', {}, cursor)
      return
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok then
      callback('invalid Loki response', {}, cursor)
      return
    end

    local lines = {}
    local new_cursor = cursor
    for _, stream in ipairs((decoded.data and decoded.data.result) or {}) do
      for _, value in ipairs(stream.values or {}) do
        lines[#lines + 1] = value[2]
        if timestamp_after(value[1], new_cursor) then
          new_cursor = value[1]
        end
      end
    end
    callback(nil, lines, new_cursor)
  end)
end

return M
