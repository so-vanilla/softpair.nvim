-- SPDX-License-Identifier: GPL-3.0-or-later

local doc = require("softpair.doc")
local sexp = require("softpair.sexp")

local M = {}

local last_region = nil

local function set_visual_range(start_pos, end_pos)
  local start_actual = math.min(start_pos, end_pos)
  local end_actual = math.max(start_pos, end_pos)
  local lines = doc.lines()
  local start_row, start_col = doc.row_col_from_position(lines, start_actual)
  local end_row, end_col = doc.row_col_from_position(lines, end_actual)

  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { end_row + 1, math.max(end_col - 1, 0) })
  last_region = { start = start_actual, finish = end_actual }
end

function M.mark_sexp_at_point()
  local text = doc.text()
  local bounds = sexp.bounds_at_point(text, doc.point())
  if not bounds then
    return false
  end
  set_visual_range(bounds.start, bounds.finish)
  return bounds
end

function M.mark_list_around_point()
  local text = doc.text()
  local bounds = sexp.list_bounds_around_point(text, doc.point())
  set_visual_range(bounds.start, bounds.finish)
  return bounds
end

function M.mark_sexp_around_point()
  local text = doc.text()
  local bounds = sexp.bounds_around_point(text, doc.point())
  if not bounds then
    return false
  end
  set_visual_range(bounds.start, bounds.finish)
  return bounds
end

function M.expand()
  local text = doc.text()
  local point = doc.point()
  local bounds = last_region

  if not bounds then
    bounds = sexp.bounds_at_point(text, point)
  end

  local around = sexp.bounds_around_point(text, bounds and bounds.start or point)
  if around and bounds and (around.start < bounds.start or around.finish > bounds.finish) then
    bounds = around
  else
    bounds = sexp.list_bounds_around_point(text, point)
  end

  if bounds then
    set_visual_range(bounds.start, bounds.finish)
  end

  return bounds
end

function M.contract()
  if not last_region then
    return false
  end

  local text = doc.text()
  local inner = sexp.bounds_at_point(text, last_region.start + 1)
  if inner and inner.start >= last_region.start and inner.finish <= last_region.finish then
    set_visual_range(inner.start, inner.finish)
    return inner
  end

  return false
end

return M
