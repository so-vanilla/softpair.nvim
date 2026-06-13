-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source reference: GNU Emacs electric-pair behavior.

local buffer = require("softpair.buffer")
local config = require("softpair.config")
local doc = require("softpair.doc")
local syntax = require("softpair.syntax")

local M = {}

local function keys(text)
  return text
end

local function notify(message)
  if config.options.notify then
    vim.notify(message, vim.log.levels.WARN, { title = "softpair" })
  end
end

local function current_context()
  local bufnr = buffer.current()
  local row, col = buffer.cursor()
  local lines = doc.lines(bufnr)
  return table.concat(lines, "\n"), doc.position_from_row_col(lines, row, col)
end

local function is_protected_candidate(text, pos, char)
  if char == "" then
    return false
  end

  return syntax.is_protected_candidate(text, pos + 1, config.options)
end

local function is_adjacent_pair(text, point, open, close)
  if not config.is_pair(open, close) then
    return false
  end

  if open == close and config.options.string_delimiters[open] then
    return syntax.is_string_open(text, point, config.options)
      and syntax.is_string_close(text, point + 1, config.options)
  end

  return is_protected_candidate(text, point - 1, open)
    and is_protected_candidate(text, point, close)
end

local function is_forward_pair(text, point, open, close)
  if not config.is_pair(open, close) then
    return false
  end

  if open == close and config.options.string_delimiters[open] then
    return syntax.is_string_open(text, point + 1, config.options)
      and syntax.is_string_close(text, point + 2, config.options)
  end

  return is_protected_candidate(text, point, open)
    and is_protected_candidate(text, point + 1, close)
end

local function deletion_exposes_candidate(text, start_pos, end_pos)
  if start_pos == end_pos then
    return false
  end

  return syntax.deletion_exposes_candidate(text, start_pos, end_pos, config.options)
end

local function refuse_pair_break()
  notify("Refusing to delete unmatched pair delimiter")
  return ""
end

function M.expr_open(open)
  local close = config.close_for(open)
  if not close then
    return open
  end

  return keys(open .. close .. "<Left>")
end

function M.expr_quote(quote)
  local bufnr = buffer.current()
  local row, col = buffer.cursor()
  local line = buffer.line(bufnr, row)
  local _, next = buffer.surrounding_chars()

  if syntax.is_escaped(line, col + 1) then
    return quote
  end

  if next == quote then
    return keys("<Right>")
  end

  return keys(quote .. quote .. "<Left>")
end

function M.expr_close(close)
  local _, next = buffer.surrounding_chars()

  if next == close then
    return keys("<Right>")
  end

  return close
end

function M.expr_backspace()
  local text, point = current_context()
  local prev, next = buffer.surrounding_chars()

  if is_adjacent_pair(text, point, prev, next) then
    return keys("<BS><Del>")
  end

  if is_protected_candidate(text, point - 1, prev) then
    return refuse_pair_break()
  end

  if deletion_exposes_candidate(text, point - 1, point) then
    return refuse_pair_break()
  end

  return keys("<BS>")
end

function M.expr_delete()
  local text, point = current_context()
  local current, after = buffer.chars_at_point()

  if is_forward_pair(text, point, current, after) then
    return keys("<Del><Del>")
  end

  if is_protected_candidate(text, point, current) then
    return refuse_pair_break()
  end

  if deletion_exposes_candidate(text, point, point + 1) then
    return refuse_pair_break()
  end

  return keys("<Del>")
end

function M.wrap_visual(open)
  local close = config.close_for(open)
  if not close then
    return
  end

  local start = vim.fn.getpos("'<")
  local finish = vim.fn.getpos("'>")
  local start_row = start[2] - 1
  local start_col = start[3] - 1
  local end_row = finish[2] - 1
  local end_col = finish[3]

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local bufnr = buffer.current()
  buffer.set_text(bufnr, end_row, end_col, end_row, end_col, { close })
  buffer.set_text(bufnr, start_row, start_col, start_row, start_col, { open })
end

return M
