-- SPDX-License-Identifier: GPL-3.0-or-later

local M = {}

local count_commands = {
  PuniStrictForwardSexpInString = "strict_forward_sexp_in_string",
  PuniStrictBackwardSexpInString = "strict_backward_sexp_in_string",
  PuniStrictForwardSexpInComment = "strict_forward_sexp_in_comment",
  PuniStrictBackwardSexpInComment = "strict_backward_sexp_in_comment",
  PuniStrictForwardSexp = "strict_forward_sexp",
  PuniStrictBackwardSexp = "strict_backward_sexp",
  PuniBackwardDeleteChar = "backward_delete_char",
  PuniForwardDeleteChar = "forward_delete_char",
  PuniForwardKillWord = "forward_kill_word",
  PuniBackwardKillWord = "backward_kill_word",
  PuniForceDelete = "force_delete",
  PuniForwardSexp = "forward_sexp",
  PuniBackwardSexp = "backward_sexp",
  PuniForwardSexpOrUpList = "forward_sexp_or_up_list",
  PuniBackwardSexpOrUpList = "backward_sexp_or_up_list",
  PuniContractRegion = "contract_region",
  PuniSlurpForward = "slurp_forward",
  PuniBarfForward = "barf_forward",
  PuniSlurpBackward = "slurp_backward",
  PuniBarfBackward = "barf_backward",
  PuniWrapRound = "wrap_round",
  PuniWrapSquare = "wrap_square",
  PuniWrapCurly = "wrap_curly",
  PuniWrapAngle = "wrap_angle",
}

local plain_commands = {
  PuniBeginningOfListAroundPoint = "beginning_of_list_around_point",
  PuniEndOfListAroundPoint = "end_of_list_around_point",
  PuniDeleteActiveRegion = "delete_active_region",
  PuniKillRegion = "kill_region",
  PuniKillActiveRegion = "kill_active_region",
  PuniKillLine = "kill_line",
  PuniBackwardKillLine = "backward_kill_line",
  PuniBeginningOfSexp = "beginning_of_sexp",
  PuniEndOfSexp = "end_of_sexp",
  PuniSyntacticForwardPunct = "syntactic_forward_punct",
  PuniSyntacticBackwardPunct = "syntactic_backward_punct",
  PuniMarkSexpAtPoint = "mark_sexp_at_point",
  PuniMarkListAroundPoint = "mark_list_around_point",
  PuniMarkSexpAroundPoint = "mark_sexp_around_point",
  PuniExpandRegion = "expand_region",
  PuniSqueeze = "squeeze",
  PuniSplice = "splice",
  PuniSpliceKillingBackward = "splice_killing_backward",
  PuniSpliceKillingForward = "splice_killing_forward",
  PuniSplit = "split",
  PuniRaise = "raise",
  PuniTranspose = "transpose",
  PuniConvolute = "convolute",
  PuniDisablePuniMode = "disable_puni_mode",
}

local delimiter_commands = {
  PuniChangeInner = "change_inner",
  PuniCopyInner = "copy_inner",
  PuniChangeOuter = "change_outer",
  PuniCopyOuter = "copy_outer",
}

function M.create()
  local softpair = require("softpair")

  for command, method in pairs(count_commands) do
    vim.api.nvim_create_user_command(command, function(opts)
      local count = opts.count > 0 and opts.count or nil
      softpair[method](count)
    end, { count = true })
  end

  for command, method in pairs(plain_commands) do
    vim.api.nvim_create_user_command(command, function()
      softpair[method]()
    end, {})
  end

  vim.api.nvim_create_user_command("PuniUpList", function(opts)
    softpair.up_list(opts.bang)
  end, { bang = true })

  for command, method in pairs(delimiter_commands) do
    vim.api.nvim_create_user_command(command, function(opts)
      softpair[method](opts.args ~= "" and opts.args or "(")
    end, { nargs = "?" })
  end
end

return M
