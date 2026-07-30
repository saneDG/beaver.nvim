local M = {}
local config = require('beaver.config')
local watcher = require('beaver.watcher')
local preview = require('beaver.preview')
local marks = require('beaver.marks')
local mock = require('beaver.mock')
local mock_server = require('beaver.mock_server')
local poll = require('beaver.poll')

local cfg
local mode = {}

local function set_keymaps(bufnr, preview_bufnr)
  vim.keymap.set('n', cfg.keymaps.pause, function()
    if mode[bufnr] == 'poll' then
      poll.toggle(bufnr)
    else
      watcher.toggle(bufnr)
    end
  end, { buffer = bufnr, desc = 'Pause or resume Beaver' })

  vim.keymap.set('n', cfg.keymaps.toggle_preview, function()
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(winid) == preview_bufnr then
        vim.api.nvim_win_close(winid, true)
        return
      end
    end

    if vim.api.nvim_buf_is_valid(preview_bufnr) then
      vim.api.nvim_open_win(preview_bufnr, false, { split = 'right', win = 0 })
    else
      preview_bufnr = preview.open(bufnr, cfg)
    end
  end, { buffer = bufnr, desc = 'Toggle Beaver preview' })

  vim.keymap.set('n', cfg.keymaps.clear_marks, function()
    marks.clear(bufnr)
  end, { buffer = bufnr, desc = 'Clear Beaver marks' })

  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    once = true,
    callback = function()
      mode[bufnr] = nil
    end,
  })
end

function M.setup(user_opts)
  cfg = config.resolve(user_opts)
  vim.api.nvim_create_user_command('Beaver', M._command, {
    nargs = '?',
    desc = 'Beaver log file watcher',
  })
  vim.api.nvim_create_user_command('BeaverMockStart', function()
    local bufnr = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == '' then
      vim.notify('Beaver: current buffer has no file', vim.log.levels.ERROR)
      return
    end
    if not mock.start(bufnr, file, cfg.mock_interval_ms) then
      vim.notify('Beaver: mock feed is already running or the file cannot be opened', vim.log.levels.WARN)
    end
  end, {
    desc = 'Start the Beaver mock live feed',
  })
  vim.api.nvim_create_user_command('BeaverMockStop', function()
    local file = vim.api.nvim_buf_get_name(0)
    if not mock.stop(file) then
      vim.notify('Beaver: no mock feed is running for this buffer', vim.log.levels.WARN)
    end
  end, {
    desc = 'Stop the Beaver mock live feed',
  })
  vim.api.nvim_create_user_command('BeaverMockServer', function(opts)
    local port = tonumber(opts.args) or 8080
    if port < 1 or port > 65535 then
      vim.notify('Beaver: invalid port', vim.log.levels.ERROR)
      return
    end
    local ok, err = mock_server.start(port, cfg.mock_interval_ms)
    if not ok then
      vim.notify('Beaver: ' .. err, vim.log.levels.WARN)
      return
    end
    vim.notify(string.format('Beaver: mock server listening at http://127.0.0.1:%d/logs', port))
  end, {
    nargs = '?',
    desc = 'Start the Beaver mock HTTP server',
  })
  vim.api.nvim_create_user_command('BeaverMockServerStop', function()
    if not mock_server.stop() then
      vim.notify('Beaver: mock server is not running', vim.log.levels.WARN)
    end
  end, {
    desc = 'Stop the Beaver mock HTTP server',
  })
end

function M._command(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if opts.args ~= '' then
    if not opts.args:match('^https?://') and not opts.args:match('^aws://') then
      vim.notify('Beaver: unrecognised input', vim.log.levels.WARN)
      return
    end
    if watcher.is_watching(bufnr) or poll.is_polling(bufnr) then
      vim.notify('Beaver: already watching this buffer', vim.log.levels.WARN)
      return
    end

    local poll_bufnr = poll.start(bufnr, opts.args, cfg)
    if not poll_bufnr then
      return
    end
    mode[poll_bufnr] = 'poll'
    vim.wo.wrap = false
    local preview_bufnr = preview.open(poll_bufnr, cfg)
    set_keymaps(poll_bufnr, preview_bufnr)
    return
  end

  if file == '' then
    vim.notify('Beaver: current buffer has no file', vim.log.levels.ERROR)
    return
  end

  if watcher.is_watching(bufnr) or poll.is_polling(bufnr) then
    vim.notify('Beaver: already watching this buffer', vim.log.levels.WARN)
    return
  end

  vim.opt_local.wrap = false
  if not cfg.allow_editing then
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  end

  local preview_bufnr = preview.open(bufnr, cfg)
  marks.setup(bufnr, cfg)
  watcher.start(bufnr, file, function()
    marks.on_reload(bufnr)
  end)
  mode[bufnr] = 'watch'
  set_keymaps(bufnr, preview_bufnr)
end

return M
