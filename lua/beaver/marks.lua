local M = {}

local namespace = vim.api.nvim_create_namespace('beaver_marks')
local scroll_namespace = vim.api.nvim_create_namespace('beaver_scroll')
local state = {}

local function line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return #lines == 1 and lines[1] == '' and 0 or #lines
end

local function update_scroll_indicator(bufnr)
  local entry = state[bufnr]
  if not entry or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, scroll_namespace, 0, -1)
  if not entry.new_line_start or entry.unread_count == 0 then
    return
  end

  local winid
  local current_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(current_win) == bufnr then
    winid = current_win
  else
    for _, candidate in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(candidate) == bufnr then
        winid = candidate
        break
      end
    end
  end
  if not winid then
    return
  end

  local last_visible = vim.api.nvim_win_call(winid, function()
    return vim.fn.line('w$') - 1
  end)
  if entry.new_line_start <= last_visible then
    return
  end

  vim.api.nvim_buf_set_extmark(bufnr, scroll_namespace, last_visible, 0, {
    virt_text = {
      { string.format('▼ %d unread below', entry.unread_count), entry.cfg.scroll_hl_group },
    },
    virt_text_pos = 'right_align',
  })
end

local function apply(bufnr)
  local entry = state[bufnr]
  if not entry or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  if not entry.new_line_start or entry.unread_count == 0 then
    update_scroll_indicator(bufnr)
    return
  end

  local divider = string.format("  ── %d new ──", entry.unread_count)
  entry.divider_extmark_id = vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.new_line_start, 0, {
    id = entry.divider_extmark_id,
    virt_lines = { { { divider, entry.cfg.divider_hl_group } } },
    virt_lines_above = true,
  })

  local count = vim.api.nvim_buf_line_count(bufnr)
  for row = entry.new_line_start, count - 1 do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
      sign_text = entry.cfg.sign_text,
      sign_hl_group = entry.cfg.sign_hl_group,
    })
  end
  update_scroll_indicator(bufnr)
end

function M.setup(bufnr, cfg)
  local group = vim.api.nvim_create_augroup('beaver_marks_' .. bufnr, { clear = true })
  state[bufnr] = {
    baseline_count = line_count(bufnr),
    new_line_start = nil,
    divider_extmark_id = nil,
    unread_count = 0,
    cfg = cfg,
  }

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = bufnr,
    callback = function()
      update_scroll_indicator(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd('WinScrolled', {
    group = group,
    callback = function()
      update_scroll_indicator(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      state[bufnr] = nil
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })
end

function M.on_reload(bufnr)
  -- Buffer reload callbacks run in a fast context, so defer every API call.
  vim.schedule(function()
    local entry = state[bufnr]
    if not entry or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local count = line_count(bufnr)
    local new_count = count - entry.baseline_count
    if new_count > 0 then
      entry.new_line_start = entry.new_line_start or entry.baseline_count
      entry.unread_count = entry.unread_count + new_count
    end
    entry.baseline_count = count
    apply(bufnr)
  end)
end

function M.clear(bufnr)
  local entry = state[bufnr]
  if not entry then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, scroll_namespace, 0, -1)
  entry.baseline_count = line_count(bufnr)
  entry.new_line_start = nil
  entry.divider_extmark_id = nil
  entry.unread_count = 0
end

return M
