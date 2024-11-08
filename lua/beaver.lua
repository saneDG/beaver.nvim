---@diagnostic disable: undefined-global

local M = {}

local prev_prewiew_buf = Nil

-- TODO: Toggle preview buffer on command, not automatically after :Beaver
-- TODO: Enable formatting and syntax hl on preview
local function create_line_autocmd(log_buf)
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    buffer = log_buf,
    callback = function(ev)
      if prev_prewiew_buf then
        vim.api.nvim_buf_delete(prev_prewiew_buf, {})
      end
      print(string.format('event fired: %s', vim.inspect(ev)))
      local current_line = vim.api.nvim_get_current_line()
      print(current_line)
      local preview_buf = vim.api.nvim_create_buf(true, true)
      print(preview_buf)
      vim.api.nvim_open_win(preview_buf, false, {
        split = 'right',
        win = 0
      })
      vim.api.nvim_buf_set_lines(preview_buf, 0, 1, false, { current_line })
      prev_prewiew_buf = preview_buf
    end
  })
end

-- TODO: Ability to close beaver
function M.setup()
  vim.api.nvim_create_user_command(
    'Beaver',
    function(opts)
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

      Watch_file(current_buf_file_name)
      create_line_autocmd(log_buf)
    end,
    {
      nargs = "?",
      desc = "Beaver log file watcher",
    }
  )
end

return M
