local M = {}

local state = {}

function M.start(bufnr, file_path, on_reload_cb)
  local handle = vim.uv.new_fs_event()
  local function on_change()
    vim.schedule(function()
      local entry = state[bufnr]
      if not entry or not entry.watching or entry.paused or handle:is_closing() then
        return
      end

      local modifiable = vim.bo[bufnr].modifiable
      if not modifiable then
        vim.bo[bufnr].modifiable = true
      end
      local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
        vim.api.nvim_command('checktime')
      end)
      if not modifiable then
        vim.bo[bufnr].modifiable = false
      end
      handle:stop()
      handle:start(file_path, {}, on_change)
      if not ok then
        vim.notify('Beaver: failed to reload file: ' .. err, vim.log.levels.ERROR)
      end
    end)
  end

  state[bufnr] = {
    watching = true,
    paused = false,
    handle = handle,
    file_path = file_path,
    on_change = on_change,
  }

  handle:start(file_path, {}, on_change)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_reload = function()
      on_reload_cb()
    end,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = bufnr,
    once = true,
    callback = function()
      M.stop(bufnr)
      state[bufnr] = nil
    end,
  })
end

function M.toggle(bufnr)
  local entry = state[bufnr]
  if not entry or not entry.watching then
    return
  end

  if entry.paused then
    if vim.bo[bufnr].modified then
      vim.notify('Beaver: cannot resume: buffer is modified', vim.log.levels.WARN)
      return
    end
    entry.paused = false
    entry.handle:start(entry.file_path, {}, entry.on_change)
    vim.notify('Beaver: watching resumed')
  else
    entry.handle:stop()
    entry.paused = true
    vim.notify('Beaver: paused')
  end
end

function M.stop(bufnr)
  local entry = state[bufnr]
  if not entry then
    return
  end

  local handle = entry.handle
  if handle and not handle:is_closing() then
    handle:stop()
    handle:close()
  end
  entry.watching = false
end

function M.is_watching(bufnr)
  return state[bufnr] ~= nil and state[bufnr].watching
end

return M
