-- SPDX-License-Identifier: GPL-3.0-or-later

local buffer = require("softpair.buffer")

local M = {}

function M.lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr or buffer.current(), 0, -1, false)
end

function M.text(bufnr)
  return table.concat(M.lines(bufnr), "\n")
end

function M.line_offsets(lines)
  local offsets = {}
  local pos = 0

  for index, line in ipairs(lines) do
    offsets[index] = pos
    pos = pos + #line + 1
  end

  return offsets
end

function M.position_from_row_col(lines, row, col)
  local offsets = M.line_offsets(lines)
  return (offsets[row + 1] or 0) + col
end

function M.row_col_from_position(lines, position)
  local pos = math.max(position, 0)
  local offset = 0

  for row, line in ipairs(lines) do
    local line_end = offset + #line
    if pos <= line_end then
      return row - 1, pos - offset
    end
    offset = line_end + 1
  end

  local last_row = math.max(#lines - 1, 0)
  local last_line = lines[#lines] or ""
  return last_row, #last_line
end

function M.point(bufnr)
  local target = bufnr or buffer.current()
  local row = buffer.cursor()
  local line = buffer.line(target, row)
  local col = buffer.point_col(line)
  return M.position_from_row_col(M.lines(target), row, col)
end

function M.set_point(position)
  local lines = M.lines()
  local row, col = M.row_col_from_position(lines, position)
  local line = lines[row + 1] or ""
  local mode = buffer.current_mode()

  if mode:sub(1, 1) == "n" and #line > 0 then
    col = math.min(col, #line - 1)
  end

  vim.api.nvim_win_set_cursor(0, { row + 1, math.max(col, 0) })
end

function M.range_from_positions(bufnr, start_pos, end_pos)
  local lines = M.lines(bufnr)
  local start_row, start_col = M.row_col_from_position(lines, start_pos)
  local end_row, end_col = M.row_col_from_position(lines, end_pos)
  return start_row, start_col, end_row, end_col
end

function M.get_range(bufnr, start_pos, end_pos)
  local start_row, start_col, end_row, end_col = M.range_from_positions(bufnr, start_pos, end_pos)
  return buffer.text_from_lines(buffer.get_text(bufnr, start_row, start_col, end_row, end_col))
end

function M.set_range(bufnr, start_pos, end_pos, replacement)
  local start_row, start_col, end_row, end_col = M.range_from_positions(bufnr, start_pos, end_pos)
  local lines = type(replacement) == "table" and replacement
    or vim.split(replacement, "\n", { plain = true })
  buffer.set_text(bufnr, start_row, start_col, end_row, end_col, lines)
end

function M.delete_range(bufnr, start_pos, end_pos, kill, regtype)
  if start_pos == end_pos then
    return false
  end

  local start_actual = math.min(start_pos, end_pos)
  local end_actual = math.max(start_pos, end_pos)
  local text = M.get_range(bufnr, start_actual, end_actual)

  if kill then
    buffer.set_register(text, regtype)
  end

  M.set_range(bufnr, start_actual, end_actual, "")
  return true
end

function M.insert_text(bufnr, position, text)
  M.set_range(bufnr, position, position, text)
end

return M
