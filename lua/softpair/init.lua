-- SPDX-License-Identifier: GPL-3.0-or-later

local config = require("softpair.config")
local pair = require("softpair.pair")
local region = require("softpair.region")
local sexp = require("softpair.sexp")
local soft_delete = require("softpair.soft_delete")
local struct = require("softpair.struct")

local M = {}

local function map(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { silent = true }, opts or {}))
end

function M.setup(opts)
  config.setup(opts)

  if config.options.mappings then
    M.apply_mappings()
  end
end

function M.apply_mappings()
  for open, close in pairs(config.options.pairs) do
    map("i", open, function()
      return pair.expr_open(open)
    end, { expr = true, desc = "Insert soft pair" })

    map("i", close, function()
      return pair.expr_close(close)
    end, { expr = true, desc = "Skip soft pair close" })
  end

  for open, close in pairs(config.options.quote_pairs) do
    map("i", open, function()
      return pair.expr_quote(open)
    end, { expr = true, desc = "Insert soft quote pair" })

    if open ~= close then
      map("i", close, function()
        return pair.expr_close(close)
      end, { expr = true, desc = "Skip soft quote close" })
    end
  end

  map("i", "<BS>", function()
    return pair.expr_backspace()
  end, { expr = true, desc = "Soft pair backspace" })

  map("i", "<Del>", function()
    return pair.expr_delete()
  end, { expr = true, desc = "Soft pair delete" })
end

function M.insert_open(open)
  return pair.expr_open(open)
end

function M.insert_quote(quote)
  return pair.expr_quote(quote)
end

function M.insert_close(close)
  return pair.expr_close(close)
end

function M.backspace()
  return pair.expr_backspace()
end

function M.delete_forward()
  return pair.expr_delete()
end

function M.wrap_visual(open)
  return struct.wrap_visual(open)
end

function M.kill_line()
  return soft_delete.kill_line()
end

function M.strict_forward_sexp(count)
  return sexp.forward(count)
end

function M.strict_backward_sexp(count)
  return sexp.backward(count)
end

function M.strict_forward_sexp_in_string(count)
  return sexp.forward(count)
end

function M.strict_backward_sexp_in_string(count)
  return sexp.backward(count)
end

function M.strict_forward_sexp_in_comment(count)
  return sexp.forward(count)
end

function M.strict_backward_sexp_in_comment(count)
  return sexp.backward(count)
end

function M.strict_backward_sexp_or_single_line_comment_quotes(count)
  return sexp.backward(count)
end

function M.beginning_of_list_around_point()
  return sexp.beginning_of_list()
end

function M.end_of_list_around_point()
  return sexp.end_of_list()
end

function M.up_list(backward)
  return sexp.up(backward)
end

function M.before_sexp_p()
  return sexp.forward_pos(require("softpair.doc").text(), require("softpair.doc").point(), 1)
end

function M.after_sexp_p()
  return sexp.backward_pos(require("softpair.doc").text(), require("softpair.doc").point(), 1)
end

function M.bounds_of_sexp_at_point()
  return sexp.bounds_at_point(require("softpair.doc").text(), require("softpair.doc").point())
end

function M.beginning_pos_of_list_around_point()
  return sexp.list_bounds_around_point(
    require("softpair.doc").text(),
    require("softpair.doc").point()
  ).start
end

function M.end_pos_of_list_around_point()
  return sexp.list_bounds_around_point(
    require("softpair.doc").text(),
    require("softpair.doc").point()
  ).finish
end

function M.bounds_of_list_around_point()
  return sexp.list_bounds_around_point(
    require("softpair.doc").text(),
    require("softpair.doc").point()
  )
end

function M.bounds_of_sexp_around_point()
  return sexp.bounds_around_point(require("softpair.doc").text(), require("softpair.doc").point())
end

function M.beginning_pos_of_sexp_around_point()
  local bounds = M.bounds_of_sexp_around_point()
  return bounds and bounds.start
end

function M.end_pos_of_sexp_around_point()
  local bounds = M.bounds_of_sexp_around_point()
  return bounds and bounds.finish
end

function M.region_balance_p(start_pos, end_pos, strict)
  return sexp.region_balance(start_pos, end_pos, strict)
end

function M.dangling_delimiter_p(point)
  return sexp.dangling_delimiter(point)
end

function M.delete_region(start_pos, end_pos)
  return soft_delete.delete_region(start_pos, end_pos)
end

function M.delete_region_keep_balanced(start_pos, end_pos, strict, kill)
  return soft_delete.delete_region_keep_balanced(start_pos, end_pos, strict, kill)
end

function M.soft_delete(from, to, strict, style, kill, fail_action, return_region)
  return soft_delete.soft_delete(from, to, strict, style, kill, fail_action, return_region)
end

function M.soft_delete_by_move(move, strict, style, kill, fail_action)
  return soft_delete.soft_delete_by_move(move, strict, style, kill, fail_action)
end

function M.delete_active_region(visual_mode)
  return soft_delete.delete_active_region(visual_mode)
end

function M.kill_region(start_pos, end_pos)
  if start_pos and end_pos then
    return soft_delete.kill_region(start_pos, end_pos)
  end
  return soft_delete.kill_active_region()
end

function M.kill_active_region(visual_mode)
  return soft_delete.kill_active_region(visual_mode)
end

function M.backward_delete_char(count)
  return soft_delete.backward_delete_char(count)
end

function M.forward_delete_char(count)
  return soft_delete.forward_delete_char(count)
end

function M.forward_kill_word(count)
  return soft_delete.forward_kill_word(count)
end

function M.backward_kill_word(count)
  return soft_delete.backward_kill_word(count)
end

function M.backward_kill_line()
  return soft_delete.backward_kill_line()
end

function M.force_delete(count)
  return soft_delete.force_delete(count)
end

function M.forward_sexp(count)
  return sexp.forward(count)
end

function M.backward_sexp(count)
  return sexp.backward(count)
end

function M.forward_sexp_or_up_list(count)
  return sexp.forward(count) or sexp.up(false)
end

function M.backward_sexp_or_up_list(count)
  return sexp.backward(count) or sexp.up(true)
end

function M.beginning_of_sexp()
  return sexp.beginning_of_sexp()
end

function M.end_of_sexp()
  return sexp.end_of_sexp()
end

function M.syntactic_forward_punct()
  return sexp.syntactic_forward_punct()
end

function M.syntactic_backward_punct()
  return sexp.syntactic_backward_punct()
end

function M.mark_sexp_at_point()
  return region.mark_sexp_at_point()
end

function M.mark_list_around_point()
  return region.mark_list_around_point()
end

function M.mark_sexp_around_point()
  return region.mark_sexp_around_point()
end

function M.expand_region()
  return region.expand()
end

function M.contract_region()
  return region.contract()
end

function M.squeeze()
  return struct.squeeze()
end

function M.slurp_forward(count)
  return struct.slurp_forward(count)
end

function M.barf_forward(count)
  return struct.barf_forward(count)
end

function M.slurp_backward(count)
  return struct.slurp_backward(count)
end

function M.barf_backward(count)
  return struct.barf_backward(count)
end

function M.splice()
  return struct.splice()
end

function M.splice_killing_backward()
  return struct.splice_killing_backward()
end

function M.splice_killing_forward()
  return struct.splice_killing_forward()
end

function M.split()
  return struct.split()
end

function M.raise()
  return struct.raise()
end

function M.transpose()
  return struct.transpose()
end

function M.convolute()
  return struct.convolute()
end

function M.change_inner(open)
  return struct.change_inner(open or "(")
end

function M.copy_inner(open)
  return struct.copy_inner(open or "(")
end

function M.change_outer(open)
  return struct.change_outer(open or "(")
end

function M.copy_outer(open)
  return struct.copy_outer(open or "(")
end

function M.wrap_next_sexps(count, open, close)
  return struct.wrap_next_sexps(count, open, close)
end

function M.wrap_round(count)
  return struct.wrap_round(count)
end

function M.wrap_square(count)
  return struct.wrap_square(count)
end

function M.wrap_curly(count)
  return struct.wrap_curly(count)
end

function M.wrap_angle(count)
  return struct.wrap_angle(count)
end

function M.disable_puni_mode()
  return true
end

local aliases = {
  ["puni-strict-forward-sexp-in-string"] = M.strict_forward_sexp_in_string,
  ["puni-strict-backward-sexp-in-string"] = M.strict_backward_sexp_in_string,
  ["puni-strict-forward-sexp-in-comment"] = M.strict_forward_sexp_in_comment,
  ["puni-strict-backward-sexp-in-comment"] = M.strict_backward_sexp_in_comment,
  ["puni-strict-forward-sexp"] = M.strict_forward_sexp,
  ["puni-strict-backward-sexp"] = M.strict_backward_sexp,
  ["puni-strict-backward-sexp-or-single-line-comment-quotes"] = M.strict_backward_sexp_or_single_line_comment_quotes,
  ["puni-beginning-of-list-around-point"] = M.beginning_of_list_around_point,
  ["puni-end-of-list-around-point"] = M.end_of_list_around_point,
  ["puni-up-list"] = M.up_list,
  ["puni-before-sexp-p"] = M.before_sexp_p,
  ["puni-after-sexp-p"] = M.after_sexp_p,
  ["puni-bounds-of-sexp-at-point"] = M.bounds_of_sexp_at_point,
  ["puni-beginning-pos-of-list-around-point"] = M.beginning_pos_of_list_around_point,
  ["puni-end-pos-of-list-around-point"] = M.end_pos_of_list_around_point,
  ["puni-bounds-of-list-around-point"] = M.bounds_of_list_around_point,
  ["puni-bounds-of-sexp-around-point"] = M.bounds_of_sexp_around_point,
  ["puni-beginning-pos-of-sexp-around-point"] = M.beginning_pos_of_sexp_around_point,
  ["puni-end-pos-of-sexp-around-point"] = M.end_pos_of_sexp_around_point,
  ["puni-region-balance-p"] = M.region_balance_p,
  ["puni-dangling-delimiter-p"] = M.dangling_delimiter_p,
  ["puni-delete-region"] = M.delete_region,
  ["puni-delete-region-keep-balanced"] = M.delete_region_keep_balanced,
  ["puni-soft-delete"] = M.soft_delete,
  ["puni-soft-delete-by-move"] = M.soft_delete_by_move,
  ["puni-delete-active-region"] = M.delete_active_region,
  ["puni-kill-region"] = M.kill_region,
  ["puni-kill-active-region"] = M.kill_active_region,
  ["puni-backward-delete-char"] = M.backward_delete_char,
  ["puni-forward-delete-char"] = M.forward_delete_char,
  ["puni-forward-kill-word"] = M.forward_kill_word,
  ["puni-backward-kill-word"] = M.backward_kill_word,
  ["puni-kill-line"] = M.kill_line,
  ["puni-backward-kill-line"] = M.backward_kill_line,
  ["puni-force-delete"] = M.force_delete,
  ["puni-forward-sexp"] = M.forward_sexp,
  ["puni-backward-sexp"] = M.backward_sexp,
  ["puni-forward-sexp-or-up-list"] = M.forward_sexp_or_up_list,
  ["puni-backward-sexp-or-up-list"] = M.backward_sexp_or_up_list,
  ["puni-beginning-of-sexp"] = M.beginning_of_sexp,
  ["puni-end-of-sexp"] = M.end_of_sexp,
  ["puni-syntactic-forward-punct"] = M.syntactic_forward_punct,
  ["puni-syntactic-backward-punct"] = M.syntactic_backward_punct,
  ["puni-mark-sexp-at-point"] = M.mark_sexp_at_point,
  ["puni-mark-list-around-point"] = M.mark_list_around_point,
  ["puni-mark-sexp-around-point"] = M.mark_sexp_around_point,
  ["puni-expand-region"] = M.expand_region,
  ["puni-contract-region"] = M.contract_region,
  ["puni-squeeze"] = M.squeeze,
  ["puni-slurp-forward"] = M.slurp_forward,
  ["puni-barf-forward"] = M.barf_forward,
  ["puni-slurp-backward"] = M.slurp_backward,
  ["puni-barf-backward"] = M.barf_backward,
  ["puni-splice"] = M.splice,
  ["puni-splice-killing-backward"] = M.splice_killing_backward,
  ["puni-splice-killing-forward"] = M.splice_killing_forward,
  ["puni-split"] = M.split,
  ["puni-raise"] = M.raise,
  ["puni-transpose"] = M.transpose,
  ["puni-convolute"] = M.convolute,
  ["puni-change-inner"] = M.change_inner,
  ["puni-copy-inner"] = M.copy_inner,
  ["puni-change-outer"] = M.change_outer,
  ["puni-copy-outer"] = M.copy_outer,
  ["puni-wrap-next-sexps"] = M.wrap_next_sexps,
  ["puni-wrap-round"] = M.wrap_round,
  ["puni-wrap-square"] = M.wrap_square,
  ["puni-wrap-curly"] = M.wrap_curly,
  ["puni-wrap-angle"] = M.wrap_angle,
  ["puni-disable-puni-mode"] = M.disable_puni_mode,
}

for name, fn in pairs(aliases) do
  M[name] = fn
end

return M
