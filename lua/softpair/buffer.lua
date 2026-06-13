-- SPDX-License-Identifier: GPL-3.0-or-later

local M = {}

function M.current()
  return vim.api.nvim_get_current_buf()
end

function M.cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return row - 1, col
end

function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

function M.line(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr or M.current(), row, row + 1, false)[1] or ""
end

function M.current_line()
  local bufnr = M.current()
  local row = M.cursor()
  return M.line(bufnr, row)
end

function M.current_mode()
  return vim.fn.mode(1)
end

function M.point_col(line)
  local _, col = M.cursor()
  local mode = M.current_mode()

  if mode:sub(1, 1) == "n" and #line > 0 then
    if col >= #line - 1 then
      return #line
    end

    return col
  end

  return col
end

function M.line_count(bufnr)
  return vim.api.nvim_buf_line_count(bufnr or M.current())
end

function M.get_text(bufnr, start_row, start_col, end_row, end_col)
  return vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
end

function M.set_text(bufnr, start_row, start_col, end_row, end_col, replacement)
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, replacement)
end

function M.text_from_lines(lines)
  return table.concat(lines, "\n")
end

function M.set_register(text, regtype)
  local register_type = regtype or (text:find("\n", 1, true) and "V" or "v")
  vim.fn.setreg('"', text, register_type)

  if vim.o.clipboard:find("unnamedplus", 1, true) then
    pcall(vim.fn.setreg, "+", text, register_type)
  end
end

function M.surrounding_chars()
  local bufnr = M.current()
  local row, col = M.cursor()
  local line = M.line(bufnr, row)
  local prev = col > 0 and line:sub(col, col) or ""
  local next = line:sub(col + 1, col + 1)
  return prev, next
end

function M.chars_at_point()
  local bufnr = M.current()
  local row, col = M.cursor()
  local line = M.line(bufnr, row)
  local current = line:sub(col + 1, col + 1)
  local after = line:sub(col + 2, col + 2)
  return current, after
end

return M
