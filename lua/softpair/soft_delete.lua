-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source reference: Puni puni.el rev fe132f803868f325cf6f162139e327b76df9e4c1,
-- especially puni-soft-delete and puni-kill-line.

local buffer = require("softpair.buffer")
local config = require("softpair.config")
local doc = require("softpair.doc")
local sexp = require("softpair.sexp")
local syntax = require("softpair.syntax")

local M = {}

local function notify(message, level)
  if config.options.notify then
    vim.notify(message, level or vim.log.levels.INFO, { title = "softpair" })
  end
end

local function range_is_balanced(start_pos, end_pos)
  return syntax.is_balanced_span(
    doc.text(),
    math.min(start_pos, end_pos),
    math.max(start_pos, end_pos)
  )
end

local function deletion_exposes_candidate(start_pos, end_pos)
  return syntax.deletion_exposes_candidate(
    doc.text(),
    math.min(start_pos, end_pos),
    math.max(start_pos, end_pos),
    config.options
  )
end

local function range_is_safe_to_delete(start_pos, end_pos)
  return range_is_balanced(start_pos, end_pos)
    and not deletion_exposes_candidate(start_pos, end_pos)
end

local function is_candidate_at(text, pos)
  return syntax.is_structural_candidate(text, pos + 1, config.options)
    or syntax.is_string_delimiter(text, pos + 1, config.options)
end

local function is_adjacent_pair_at(text, point)
  local prev = text:sub(point, point)
  local next = text:sub(point + 1, point + 1)

  if prev == next and config.options.string_delimiters[prev] then
    return config.is_pair(prev, next)
      and syntax.is_string_open(text, point, config.options)
      and syntax.is_string_close(text, point + 1, config.options)
  end

  return config.is_pair(prev, next)
    and is_candidate_at(text, point - 1)
    and is_candidate_at(text, point)
end

local function is_forward_pair_at(text, point)
  local current = text:sub(point + 1, point + 1)
  local after = text:sub(point + 2, point + 2)

  if current == after and config.options.string_delimiters[current] then
    return config.is_pair(current, after)
      and syntax.is_string_open(text, point + 1, config.options)
      and syntax.is_string_close(text, point + 2, config.options)
  end

  return config.is_pair(current, after)
    and is_candidate_at(text, point)
    and is_candidate_at(text, point + 1)
end

local function warn_pair_break()
  notify(
    "Refusing to delete region: deletion would remove unmatched pair delimiter",
    vim.log.levels.WARN
  )
end

local function delete_range_guarded(start_pos, end_pos, kill, regtype, force)
  if start_pos == end_pos then
    return false
  end

  if not range_is_safe_to_delete(start_pos, end_pos) then
    if force then
      notify("Force deleting unmatched pair delimiter", vim.log.levels.WARN)
    else
      warn_pair_break()
      return false
    end
  end

  return doc.delete_range(buffer.current(), start_pos, end_pos, kill, regtype or "v")
end

local function next_char_pos(text, pos)
  if pos >= #text then
    return #text
  end

  local first = text:byte(pos + 1)
  if not first then
    return #text
  end

  local len
  if first < 0x80 then
    len = 1
  elseif first < 0xE0 then
    len = 2
  elseif first < 0xF0 then
    len = 3
  elseif first < 0xF8 then
    len = 4
  else
    len = 1
  end

  return math.min(pos + len, #text)
end

local function prev_char_pos(text, pos)
  local cursor = math.min(pos, #text)
  if cursor <= 0 then
    return 0
  end

  while cursor > 1 do
    local byte = text:byte(cursor)
    if not byte or byte < 0x80 or byte >= 0xC0 then
      break
    end
    cursor = cursor - 1
  end

  return cursor - 1
end

local function advance_chars(text, pos, count)
  local cursor = pos
  for _ = 1, count do
    cursor = next_char_pos(text, cursor)
  end
  return cursor
end

local function retreat_chars(text, pos, count)
  local cursor = pos
  for _ = 1, count do
    cursor = prev_char_pos(text, cursor)
  end
  return cursor
end

local function kill_range()
  local bufnr = buffer.current()
  local row = buffer.cursor()
  local line = buffer.line(bufnr, row)
  local col = buffer.kill_line_col(line)
  local line_count = buffer.line_count(bufnr)
  local lines = doc.lines(bufnr)

  if col < #line then
    local range_lines = buffer.get_text(bufnr, row, col, row, #line)

    return {
      bufnr = bufnr,
      start_row = row,
      start_col = col,
      end_row = row,
      end_col = #line,
      start_pos = doc.position_from_row_col(lines, row, col),
      end_pos = doc.position_from_row_col(lines, row, #line),
      text = buffer.text_from_lines(range_lines),
      regtype = "v",
    }
  end

  if row + 1 < line_count then
    return {
      bufnr = bufnr,
      start_row = row,
      start_col = #line,
      end_row = row + 1,
      end_col = 0,
      start_pos = doc.position_from_row_col(lines, row, #line),
      end_pos = doc.position_from_row_col(lines, row + 1, 0),
      text = "\n",
      regtype = "v",
    }
  end
end

function M.kill_line()
  local target = kill_range()

  if not target or target.text == "" then
    return false
  end

  if not range_is_safe_to_delete(target.start_pos, target.end_pos) then
    notify(
      "Refusing to kill line: deletion would remove an unmatched delimiter",
      vim.log.levels.WARN
    )
    return false
  end

  buffer.set_register(target.text, target.regtype)
  buffer.set_text(
    target.bufnr,
    target.start_row,
    target.start_col,
    target.end_row,
    target.end_col,
    {}
  )

  return true
end

function M.backward_kill_line()
  local text = doc.text()
  local point = doc.point()
  local line_start = point

  while line_start > 0 and text:sub(line_start, line_start) ~= "\n" do
    line_start = line_start - 1
  end

  if line_start == point then
    return false
  end

  return delete_range_guarded(line_start, point, true, "v")
end

function M.delete_region(start_pos, end_pos)
  return delete_range_guarded(start_pos, end_pos, false, "v")
end

function M.kill_region(start_pos, end_pos)
  return delete_range_guarded(start_pos, end_pos, true, "v")
end

function M.delete_region_keep_balanced(start_pos, end_pos, _strict, kill)
  if not range_is_safe_to_delete(start_pos, end_pos) then
    warn_pair_break()
    return false
  end

  return doc.delete_range(buffer.current(), start_pos, end_pos, kill, "v")
end

function M.soft_delete(from, to, _strict, style, kill, _fail_action, return_region)
  local start_pos = math.min(from, to)
  local end_pos = math.max(from, to)

  if style == "within" or style == "beyond" then
    local text = doc.text()
    local cursor = from
    local last = from
    local forward = from < to
    while (forward and cursor < to) or ((not forward) and cursor > to) do
      local next_pos = forward and sexp.forward_pos(text, cursor, 1)
        or sexp.backward_pos(text, cursor, 1)
      if not next_pos or next_pos == cursor then
        break
      end
      if
        style == "within" and ((forward and next_pos > to) or ((not forward) and next_pos < to))
      then
        break
      end
      last = next_pos
      cursor = next_pos
      if style == "beyond" and ((forward and cursor >= to) or ((not forward) and cursor <= to)) then
        break
      end
    end
    start_pos = math.min(from, last)
    end_pos = math.max(from, last)
  end

  if start_pos == end_pos then
    return false
  end

  if not range_is_safe_to_delete(start_pos, end_pos) then
    warn_pair_break()
    return false
  end

  if return_region then
    return { start = start_pos, finish = end_pos }
  end

  return doc.delete_range(buffer.current(), start_pos, end_pos, kill, "v")
end

function M.soft_delete_by_move(move, strict, style, kill, fail_action)
  local from = doc.point()
  local to = move()
  if not to then
    return false
  end
  return M.soft_delete(from, to, strict, style, kill, fail_action)
end

local function active_region_range(visual_mode)
  if visual_mode == "\22" then
    notify("Blockwise regions are not supported yet", vim.log.levels.WARN)
    return nil
  end

  local start = vim.fn.getpos("'<")
  local finish = vim.fn.getpos("'>")
  if start[2] == 0 or finish[2] == 0 then
    return nil
  end

  local lines = doc.lines()
  local start_row = start[2] - 1
  local finish_row = finish[2] - 1
  local start_col = start[3] - 1
  local finish_col = finish[3]

  if start_row > finish_row or (start_row == finish_row and start_col > finish_col) then
    start_row, finish_row = finish_row, start_row
    start_col, finish_col = finish_col, start_col
  end

  if visual_mode == "V" then
    local end_pos
    if finish_row + 1 < #lines then
      end_pos = doc.position_from_row_col(lines, finish_row + 1, 0)
    else
      end_pos = doc.position_from_row_col(lines, finish_row, #(lines[finish_row + 1] or ""))
    end

    return doc.position_from_row_col(lines, start_row, 0), end_pos, "V"
  end

  local start_pos = doc.position_from_row_col(lines, start_row, start_col)
  local end_pos = doc.position_from_row_col(lines, finish_row, finish_col)
  return math.min(start_pos, end_pos), math.max(start_pos, end_pos), "v"
end

function M.delete_active_region(visual_mode)
  local start_pos, end_pos, regtype = active_region_range(visual_mode)
  if not start_pos then
    return false
  end

  return delete_range_guarded(start_pos, end_pos, false, regtype)
end

function M.kill_active_region(visual_mode)
  local start_pos, end_pos, regtype = active_region_range(visual_mode)
  if not start_pos then
    return false
  end

  return delete_range_guarded(start_pos, end_pos, true, regtype)
end

function M.backward_delete_char(count, force)
  local text = doc.text()
  local point = doc.point()
  local n = count or 1

  if n < 0 then
    return M.forward_delete_char(-n, force)
  end

  if n <= 0 or point <= 0 then
    return true
  end

  if n == 1 and is_adjacent_pair_at(text, point) then
    return delete_range_guarded(point - 1, point + 1, false, "v", force)
  end

  return delete_range_guarded(retreat_chars(text, point, n), point, false, "v", force)
end

function M.forward_delete_char(count, force)
  local text = doc.text()
  local point = doc.point()
  local n = count or 1

  if n < 0 then
    return M.backward_delete_char(-n, force)
  end

  if n <= 0 or point >= #text then
    return true
  end

  if n == 1 and is_forward_pair_at(text, point) then
    return delete_range_guarded(point, point + 2, false, "v", force)
  end

  return delete_range_guarded(point, advance_chars(text, point, n), false, "v", force)
end

function M.forward_kill_word(count)
  local text = doc.text()
  local point = doc.point()
  local target = point
  for _ = 1, count or 1 do
    local bounds = sexp.next_bounds(text, target)
    if not bounds then
      return false
    end
    target = bounds.finish
  end
  return delete_range_guarded(point, target, true, "v")
end

function M.backward_kill_word(count)
  local text = doc.text()
  local point = doc.point()
  local target = point
  for _ = 1, count or 1 do
    local bounds = sexp.prev_bounds(text, target)
    if not bounds then
      return false
    end
    target = bounds.start
  end
  return delete_range_guarded(target, point, true, "v")
end

function M.force_delete(count)
  return M.forward_delete_char(count or 1, true)
end

return M
