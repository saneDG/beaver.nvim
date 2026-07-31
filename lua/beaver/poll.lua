local M = {}

local marks = require('beaver.marks')
local state = {}

local adapters = {
  generic = true,
  loki = true,
  papertrail = true,
  datadog = true,
  cloudwatch = true,
}

local function adapter_name(url)
  if vim.env.BEAVER_ADAPTER and vim.env.BEAVER_ADAPTER ~= '' then
    return vim.env.BEAVER_ADAPTER
  end
  if url:match('^aws://') then
    return 'cloudwatch'
  end

  local hostname = url:match('https?://([^/:]+)') or ''
  if hostname:match('amazonaws%.com') then
    return 'cloudwatch'
  end
  if hostname:match('grafana%.net') or hostname:lower():match('loki') or url:match('^https?://[^/]+:3100') then
    return 'loki'
  end
  if hostname:match('papertrailapp%.com') then
    return 'papertrail'
  end
  if hostname:match('datadoghq%.com$') or hostname:match('datadoghq%.eu$') then
    return 'datadog'
  end
  return 'generic'
end

function M.start(bufnr, url, cfg)
  local name = adapter_name(url)
  if not adapters[name] then
    vim.notify('Beaver: unknown adapter ' .. name, vim.log.levels.WARN)
    return nil
  end

  local adapter = require('beaver.adapters.' .. name)
  local validation_err = adapter.validate(url)
  if validation_err then
    vim.notify('Beaver: ' .. validation_err, vim.log.levels.WARN)
    return nil
  end

  local poll_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(poll_bufnr, url)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = poll_bufnr })
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), poll_bufnr)
  marks.setup(poll_bufnr, cfg)

  local timer = vim.uv.new_timer()
  state[poll_bufnr] = {
    polling = true,
    paused = false,
    timer = timer,
    cursor = nil,
    adapter = adapter,
    url = url,
  }

  local function tick()
    local entry = state[poll_bufnr]
    if not entry or entry.paused then
      return
    end

    entry.adapter.fetch(entry.url, entry.cursor, cfg, function(err, lines, new_cursor)
      vim.schedule(function()
        local current = state[poll_bufnr]
        if not current or not vim.api.nvim_buf_is_valid(poll_bufnr) then
          return
        end
        if err then
          vim.notify('Beaver: ' .. err, vim.log.levels.WARN)
          return
        end

        current.cursor = new_cursor
        if lines and #lines > 0 then
          vim.api.nvim_buf_set_lines(poll_bufnr, -1, -1, false, lines)
          marks.on_reload(poll_bufnr)
        end
      end)
    end)
  end

  timer:start(0, cfg.poll_interval_ms, function()
    vim.schedule(tick)
  end)

  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = poll_bufnr,
    once = true,
    callback = function()
      M.stop(poll_bufnr)
    end,
  })

  return poll_bufnr
end

function M.stop(bufnr)
  local entry = state[bufnr]
  if not entry then
    return
  end
  if not entry.timer:is_closing() then
    entry.timer:stop()
    entry.timer:close()
  end
  entry.polling = false
end

function M.toggle(bufnr)
  local entry = state[bufnr]
  if not entry or not entry.polling then
    return
  end
  entry.paused = not entry.paused
  vim.notify(entry.paused and 'Paused' or 'Watching resumed')
end

function M.is_polling(bufnr)
  return state[bufnr] ~= nil and state[bufnr].polling
end

return M
