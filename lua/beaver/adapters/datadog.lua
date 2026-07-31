local M = {}

function M.validate()
  local api_key = vim.env.BEAVER_DATADOG_API_KEY
  if not api_key or api_key == '' then
    return 'missing BEAVER_DATADOG_API_KEY'
  end
  local app_key = vim.env.BEAVER_DATADOG_APP_KEY
  if not app_key or app_key == '' then
    return 'missing BEAVER_DATADOG_APP_KEY'
  end
  return nil
end

function M.fetch(url, cursor, cfg, callback)
  local api_key = vim.env.BEAVER_DATADOG_API_KEY
  local app_key = vim.env.BEAVER_DATADOG_APP_KEY
  local site = vim.env.BEAVER_DATADOG_SITE or 'datadoghq.com'
  local endpoint = 'https://api.' .. site .. '/api/v2/logs/events/search'
  local body = {
    filter = {
      query = vim.env.BEAVER_DATADOG_QUERY or '*',
    },
  }
  if cursor then
    body.page = { cursor = cursor }
  end

  vim.system({
    'curl', '-sS', '-X', 'POST', endpoint,
    '-H', 'Content-Type: application/json',
    '-H', 'DD-API-KEY: ' .. api_key,
    '-H', 'DD-APPLICATION-KEY: ' .. app_key,
    '-d', vim.json.encode(body),
  }, { text = true }, function(result)
    if result.code ~= 0 then
      callback(result.stderr ~= '' and result.stderr or 'Datadog request failed', {}, cursor)
      return
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok then
      callback('invalid Datadog response', {}, cursor)
      return
    end

    local lines = {}
    for _, item in ipairs(decoded.data or {}) do
      local attributes = item.attributes or {}
      lines[#lines + 1] = attributes.message or vim.json.encode(attributes)
    end
    local page = decoded.meta and decoded.meta.page or {}
    callback(nil, lines, page.after)
  end)
end

return M
