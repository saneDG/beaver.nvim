---@diagnostic disable: undefined-global

local M = {}

local function format_json(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local content = table.concat(lines, "\n")
  local ok, parsed = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Invalid JSON in buffer!", vim.log.levels.ERROR)
    return
  end
  local formatted = vim.json.encode(parsed)
  formatted = formatted:gsub(",", ",\n"):gsub("{", "{\n"):gsub("}", "\n}")
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(formatted, "\n"))
end

-- TODO: Toggle preview buffer on command, not automatically after :Beaver
-- TODO: Enable formatting and syntax hl on preview
local function create_line_autocmd(log_buf, preview_buf)
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    buffer = log_buf,
    callback = function()
      local current_line = vim.api.nvim_get_current_line()
      vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { current_line })
      vim.api.nvim_buf_call(preview_buf, function()
        vim.api.nvim_exec_autocmds("BufWritePost", {})
      end)
    end
  })
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    buffer = preview_buf,
    callback = function()
      format_json(preview_buf)
    end
  })
end

-- TODO: Ability to close beaver
function M.setup()
  vim.api.nvim_create_user_command(
    'Beaver',
    function()
      vim.opt_local.wrap = false
      local watch = vim.uv.new_fs_event()
      local current_buf_file_name = vim.api.nvim_buf_get_name(0)
      local log_buf = vim.api.nvim_win_get_buf(0)
      local function on_change(err, fname, status)
        vim.api.nvim_command('checktime')
        -- Debounce: stop/start.
        watch:stop()
        Watch_file(current_buf_file_name)
      end
      function Watch_file(file_name)
        watch:start(file_name, {}, vim.schedule_wrap(function(...)
          on_change(...)
        end))
      end

      local preview_buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_option(preview_buf, "filetype", "json")

      vim.api.nvim_open_win(preview_buf, false, {
        split = 'right',
        win = 0
      })

      Watch_file(current_buf_file_name)
      create_line_autocmd(log_buf, preview_buf)
    end,
    {
      nargs = "?",
      desc = "Beaver log file watcher",
    }
  )
end

return M
