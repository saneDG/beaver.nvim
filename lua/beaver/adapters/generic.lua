local M = {}

function M.validate()
  return nil
end

function M.fetch(url, cursor, cfg, callback)
  vim.system({ 'curl', '-sS', url }, { text = true }, function(result)
    if result.code ~= 0 then
      callback(result.stderr ~= '' and result.stderr or 'curl request failed', {}, cursor)
      return
    end

    local lines = vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })
    local seen = cursor or 0
    -- Generic endpoints are assumed to return their full history on every request.
    if #lines <= seen then
      callback(nil, {}, seen)
      return
    end

    local new_lines = {}
    for index = seen + 1, #lines do
      new_lines[#new_lines + 1] = lines[index]
    end
    callback(nil, new_lines, #lines)
  end)
end

return M
