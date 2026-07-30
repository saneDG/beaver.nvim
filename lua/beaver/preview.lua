local M = {}
local is_list = vim.islist or vim.tbl_islist

local function pretty(val, indent)
  indent = indent or 0

  if type(val) ~= "table" then
    return vim.json.encode(val)
  end

  local padding = string.rep(" ", indent)
  local child_padding = string.rep(" ", indent + 2)
  local parts = {}

  if is_list(val) then
    if #val == 0 then
      return "[]"
    end
    for _, item in ipairs(val) do
      parts[#parts + 1] = child_padding .. pretty(item, indent + 2)
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. padding .. "]"
  end

  if next(val) == nil then
    return "{}"
  end
  for key, item in pairs(val) do
    parts[#parts + 1] = child_padding
      .. vim.json.encode(tostring(key))
      .. ": "
      .. pretty(item, indent + 2)
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. padding .. "}"
end

function M.format(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    return
  end

  local formatted = pretty(decoded, 0)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(formatted, "\n", { plain = true }))
end

function M.open(log_bufnr, cfg)
  local preview_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(preview_bufnr, "filetype", "json")
  vim.api.nvim_open_win(preview_bufnr, false, {
    split = 'right',
    win = 0,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = log_bufnr,
    callback = function()
      if not vim.api.nvim_buf_is_valid(preview_bufnr) then
        return
      end
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local line = vim.api.nvim_buf_get_lines(log_bufnr, row - 1, row, false)
      vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, line)
      M.format(preview_bufnr)
    end,
  })

  return preview_bufnr
end

return M
