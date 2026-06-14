-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source reference: Puni puni.el rev fe132f803868f325cf6f162139e327b76df9e4c1,
-- especially slurp/barf/splice/squeeze/split/raise/wrap APIs.

local buffer = require("softpair.buffer")
local config = require("softpair.config")
local doc = require("softpair.doc")
local feedback = require("softpair.feedback")
local sexp = require("softpair.sexp")
local syntax = require("softpair.syntax")

local M = {}

local function current_text_point()
  return doc.text(), doc.point()
end

local function set_register_range(start_pos, end_pos)
  buffer.set_register(doc.get_range(buffer.current(), start_pos, end_pos), "v")
end

local function pair_for(open)
  return config.close_for(open)
end

local function char_at(text, pos)
  if pos < 0 or pos >= #text then
    return ""
  end
  return text:sub(pos + 1, pos + 1)
end

local function is_space(char)
  return char:match("%s") ~= nil
end

local function skip_spaces_backward(text, pos, limit)
  local cursor = pos
  local min = limit or 0
  while cursor > min and is_space(char_at(text, cursor - 1)) do
    cursor = cursor - 1
  end
  return cursor
end

local function skip_spaces_forward(text, pos, limit)
  local cursor = pos
  local max = limit or #text
  while cursor < max and is_space(char_at(text, cursor)) do
    cursor = cursor + 1
  end
  return cursor
end

local function insert_pair(start_pos, finish_pos, open, close)
  local bufnr = buffer.current()
  feedback.highlight(start_pos, finish_pos)
  doc.insert_text(bufnr, finish_pos, close)
  feedback.undo_join()
  doc.insert_text(bufnr, start_pos, open)
end

local function point_in_string(text, point)
  local index = point + 1
  return syntax.is_in_string(text, index, config.options)
    or syntax.is_string_open(text, index, config.options)
    or syntax.is_string_close(text, index, config.options)
end

local function list_bounds_for_edit(text, point)
  if point_in_string(text, point) then
    return nil
  end

  local at_point = sexp.bounds_at_point(text, point)
  if
    at_point
    and at_point.type == "list"
    and (at_point.start == point or at_point.finish - 1 == point)
  then
    return at_point
  end

  local around = sexp.bounds_around_point(text, point)
  if not around or around.type ~= "list" then
    return nil
  end

  return around
end

local function inner_bounds(around)
  return { start = around.start + 1, finish = around.finish - 1, type = "list-inner" }
end

local function list_bounds_matching_open(text, point, open)
  if point_in_string(text, point) then
    return nil
  end

  local best = nil
  for pos = 0, #text - 1 do
    if char_at(text, pos) == open then
      local close = sexp.match_forward(text, pos)
      if close and pos <= point and point <= close + 1 then
        best = { start = pos, finish = close + 1, type = "list" }
      end
    end
  end

  return best
end

function M.squeeze()
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end
  local inner = inner_bounds(around)

  set_register_range(inner.start, inner.finish)
  feedback.highlight(around.start, around.finish)
  doc.delete_range(buffer.current(), around.start, around.finish, false)
  return true
end

function M.splice()
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end

  local bufnr = buffer.current()
  feedback.highlight(around.start, around.finish)
  doc.delete_range(bufnr, around.finish - 1, around.finish, false)
  feedback.undo_join()
  doc.delete_range(bufnr, around.start, around.start + 1, false)
  doc.set_point(around.start)
  return true
end

function M.splice_killing_backward()
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end
  local inner = inner_bounds(around)
  if point <= inner.start then
    return M.splice()
  end

  doc.delete_range(buffer.current(), inner.start, point, true, "v")
  return M.splice()
end

function M.splice_killing_forward()
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end
  local inner = inner_bounds(around)
  if point >= inner.finish then
    return M.splice()
  end

  doc.delete_range(buffer.current(), point, inner.finish, true, "v")
  return M.splice()
end

function M.slurp_forward(count)
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end

  local close_start = around.finish - 1
  local next_bounds = sexp.next_bounds(text, around.finish)
  if not next_bounds then
    return false
  end

  local close = text:sub(around.finish, around.finish)
  local target = next_bounds.finish
  for _ = 2, count or 1 do
    local next_next = sexp.next_bounds(text, target)
    if not next_next then
      break
    end
    target = next_next.finish
  end

  local bufnr = buffer.current()
  feedback.highlight(around.start, target)
  doc.delete_range(bufnr, close_start, around.finish, false)
  feedback.undo_join()
  doc.insert_text(bufnr, target - 1, close)
  return true
end

function M.slurp_backward(count)
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end

  local prev_bounds = sexp.prev_bounds(text, around.start)
  if not prev_bounds then
    return false
  end

  local target = prev_bounds.start
  for _ = 2, count or 1 do
    local prev_prev = sexp.prev_bounds(text, target)
    if not prev_prev then
      break
    end
    target = prev_prev.start
  end

  local open = text:sub(around.start + 1, around.start + 1)
  local bufnr = buffer.current()
  feedback.highlight(target, around.finish)
  doc.delete_range(bufnr, around.start, around.start + 1, false)
  feedback.undo_join()
  doc.insert_text(bufnr, target, open)
  return true
end

function M.barf_forward(count)
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end
  local inner = inner_bounds(around)

  local last_inside = sexp.prev_bounds(text, inner.finish)
  if not last_inside or last_inside.start <= inner.start then
    return false
  end

  local target = skip_spaces_backward(text, last_inside.start, inner.start)
  for _ = 2, count or 1 do
    local prev_prev = sexp.prev_bounds(text, target)
    if not prev_prev or prev_prev.start < inner.start then
      break
    end
    target = skip_spaces_backward(text, prev_prev.start, inner.start)
  end

  local close = text:sub(around.finish, around.finish)
  local bufnr = buffer.current()
  feedback.highlight(target, around.finish)
  doc.delete_range(bufnr, around.finish - 1, around.finish, false)
  feedback.undo_join()
  doc.insert_text(bufnr, target, close)
  return true
end

function M.barf_backward(count)
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end
  local inner = inner_bounds(around)

  local first_inside = sexp.next_bounds(text, inner.start)
  if not first_inside or first_inside.finish >= inner.finish then
    return false
  end

  local target = skip_spaces_forward(text, first_inside.finish, inner.finish)
  for _ = 2, count or 1 do
    local next_next = sexp.next_bounds(text, target)
    if not next_next or next_next.finish > inner.finish then
      break
    end
    target = skip_spaces_forward(text, next_next.finish, inner.finish)
  end

  local open = text:sub(around.start + 1, around.start + 1)
  local bufnr = buffer.current()
  feedback.highlight(around.start, target)
  doc.delete_range(bufnr, around.start, around.start + 1, false)
  feedback.undo_join()
  doc.insert_text(bufnr, target - 1, open)
  return true
end

function M.split()
  local text, point = current_text_point()
  local around = list_bounds_for_edit(text, point)
  if not around then
    return false
  end

  local open = text:sub(around.start + 1, around.start + 1)
  local close = text:sub(around.finish, around.finish)
  feedback.highlight(point, point + #close + #open)
  doc.insert_text(buffer.current(), point, close .. open)
  doc.set_point(point + #close)
  return true
end

function M.raise()
  local text, point = current_text_point()
  if point_in_string(text, point) then
    return false
  end

  local target = sexp.bounds_at_point(text, point)
  local parent = sexp.bounds_around_point(text, point)
  if not target or not parent or parent.type ~= "list" then
    return false
  end

  local replacement = text:sub(target.start + 1, target.finish)
  local bufnr = buffer.current()
  feedback.highlight(parent.start, parent.finish)
  doc.set_range(bufnr, parent.start, parent.finish, replacement)
  doc.set_point(parent.start)
  return true
end

function M.transpose()
  local text, point = current_text_point()
  if point_in_string(text, point) then
    return false
  end

  local before = sexp.prev_bounds(text, point)
  local after = sexp.next_bounds(text, point)
  if not before or not after or before.finish > after.start then
    return false
  end

  local before_text = text:sub(before.start + 1, before.finish)
  local middle = text:sub(before.finish + 1, after.start)
  local after_text = text:sub(after.start + 1, after.finish)
  feedback.highlight(before.start, after.finish)
  doc.set_range(buffer.current(), before.start, after.finish, after_text .. middle .. before_text)
  doc.set_point(before.start + #after_text + #middle)
  return true
end

function M.convolute()
  local text, point = current_text_point()
  local inner = list_bounds_for_edit(text, point)
  if not inner then
    return false
  end

  local outer = sexp.bounds_around_point(text, inner.start)
  if not outer or outer.start == inner.start or outer.type ~= "list" then
    return false
  end

  local inner_open = text:sub(inner.start + 1, inner.start + 1)
  local inner_close = text:sub(inner.finish, inner.finish)
  local outer_open = text:sub(outer.start + 1, outer.start + 1)
  local outer_close = text:sub(outer.finish, outer.finish)
  local before_inner = text:sub(outer.start + 2, inner.start)
  local inner_body = text:sub(inner.start + 2, inner.finish - 1)
  local after_inner = text:sub(inner.finish + 1, outer.finish - 1)
  local replacement = inner_open
    .. inner_body
    .. " "
    .. outer_open
    .. before_inner
    .. after_inner
    .. outer_close
    .. inner_close

  feedback.highlight(outer.start, outer.finish)
  doc.set_range(buffer.current(), outer.start, outer.finish, replacement)
  doc.set_point(outer.start + #inner_open + #inner_body + 1)
  return true
end

function M.wrap_next_sexps(count, open, close)
  local text, point = current_text_point()
  if point_in_string(text, point) then
    return false
  end

  local end_pos

  if count == "to-end" then
    end_pos = sexp.list_bounds_around_point(text, point).finish
  elseif count == "to-beg" then
    local start_pos = sexp.list_bounds_around_point(text, point).start
    insert_pair(start_pos, point, open, close)
    doc.set_point(start_pos + #open)
    return true
  else
    local n = count or 1
    end_pos = n >= 0 and sexp.forward_pos(text, point, n) or point
    if n < 0 then
      local start_pos = sexp.backward_pos(text, point, math.abs(n))
      if not start_pos then
        return false
      end
      insert_pair(start_pos, point, open, close)
      doc.set_point(start_pos + #open)
      return true
    end
  end

  if not end_pos then
    return false
  end

  local start = sexp.next_bounds(text, point)
  if not start then
    return false
  end

  insert_pair(start.start, end_pos, open, close)
  doc.set_point(start.start + #open)
  return true
end

function M.wrap_round(count)
  return M.wrap_next_sexps(count or 1, "(", ")")
end

function M.wrap_square(count)
  return M.wrap_next_sexps(count or 1, "[", "]")
end

function M.wrap_curly(count)
  return M.wrap_next_sexps(count or 1, "{", "}")
end

function M.wrap_angle(count)
  return M.wrap_next_sexps(count or 1, "<", ">")
end

function M.change_inner(open)
  local text, point = current_text_point()
  local around = list_bounds_matching_open(text, point, open)
  if not around then
    return false
  end

  doc.delete_range(buffer.current(), around.start + 1, around.finish - 1, true, "v")
  return true
end

function M.copy_inner(open)
  local text, point = current_text_point()
  local around = list_bounds_matching_open(text, point, open)
  if not around then
    return false
  end

  set_register_range(around.start + 1, around.finish - 1)
  return true
end

function M.change_outer(open)
  local text, point = current_text_point()
  local around = list_bounds_matching_open(text, point, open)
  if not around then
    return false
  end

  doc.delete_range(buffer.current(), around.start, around.finish, true, "v")
  return true
end

function M.copy_outer(open)
  local text, point = current_text_point()
  local around = list_bounds_matching_open(text, point, open)
  if not around then
    return false
  end

  set_register_range(around.start, around.finish)
  return true
end

function M.wrap_visual(open)
  local close = pair_for(open)
  if not close then
    return false
  end

  local start = vim.fn.getpos("'<")
  local finish = vim.fn.getpos("'>")
  local lines = doc.lines()
  local start_pos = doc.position_from_row_col(lines, start[2] - 1, start[3] - 1)
  local finish_pos = doc.position_from_row_col(lines, finish[2] - 1, finish[3])
  insert_pair(start_pos, finish_pos, open, close)
  return true
end

return M
