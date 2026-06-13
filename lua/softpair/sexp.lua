-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source reference: Puni puni.el rev fe132f803868f325cf6f162139e327b76df9e4c1,
-- especially strict sexp movement and bounds APIs.

local config = require("softpair.config")
local doc = require("softpair.doc")
local syntax = require("softpair.syntax")

local M = {}

local function char_at(text, pos)
  if pos < 0 or pos >= #text then
    return ""
  end

  return text:sub(pos + 1, pos + 1)
end

local function is_space(char)
  return char:match("%s") ~= nil
end

local function closing_pairs()
  return syntax.closing_pairs(config.options)
end

local function is_candidate(text, pos)
  return syntax.is_candidate(text, pos + 1, config.options)
end

local function is_structural_candidate(text, pos)
  return syntax.is_structural_candidate(text, pos + 1, config.options)
end

local function is_string_open_at(text, pos)
  return syntax.is_string_open(text, pos + 1, config.options)
end

local function is_string_close_at(text, pos)
  return syntax.is_string_close(text, pos + 1, config.options)
end

local function is_string_boundary_at(text, pos)
  return is_string_open_at(text, pos) or is_string_close_at(text, pos)
end

local function is_open_at(text, pos)
  return is_structural_candidate(text, pos) and config.options.pairs[char_at(text, pos)] ~= nil
end

local function is_close_at(text, pos)
  return is_structural_candidate(text, pos) and closing_pairs()[char_at(text, pos)] ~= nil
end

local function is_delimiter_at(text, pos)
  local char = char_at(text, pos)
  return char == ""
    or is_space(char)
    or is_open_at(text, pos)
    or is_close_at(text, pos)
    or is_string_boundary_at(text, pos)
end

local function skip_spaces_forward(text, pos, limit)
  local cursor = pos
  local max = limit or #text
  while cursor < max and is_space(char_at(text, cursor)) do
    cursor = cursor + 1
  end
  return cursor
end

local function skip_spaces_backward(text, pos, limit)
  local cursor = pos
  local min = limit or 0
  while cursor > min and is_space(char_at(text, cursor - 1)) do
    cursor = cursor - 1
  end
  return cursor
end

local function scan_string_forward(text, pos)
  local delimiter = char_at(text, pos)
  local cursor = pos + 1
  while cursor < #text do
    if
      char_at(text, cursor) == delimiter
      and is_candidate(text, cursor)
      and is_string_close_at(text, cursor)
    then
      return cursor + 1
    end
    cursor = cursor + 1
  end
end

local function scan_string_backward(text, pos)
  local delimiter = char_at(text, math.min(pos - 1, #text - 1))
  local cursor = math.min(pos - 2, #text - 2)
  while cursor >= 0 do
    if
      char_at(text, cursor) == delimiter
      and is_candidate(text, cursor)
      and is_string_open_at(text, cursor)
    then
      return cursor
    end
    cursor = cursor - 1
  end
end

function M.match_forward(text, open_pos)
  local open = char_at(text, open_pos)
  local close = config.options.pairs[open]
  if not close or not is_structural_candidate(text, open_pos) then
    return nil
  end

  local stack = { open }
  local cursor = open_pos + 1

  while cursor < #text do
    local char = char_at(text, cursor)

    if is_string_open_at(text, cursor) then
      cursor = scan_string_forward(text, cursor) or #text
    elseif is_open_at(text, cursor) then
      stack[#stack + 1] = char
      cursor = cursor + 1
    elseif is_close_at(text, cursor) then
      if stack[#stack] ~= closing_pairs()[char] then
        return nil
      end

      stack[#stack] = nil
      if #stack == 0 then
        return cursor
      end
      cursor = cursor + 1
    else
      cursor = cursor + 1
    end
  end
end

function M.match_backward(text, close_pos)
  local close = char_at(text, close_pos)
  local open = closing_pairs()[close]
  if not open or not is_structural_candidate(text, close_pos) then
    return nil
  end

  local stack = { close }
  local cursor = close_pos - 1

  while cursor >= 0 do
    local char = char_at(text, cursor)

    if is_string_close_at(text, cursor) then
      cursor = (scan_string_backward(text, cursor + 1) or 0) - 1
    elseif is_close_at(text, cursor) then
      stack[#stack + 1] = char
      cursor = cursor - 1
    elseif is_open_at(text, cursor) then
      if config.options.pairs[char] ~= stack[#stack] then
        return nil
      end

      stack[#stack] = nil
      if #stack == 0 then
        return cursor
      end
      cursor = cursor - 1
    else
      cursor = cursor - 1
    end
  end
end

local function symbol_forward(text, pos)
  local cursor = pos
  while cursor < #text and not is_delimiter_at(text, cursor) do
    cursor = cursor + 1
  end

  if cursor > pos then
    return { start = pos, finish = cursor, type = "symbol" }
  end
end

local function symbol_backward(text, pos)
  local cursor = pos
  while cursor > 0 and not is_delimiter_at(text, cursor - 1) do
    cursor = cursor - 1
  end

  if cursor < pos then
    return { start = cursor, finish = pos, type = "symbol" }
  end
end

function M.next_bounds(text, pos)
  local start = skip_spaces_forward(text, pos)
  local char = char_at(text, start)

  if char == "" or is_close_at(text, start) then
    return nil
  end

  if is_string_open_at(text, start) then
    local finish = scan_string_forward(text, start)
    return finish and { start = start, finish = finish, type = "string" }
  end

  if is_open_at(text, start) then
    local close = M.match_forward(text, start)
    return close and { start = start, finish = close + 1, type = "list" }
  end

  return symbol_forward(text, start)
end

function M.prev_bounds(text, pos)
  local finish = skip_spaces_backward(text, pos)
  local char = char_at(text, finish - 1)

  if char == "" or is_open_at(text, finish - 1) then
    return nil
  end

  if is_string_close_at(text, finish - 1) then
    local start = scan_string_backward(text, finish)
    return start and { start = start, finish = finish, type = "string" }
  end

  if is_close_at(text, finish - 1) then
    local open = M.match_backward(text, finish - 1)
    return open and { start = open, finish = finish, type = "list" }
  end

  return symbol_backward(text, finish)
end

function M.enclosing_list(text, pos)
  local stack = {}
  local cursor = 0

  while cursor < #text and cursor <= pos do
    local char = char_at(text, cursor)

    if is_string_open_at(text, cursor) then
      cursor = scan_string_forward(text, cursor) or #text
    elseif is_open_at(text, cursor) then
      local close = M.match_forward(text, cursor)
      if close and cursor < pos and pos <= close then
        stack[#stack + 1] = { start = cursor, finish = close + 1, type = "list" }
      end
      cursor = cursor + 1
    elseif is_close_at(text, cursor) then
      cursor = cursor + 1
    else
      cursor = cursor + 1
    end
  end

  return stack[#stack]
end

function M.atom_at(text, pos)
  local point = math.min(math.max(pos, 0), #text)
  local start = point
  while start > 0 and not is_delimiter_at(text, start - 1) do
    start = start - 1
  end

  local finish = point
  while finish < #text and not is_delimiter_at(text, finish) do
    finish = finish + 1
  end

  if finish > start then
    return { start = start, finish = finish, type = "symbol" }
  end
end

function M.bounds_at_point(text, pos)
  local point = pos or doc.point()

  if is_open_at(text, point) then
    local close = M.match_forward(text, point)
    return close and { start = point, finish = close + 1, type = "list" }
  end

  if is_close_at(text, point) then
    local open = M.match_backward(text, point)
    return open and { start = open, finish = point + 1, type = "list" }
  end

  if is_string_open_at(text, point) then
    local forward = scan_string_forward(text, point)
    if forward then
      return { start = point, finish = forward, type = "string" }
    end
  end

  if is_string_close_at(text, point) then
    local start = scan_string_backward(text, point + 1)
    if start then
      return { start = start, finish = point + 1, type = "string" }
    end
  end

  local atom = M.atom_at(text, point)
  if atom then
    return atom
  end

  return M.next_bounds(text, point) or M.prev_bounds(text, point)
end

function M.bounds_around_point(text, pos)
  local point = pos or doc.point()
  return M.enclosing_list(text, point) or M.bounds_at_point(text, point)
end

function M.list_bounds_around_point(text, pos)
  local bounds = M.enclosing_list(text, pos or doc.point())
  if not bounds then
    return { start = 0, finish = #text, type = "top" }
  end

  return { start = bounds.start + 1, finish = bounds.finish - 1, type = "list-inner" }
end

function M.forward_pos(text, pos, count)
  local cursor = pos
  for _ = 1, count or 1 do
    local bounds = M.next_bounds(text, cursor)
    if not bounds then
      return nil
    end
    cursor = bounds.finish
  end
  return cursor
end

function M.backward_pos(text, pos, count)
  local cursor = pos
  for _ = 1, count or 1 do
    local bounds = M.prev_bounds(text, cursor)
    if not bounds then
      return nil
    end
    cursor = bounds.start
  end
  return cursor
end

function M.forward(count)
  local text = doc.text()
  local target = M.forward_pos(text, doc.point(), count or 1)
  if target then
    doc.set_point(target)
  end
  return target
end

function M.backward(count)
  local text = doc.text()
  local target = M.backward_pos(text, doc.point(), count or 1)
  if target then
    doc.set_point(target)
  end
  return target
end

function M.up(backward)
  local text = doc.text()
  local bounds = M.bounds_around_point(text, doc.point())
  if not bounds then
    return nil
  end

  local target = backward and bounds.start or bounds.finish
  doc.set_point(target)
  return target
end

function M.beginning_of_list()
  local text = doc.text()
  local bounds = M.list_bounds_around_point(text, doc.point())
  doc.set_point(bounds.start)
  return bounds.start
end

function M.end_of_list()
  local text = doc.text()
  local bounds = M.list_bounds_around_point(text, doc.point())
  doc.set_point(bounds.finish)
  return bounds.finish
end

function M.beginning_of_sexp()
  local text = doc.text()
  local bounds = M.bounds_around_point(text, doc.point())
  if bounds then
    doc.set_point(bounds.start)
    return bounds.start
  end
end

function M.end_of_sexp()
  local text = doc.text()
  local bounds = M.bounds_around_point(text, doc.point())
  if bounds then
    doc.set_point(bounds.finish)
    return bounds.finish
  end
end

function M.region_balance(start_pos, end_pos)
  local text = doc.text()
  return require("softpair.syntax").is_balanced_span(text, start_pos, end_pos)
end

function M.dangling_delimiter(pos)
  local text = doc.text()
  local point = pos or doc.point()
  local char = char_at(text, point)

  if is_open_at(text, point) then
    return M.match_forward(text, point) == nil
  end

  if is_close_at(text, point) then
    return M.match_backward(text, point) == nil
  end

  return false
end

function M.syntactic_forward_punct()
  local text = doc.text()
  local pos = skip_spaces_forward(text, doc.point())
  while pos < #text and is_delimiter_at(text, pos) and not is_space(char_at(text, pos)) do
    pos = pos + 1
  end
  doc.set_point(pos)
  return pos
end

function M.syntactic_backward_punct()
  local text = doc.text()
  local pos = skip_spaces_backward(text, doc.point())
  while pos > 0 and is_delimiter_at(text, pos - 1) and not is_space(char_at(text, pos - 1)) do
    pos = pos - 1
  end
  doc.set_point(pos)
  return pos
end

return M
