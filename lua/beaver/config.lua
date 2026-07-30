local M = {}

M.defaults = {
  allow_editing = false,
  sign_text = "▎",
  sign_hl_group = "DiffAdd",
  divider_hl_group = "Comment",
  poll_interval_ms = 5000,
  mock_interval_ms = 500,
  keymaps = {
    pause = "<leader>Lp",
    toggle_preview = "<leader>Lv",
    clear_marks = "<leader>Lc",
  },
}

function M.resolve(user_opts)
  return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
