-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source reference: GNU Emacs pulse/undo boundary behavior used by Puni.

local doc = require("softpair.doc")

local M = {}

local namespace = vim.api.nvim_create_namespace("softpair-feedback")

function M.undo_join()
  pcall(vim.cmd, "undojoin")
end

function M.highlight(start_pos, end_pos)
  if start_pos == end_pos then
    return
  end

  local lines = doc.lines()
  local start_row, start_col = doc.row_col_from_position(lines, math.min(start_pos, end_pos))
  local end_row, end_col = doc.row_col_from_position(lines, math.max(start_pos, end_pos))
  local ok = pcall(
    vim.highlight.range,
    0,
    namespace,
    "IncSearch",
    { start_row, start_col },
    { end_row, end_col },
    {
      inclusive = false,
    }
  )

  if ok then
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(0) then
        vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
      end
    end, 120)
  end
end

return M
