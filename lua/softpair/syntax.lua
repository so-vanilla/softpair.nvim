-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source reference: GNU Emacs syntax and sexp APIs.

local config = require("softpair.config")

local M = {}

local function closing_pairs(options)
  local closing = {}
  for open, close in pairs(options.pairs) do
    closing[close] = open
  end
  return closing
end

function M.closing_pairs(opts)
  return closing_pairs(opts or config.options)
end

function M.is_escaped(text, index)
  local slash_count = 0
  local cursor = index - 1

  while cursor >= 1 and text:sub(cursor, cursor) == "\\" do
    slash_count = slash_count + 1
    cursor = cursor - 1
  end

  return slash_count % 2 == 1
end

function M.is_candidate(text, index, opts)
  local options = opts or config.options
  return not (options.ignore_escaped_delimiters and M.is_escaped(text, index))
end

function M.is_string_delimiter(text, index, opts)
  local options = opts or config.options
  local char = text:sub(index, index)
  return options.string_delimiters[char] and M.is_candidate(text, index, options)
end

function M.string_delimiter_context(text, index, opts)
  local options = opts or config.options
  local char = text:sub(index, index)
  if not options.string_delimiters[char] or not M.is_candidate(text, index, options) then
    return nil
  end

  local delimiter = M.string_delimiter_before(text, index, options)
  if not delimiter then
    return "open"
  end

  if delimiter == char then
    return "close"
  end
end

function M.is_string_open(text, index, opts)
  return M.string_delimiter_context(text, index, opts) == "open"
end

function M.is_string_close(text, index, opts)
  return M.string_delimiter_context(text, index, opts) == "close"
end

function M.string_delimiter_before(text, index, opts)
  local options = opts or config.options
  local delimiter = nil

  for cursor = 1, math.max(index - 1, 0) do
    local char = text:sub(cursor, cursor)
    if delimiter then
      if char == delimiter and M.is_candidate(text, cursor, options) then
        delimiter = nil
      end
    elseif options.string_delimiters[char] and M.is_candidate(text, cursor, options) then
      delimiter = char
    end
  end

  return delimiter
end

function M.is_in_string(text, index, opts)
  return M.string_delimiter_before(text, index, opts) ~= nil
end

function M.is_structural_candidate(text, index, opts)
  return M.is_candidate(text, index, opts) and not M.is_in_string(text, index, opts)
end

function M.is_pair_delimiter(text, index, opts)
  local options = opts or config.options
  local char = text:sub(index, index)
  return M.is_structural_candidate(text, index, options)
    and (options.pairs[char] ~= nil or closing_pairs(options)[char] ~= nil)
end

function M.is_protected_candidate(text, index, opts)
  return M.is_pair_delimiter(text, index, opts)
    or M.is_string_open(text, index, opts)
    or M.is_string_close(text, index, opts)
end

function M.deletion_exposes_candidate(text, start_pos, end_pos, opts)
  local options = opts or config.options
  local start_actual = math.min(start_pos, end_pos)
  local end_actual = math.max(start_pos, end_pos)

  if start_actual < 0 or start_actual == end_actual or end_actual > #text then
    return false
  end

  local edited = text:sub(1, start_actual) .. text:sub(end_actual + 1)
  local deleted_length = end_actual - start_actual

  for original_index = end_actual + 1, #text do
    local edited_index = original_index - deleted_length
    if
      M.is_protected_candidate(edited, edited_index, options)
      and not M.is_protected_candidate(text, original_index, options)
    then
      return true
    end
  end

  return false
end

function M.is_balanced_span(text, start_pos, end_pos, opts)
  local options = opts or config.options
  local closing = closing_pairs(options)
  local stack = {}
  local string_delimiter = nil
  local string_started_before_span = false
  local start_index = math.min(start_pos, end_pos) + 1
  local end_index = math.max(start_pos, end_pos)

  string_delimiter = M.string_delimiter_before(text, start_index, options)
  string_started_before_span = string_delimiter ~= nil

  for index = start_index, end_index do
    local char = text:sub(index, index)

    if string_delimiter then
      if char == string_delimiter and M.is_candidate(text, index, options) then
        if string_started_before_span then
          return false
        end
        string_delimiter = nil
      end
    elseif options.string_delimiters[char] and M.is_candidate(text, index, options) then
      string_delimiter = char
      string_started_before_span = false
    elseif options.pairs[char] and M.is_structural_candidate(text, index, options) then
      stack[#stack + 1] = char
    elseif closing[char] and M.is_structural_candidate(text, index, options) then
      if stack[#stack] ~= closing[char] then
        return false
      end

      stack[#stack] = nil
    end
  end

  return #stack == 0 and (string_delimiter == nil or string_started_before_span)
end

function M.is_balanced_fragment(text, opts)
  return M.is_balanced_span(text, 0, #text, opts)
end

return M
