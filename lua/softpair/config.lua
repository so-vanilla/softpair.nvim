-- SPDX-License-Identifier: GPL-3.0-or-later

local M = {}

M.defaults = {
  mappings = false,
  notify = true,
  pairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
  },
  quote_pairs = {
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
  },
  string_delimiters = {
    ['"'] = true,
  },
  ignore_escaped_delimiters = true,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

function M.close_for(open)
  return M.options.pairs[open] or M.options.quote_pairs[open]
end

function M.open_for(close)
  for open, pair_close in pairs(M.options.pairs) do
    if pair_close == close then
      return open
    end
  end

  for open, pair_close in pairs(M.options.quote_pairs) do
    if pair_close == close then
      return open
    end
  end
end

function M.is_pair(open, close)
  return M.close_for(open) == close
end

return M
