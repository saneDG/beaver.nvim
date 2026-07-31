local M = {}

local function log_group(url)
  return url:match('^aws://(.+)$') or vim.env.BEAVER_CLOUDWATCH_LOG_GROUP
end

function M.validate(url)
  if vim.fn.executable('aws') ~= 1 then
    return 'aws CLI not found'
  end
  if not log_group(url) or log_group(url) == '' then
    return 'missing BEAVER_CLOUDWATCH_LOG_GROUP'
  end
  return nil
end

function M.fetch(url, cursor, cfg, callback)
  local command = { 'aws', 'logs', 'filter-log-events', '--log-group-name', log_group(url), '--output', 'json' }
  local region = vim.env.BEAVER_AWS_REGION or vim.env.AWS_DEFAULT_REGION
  if region and region ~= '' then
    vim.list_extend(command, { '--region', region })
  end
  local filter = vim.env.BEAVER_CLOUDWATCH_FILTER
  if filter and filter ~= '' then
    vim.list_extend(command, { '--filter-pattern', filter })
  end
  if cursor then
    vim.list_extend(command, { '--next-token', cursor })
  end

  vim.system(command, { text = true }, function(result)
    if result.code ~= 0 then
      callback(result.stderr ~= '' and result.stderr or 'CloudWatch request failed', {}, cursor)
      return
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok then
      callback('invalid CloudWatch response', {}, cursor)
      return
    end

    local lines = {}
    for _, event in ipairs(decoded.events or {}) do
      lines[#lines + 1] = event.message
    end
    callback(nil, lines, decoded.nextToken)
  end)
end

return M
