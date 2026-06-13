-- SPDX-License-Identifier: GPL-3.0-or-later

local M = {}

local function termcodes(text)
  return vim.api.nvim_replace_termcodes(text, true, false, true)
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(
      string.format(
        "%s: expected %q, got %q",
        label or "assert_equal",
        tostring(expected),
        tostring(actual)
      )
    )
  end
end

local function assert_truthy(actual, label)
  if not actual then
    error(label or "assert_truthy failed")
  end
end

local function assert_falsy(actual, label)
  if actual then
    error(label or "assert_falsy failed")
  end
end

local function new_buffer(lines, cursor)
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, cursor)
end

local function current_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function current_text()
  return table.concat(current_lines(), "\n")
end

local function feed(keys)
  vim.api.nvim_feedkeys(termcodes(keys), "xt", false)
end

local function set_point(position)
  require("softpair.doc").set_point(position)
end

local function point()
  return require("softpair.doc").point()
end

local puni_public_names = {
  "puni-after-sexp-p",
  "puni-backward-delete-char",
  "puni-backward-kill-line",
  "puni-backward-kill-word",
  "puni-backward-sexp",
  "puni-backward-sexp-or-up-list",
  "puni-barf-backward",
  "puni-barf-forward",
  "puni-before-sexp-p",
  "puni-beginning-of-list-around-point",
  "puni-beginning-of-sexp",
  "puni-beginning-pos-of-list-around-point",
  "puni-beginning-pos-of-sexp-around-point",
  "puni-bounds-of-list-around-point",
  "puni-bounds-of-sexp-around-point",
  "puni-bounds-of-sexp-at-point",
  "puni-change-inner",
  "puni-change-outer",
  "puni-contract-region",
  "puni-convolute",
  "puni-copy-inner",
  "puni-copy-outer",
  "puni-dangling-delimiter-p",
  "puni-delete-active-region",
  "puni-delete-region",
  "puni-delete-region-keep-balanced",
  "puni-disable-puni-mode",
  "puni-end-of-list-around-point",
  "puni-end-of-sexp",
  "puni-end-pos-of-list-around-point",
  "puni-end-pos-of-sexp-around-point",
  "puni-expand-region",
  "puni-force-delete",
  "puni-forward-delete-char",
  "puni-forward-kill-word",
  "puni-forward-sexp",
  "puni-forward-sexp-or-up-list",
  "puni-kill-active-region",
  "puni-kill-line",
  "puni-kill-region",
  "puni-mark-list-around-point",
  "puni-mark-sexp-around-point",
  "puni-mark-sexp-at-point",
  "puni-raise",
  "puni-region-balance-p",
  "puni-slurp-backward",
  "puni-slurp-forward",
  "puni-soft-delete",
  "puni-soft-delete-by-move",
  "puni-splice",
  "puni-splice-killing-backward",
  "puni-splice-killing-forward",
  "puni-split",
  "puni-squeeze",
  "puni-strict-backward-sexp",
  "puni-strict-backward-sexp-in-comment",
  "puni-strict-backward-sexp-in-string",
  "puni-strict-backward-sexp-or-single-line-comment-quotes",
  "puni-strict-forward-sexp",
  "puni-strict-forward-sexp-in-comment",
  "puni-strict-forward-sexp-in-string",
  "puni-syntactic-backward-punct",
  "puni-syntactic-forward-punct",
  "puni-transpose",
  "puni-up-list",
  "puni-wrap-angle",
  "puni-wrap-curly",
  "puni-wrap-next-sexps",
  "puni-wrap-round",
  "puni-wrap-square",
}

function M.run()
  local softpair = require("softpair")
  local sexp = require("softpair.sexp")
  local syntax = require("softpair.syntax")
  softpair.setup({ notify = false })

  assert_truthy(syntax.is_balanced_fragment("(foo [bar] {baz})"), "balanced fragment")
  assert_falsy(syntax.is_balanced_fragment("(foo"), "unbalanced open")
  assert_falsy(syntax.is_balanced_fragment("foo)"), "unbalanced close")
  assert_truthy(syntax.is_balanced_fragment([["("]]), "delimiter inside string")
  assert_truthy(syntax.is_escaped([[\"]], 2), "single slash escapes")
  assert_falsy(syntax.is_escaped([[\\"]], 3), "double slash does not escape")
  assert_truthy(syntax.is_balanced_fragment([[\(]]), "escaped open is literal")
  assert_truthy(syntax.is_balanced_fragment([[\)]]), "escaped close is literal")
  assert_falsy(syntax.is_balanced_fragment([[\\)]]), "even slashes expose close")
  assert_truthy(syntax.is_balanced_fragment([[(\))]]), "escaped close inside list")
  assert_truthy(syntax.is_balanced_fragment("<"), "angle is not a pair by default")
  assert_truthy(syntax.is_balanced_span([["(x)"]], 1, 2), "string-internal open is literal")
  assert_falsy(syntax.is_balanced_span([["(x)"]], 4, 5), "string quote is protected")

  local angle_bounds = sexp.next_bounds("<x>", 0)
  assert_equal(angle_bounds.type, "symbol", "angle text is a symbol")
  assert_equal(angle_bounds.finish, 3, "angle text is not a list")

  local escaped_quote_bounds = sexp.next_bounds([[a\"b]], 0)
  assert_equal(escaped_quote_bounds.type, "symbol", "escaped quote stays in symbol")
  assert_equal(escaped_quote_bounds.finish, 4, "escaped quote does not split symbol")

  local adjacent_strings = [["a" "b"]]
  local closing_quote_bounds = sexp.bounds_at_point(adjacent_strings, 2)
  assert_equal(closing_quote_bounds.start, 0, "closing quote belongs to its string")
  assert_equal(closing_quote_bounds.finish, 3, "closing quote string finish")
  local previous_string_bounds = sexp.prev_bounds(adjacent_strings, 4)
  assert_equal(previous_string_bounds.start, 0, "prev bounds before next string")
  assert_equal(previous_string_bounds.finish, 3, "prev bounds does not cross strings")

  local string_inner_bounds = sexp.bounds_at_point([["(x)" y]], 1)
  assert_falsy(
    string_inner_bounds and string_inner_bounds.type == "list",
    "string inner paren is not a list"
  )

  softpair.setup({ notify = false, string_delimiters = { ['"'] = true, ["'"] = true } })
  local single_quote_bounds = sexp.bounds_at_point([['(x)' y]], 1)
  assert_falsy(
    single_quote_bounds and single_quote_bounds.type == "list",
    "configured single quote string hides paren"
  )
  local mixed_quote_bounds = sexp.bounds_at_point([["a'b" y]], 2)
  assert_falsy(
    mixed_quote_bounds and mixed_quote_bounds.type == "string",
    "other quote inside string is not string boundary"
  )

  softpair.setup({ notify = false })
  assert_falsy(syntax.is_balanced_fragment("([)]"), "crossed delimiters are unbalanced")
  assert_falsy(sexp.match_forward("([)]", 0), "match forward rejects crossed delimiters")
  assert_falsy(sexp.match_backward("([)]", 3), "match backward rejects crossed delimiters")
  assert_falsy(sexp.next_bounds("([)]", 0), "next bounds rejects crossed delimiters")
  assert_falsy(sexp.prev_bounds("([)]", 4), "prev bounds rejects crossed delimiters")

  assert_equal(softpair.insert_open("("), "()<Left>", "insert open")
  assert_equal(softpair.insert_quote('"'), [[""<Left>]], "insert quote")

  new_buffer({ "()" }, { 1, 1 })
  assert_equal(softpair.backspace(), "<BS><Del>", "paired backspace")
  assert_equal(softpair.insert_close(")"), "<Right>", "skip close")

  new_buffer({ "()" }, { 1, 0 })
  assert_equal(softpair.delete_forward(), "<Del><Del>", "paired forward delete")

  new_buffer({ [[""]] }, { 1, 1 })
  assert_equal(softpair.insert_quote('"'), "<Right>", "skip quote")

  new_buffer({ [["a""b"]] }, { 1, 3 })
  assert_equal(softpair.backspace(), "", "backspace refuses closing-opening quote pair")

  new_buffer({ [["a""b"]] }, { 1, 3 })
  assert_equal(softpair.delete_forward(), "", "delete refuses closing-opening quote pair")

  new_buffer({ [[\a]] }, { 1, 1 })
  assert_equal(softpair.insert_quote('"'), '"', "escaped quote inserts plain quote")

  new_buffer({ [[\\a]] }, { 1, 2 })
  assert_equal(softpair.insert_quote('"'), [[""<Left>]], "even slashes pair quote")

  new_buffer({ "abc" }, { 1, 1 })
  assert_equal(softpair.backspace(), "<BS>", "plain backspace")
  assert_equal(softpair.delete_forward(), "<Del>", "plain forward delete")

  new_buffer({ "(text)" }, { 1, 1 })
  assert_equal(softpair.backspace(), "", "backspace refuses content pair open")

  new_buffer({ "(text)" }, { 1, 0 })
  assert_equal(softpair.delete_forward(), "", "delete refuses content pair open")

  new_buffer({ "(text)" }, { 1, 5 })
  assert_equal(softpair.delete_forward(), "", "delete refuses content pair close")

  new_buffer({ [["text"]] }, { 1, 1 })
  assert_equal(softpair.backspace(), "", "backspace refuses string open quote")

  new_buffer({ [["text"]] }, { 1, 5 })
  assert_equal(softpair.delete_forward(), "", "delete refuses string close quote")

  new_buffer({ [["text"]] }, { 1, 3 })
  assert_equal(softpair.backspace(), "<BS>", "backspace allows string content")

  new_buffer({ [[\(x\)]] }, { 1, 2 })
  assert_equal(softpair.backspace(), "<BS>", "backspace allows escaped open")

  new_buffer({ [["(x)"]] }, { 1, 2 })
  assert_equal(softpair.backspace(), "<BS>", "backspace allows string inner open")

  new_buffer({ [["(x)"]] }, { 1, 1 })
  assert_equal(softpair.delete_forward(), "<Del>", "delete allows string inner open")

  new_buffer({ [["abc]], [[(x)"]] }, { 2, 1 })
  assert_equal(softpair.backspace(), "<BS>", "backspace allows multiline string inner open")

  new_buffer({ [["abc]], [[(x)"]] }, { 2, 0 })
  assert_equal(softpair.delete_forward(), "<Del>", "delete allows multiline string inner open")

  new_buffer({ [[\(x]] }, { 1, 1 })
  assert_equal(softpair.backspace(), "", "backspace refuses exposing escaped open")

  new_buffer({ [[\)x]] }, { 1, 0 })
  assert_equal(softpair.delete_forward(), "", "delete refuses exposing escaped close")

  new_buffer({ [[\"x]] }, { 1, 0 })
  assert_equal(softpair.delete_forward(), "", "delete refuses exposing escaped quote")

  new_buffer({ [[\\\(x]] }, { 1, 0 })
  assert_equal(softpair.delete_forward(), "", "delete refuses exposing deeply escaped open")

  new_buffer({ "foo bar" }, { 1, 4 })
  assert_truthy(softpair.kill_line(), "kill line succeeds")
  assert_equal(current_lines()[1], "foo ", "kill line result")
  assert_equal(vim.fn.getreg('"'), "bar", "kill line register")
  assert_equal(vim.fn.getregtype('"'), "v", "kill line register type")

  new_buffer({ "(foo bar)" }, { 1, 5 })
  assert_falsy(softpair.kill_line(), "kill line refuses unbalanced close")
  assert_equal(current_lines()[1], "(foo bar)", "refused kill keeps buffer")

  new_buffer({ "foo", "bar" }, { 1, 3 })
  assert_truthy(softpair.kill_line(), "kill line joins at eol")
  assert_equal(current_lines()[1], "foobar", "normal-mode eol joins next line")
  assert_equal(vim.fn.getreg('"'), "\n", "normal-mode eol kill register")
  assert_equal(vim.fn.getregtype('"'), "v", "normal-mode eol kill register type")

  new_buffer({ "a", "b" }, { 1, 0 })
  assert_truthy(softpair.kill_line(), "single-char normal-mode line is eol")
  assert_equal(current_lines()[1], "ab", "single-char normal-mode line joins next line")

  new_buffer({ "foo bar" }, { 1, 0 })
  assert_truthy(softpair.kill_line(), "normal-mode line start kills line tail")
  assert_equal(current_lines()[1], "", "normal-mode line start kill result")
  assert_equal(vim.fn.getreg('"'), "foo bar", "normal-mode line start kill register")

  new_buffer({ "foo bar" }, { 1, 4 })
  assert_truthy(softpair.kill_line(), "normal-mode line middle kills from cursor")
  assert_equal(current_lines()[1], "foo ", "normal-mode line middle kill result")
  assert_equal(vim.fn.getreg('"'), "bar", "normal-mode line middle kill register")

  new_buffer({ "", "bar" }, { 1, 0 })
  assert_truthy(softpair.kill_line(), "kill line joins empty line")
  assert_equal(current_lines()[1], "bar", "empty line joined")
  assert_equal(vim.fn.getregtype('"'), "v", "empty line join register type")

  softpair.setup({ mappings = true, notify = false })
  local backspace_map = vim.fn.maparg("<BS>", "i", false, true)
  local delete_map = vim.fn.maparg("<Del>", "i", false, true)
  assert_equal(backspace_map.desc, "Soft pair backspace", "backspace mapping")
  assert_equal(delete_map.desc, "Soft pair delete", "delete mapping")

  new_buffer({ "" }, { 1, 0 })
  feed("i(x<Esc>")
  assert_equal(current_lines()[1], "(x)", "insert mapping creates pair")

  new_buffer({ "" }, { 1, 0 })
  feed("i(<BS><Esc>")
  assert_equal(current_lines()[1], "", "backspace mapping deletes pair")

  new_buffer({ "()" }, { 1, 0 })
  feed("i<Home><Del><Esc>")
  assert_equal(current_lines()[1], "", "delete mapping deletes pair")

  new_buffer({ "" }, { 1, 0 })
  feed("i()<Esc>")
  assert_equal(current_lines()[1], "()", "close mapping skips pair")

  new_buffer({ [[\]] }, { 1, 1 })
  feed('A"<Esc>')
  assert_equal(current_lines()[1], [[\"]], "escaped quote mapping inserts plain quote")

  vim.keymap.set("i", "<C-k>", function()
    softpair.kill_line()
  end, { desc = "Soft kill line" })

  new_buffer({ "foo", "bar" }, { 1, 0 })
  feed("A<C-k><Esc>")
  assert_equal(current_lines()[1], "foobar", "insert-mode kill line joins next line")

  softpair.setup({ notify = false })

  new_buffer({ "(a b) c" }, { 1, 0 })
  set_point(0)
  assert_equal(softpair.forward_sexp(), 5, "forward sexp over list")
  assert_equal(point(), 5, "normal cursor after forward sexp")
  assert_equal(softpair.backward_sexp(), 0, "backward sexp over list")

  new_buffer({ "(a b) c" }, { 1, 1 })
  set_point(1)
  local list_bounds = softpair.bounds_of_list_around_point()
  assert_equal(list_bounds.start, 1, "list inner start")
  assert_equal(list_bounds.finish, 4, "list inner finish")
  local around_bounds = softpair.bounds_of_sexp_around_point()
  assert_equal(around_bounds.start, 0, "sexp around start")
  assert_equal(around_bounds.finish, 5, "sexp around finish")

  new_buffer({ "(a b) c" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.slurp_forward(), "slurp forward")
  assert_equal(current_text(), "(a b c)", "slurp forward result")

  new_buffer({ "a (b c)" }, { 1, 3 })
  set_point(3)
  assert_truthy(softpair.slurp_backward(), "slurp backward")
  assert_equal(current_text(), "(a b c)", "slurp backward result")

  new_buffer({ "(a b c)" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.barf_forward(), "barf forward")
  assert_equal(current_text(), "(a b) c", "barf forward result")

  new_buffer({ "(a b c)" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.barf_backward(), "barf backward")
  assert_equal(current_text(), "a (b c)", "barf backward result")

  new_buffer({ "(a b)" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.splice(), "splice")
  assert_equal(current_text(), "a b", "splice result")

  new_buffer({ "(a b)" }, { 1, 2 })
  set_point(2)
  assert_truthy(softpair.split(), "split")
  assert_equal(current_text(), "(a)( b)", "split result")

  new_buffer({ "(a (b c))" }, { 1, 4 })
  set_point(4)
  assert_truthy(softpair.raise(), "raise")
  assert_equal(current_text(), "(a b)", "raise result")

  new_buffer({ "a b" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.transpose(), "transpose")
  assert_equal(current_text(), "b a", "transpose result")

  new_buffer({ "a b" }, { 1, 0 })
  set_point(0)
  assert_truthy(softpair.wrap_round(2), "wrap round")
  assert_equal(current_text(), "(a b)", "wrap round result")

  new_buffer({ "(a b)" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.copy_inner("("), "copy inner")
  assert_equal(vim.fn.getreg('"'), "a b", "copy inner register")
  assert_truthy(softpair.change_outer("("), "change outer")
  assert_equal(current_text(), "", "change outer result")

  new_buffer({ "(a b)" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.change_inner("("), "change inner")
  assert_equal(current_text(), "()", "change inner result")
  assert_equal(vim.fn.getreg('"'), "a b", "change inner register")

  new_buffer({ [["(x)" y]] }, { 1, 2 })
  set_point(2)
  assert_falsy(softpair.change_inner("("), "change inner ignores string internal paren")
  assert_falsy(softpair.change_outer("("), "change outer ignores string internal paren")
  assert_falsy(softpair.copy_inner("("), "copy inner ignores string internal paren")
  assert_falsy(softpair.copy_outer("("), "copy outer ignores string internal paren")
  assert_equal(current_text(), [["(x)" y]], "string internal paren edit keeps text")

  local struct_ops_inside_string = {
    {
      label = "squeeze",
      run = function()
        return softpair.squeeze()
      end,
    },
    {
      label = "splice",
      run = function()
        return softpair.splice()
      end,
    },
    {
      label = "splice killing backward",
      run = function()
        return softpair.splice_killing_backward()
      end,
    },
    {
      label = "splice killing forward",
      run = function()
        return softpair.splice_killing_forward()
      end,
    },
    {
      label = "slurp forward",
      run = function()
        return softpair.slurp_forward()
      end,
    },
    {
      label = "barf forward",
      run = function()
        return softpair.barf_forward()
      end,
    },
    {
      label = "barf backward",
      run = function()
        return softpair.barf_backward()
      end,
    },
    {
      label = "split",
      run = function()
        return softpair.split()
      end,
    },
    {
      label = "raise",
      run = function()
        return softpair.raise()
      end,
    },
  }

  for _, case in ipairs(struct_ops_inside_string) do
    new_buffer({ [[("(x)" y) z]] }, { 1, 2 })
    set_point(2)
    assert_falsy(case.run(), case.label .. " ignores string internal paren in list")
    assert_equal(current_text(), [[("(x)" y) z]], case.label .. " keeps text")
  end

  new_buffer({ "(a b)" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.squeeze(), "squeeze")
  assert_equal(current_text(), "", "squeeze result")
  assert_equal(vim.fn.getreg('"'), "a b", "squeeze register")

  new_buffer({ "(a b)" }, { 1, 1 })
  assert_falsy(softpair.delete_region_keep_balanced(0, 1), "refuse unbalanced region")
  assert_equal(current_text(), "(a b)", "refused region delete keeps text")
  assert_truthy(softpair.delete_region_keep_balanced(1, 4), "delete balanced region")
  assert_equal(current_text(), "()", "balanced region delete result")

  new_buffer({ "(text)" }, { 1, 0 })
  set_point(0)
  assert_falsy(softpair.forward_delete_char(), "forward char refuses content pair open")
  assert_equal(current_text(), "(text)", "forward char keeps content pair")

  new_buffer({ "(text)" }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.backward_delete_char(), "backward char refuses content pair open")
  assert_equal(current_text(), "(text)", "backward char keeps content pair")

  new_buffer({ "(text) x" }, { 1, 5 })
  set_point(5)
  assert_falsy(softpair.forward_delete_char(), "forward char refuses content pair close")
  assert_equal(current_text(), "(text) x", "forward char keeps content pair close")

  new_buffer({ "(text)" }, { 1, 0 })
  set_point(0)
  assert_truthy(softpair.force_delete(), "force delete allows pair break")
  assert_equal(current_text(), "text)", "force delete result")

  new_buffer({ "()x" }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.backward_delete_char(), "backward char deletes empty pair")
  assert_equal(current_text(), "x", "backward empty pair result")

  new_buffer({ "()" }, { 1, 0 })
  set_point(0)
  assert_truthy(softpair.forward_delete_char(), "forward char deletes empty pair")
  assert_equal(current_text(), "", "forward empty pair result")

  new_buffer({ [[\)x]] }, { 1, 1 })
  set_point(1)
  assert_truthy(softpair.forward_delete_char(), "forward char allows escaped close")
  assert_equal(current_text(), [[\x]], "escaped close delete result")

  new_buffer({ [[\(x]] }, { 1, 0 })
  set_point(0)
  assert_falsy(softpair.forward_delete_char(), "forward char refuses exposing escaped open")
  assert_equal(current_text(), [[\(x]], "forward char keeps escaped open prefix")

  new_buffer({ [[\\\(x]] }, { 1, 0 })
  set_point(0)
  assert_falsy(softpair.forward_delete_char(), "forward char refuses deeply exposing escaped open")
  assert_equal(current_text(), [[\\\(x]], "forward char keeps deep escaped open prefix")

  new_buffer({ [[\)x]] }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.backward_delete_char(), "backward char refuses exposing escaped close")
  assert_equal(current_text(), [[\)x]], "backward char keeps escaped close prefix")

  new_buffer({ [[\"x]] }, { 1, 0 })
  set_point(0)
  assert_falsy(softpair.forward_delete_char(), "forward char refuses exposing escaped quote")
  assert_equal(current_text(), [[\"x]], "forward char keeps escaped quote prefix")

  new_buffer({ [[\(x]] }, { 1, 0 })
  set_point(0)
  assert_truthy(softpair.force_delete(), "force delete allows exposing escaped open")
  assert_equal(current_text(), "(x", "force delete escaped prefix result")

  new_buffer({ [["a""b"]] }, { 1, 3 })
  set_point(3)
  assert_falsy(softpair.backward_delete_char(), "backward char refuses closing-opening quote pair")
  assert_equal(current_text(), [["a""b"]], "backward char keeps adjacent strings")

  new_buffer({ [["a""b"]] }, { 1, 3 })
  set_point(3)
  assert_falsy(softpair.forward_delete_char(), "forward char refuses closing-opening quote pair")
  assert_equal(current_text(), [["a""b"]], "forward char keeps adjacent strings")

  new_buffer({ "(ab)" }, { 1, 2 })
  set_point(2)
  assert_falsy(softpair.backward_delete_char(2), "count backward delete refuses atomically")
  assert_equal(current_text(), "(ab)", "count backward delete keeps buffer on refusal")

  new_buffer({ "(ab)" }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.forward_delete_char(3), "count forward delete refuses atomically")
  assert_equal(current_text(), "(ab)", "count forward delete keeps buffer on refusal")

  new_buffer({ "(text)" }, { 1, 0 })
  assert_falsy(softpair.delete_region(0, 1), "delete region refuses pair break")
  assert_equal(current_text(), "(text)", "delete region keeps content pair")
  assert_falsy(softpair.kill_region(0, 1), "kill region refuses pair break")
  assert_equal(current_text(), "(text)", "kill region keeps content pair")
  assert_truthy(softpair.delete_region(1, 5), "delete region allows content")
  assert_equal(current_text(), "()", "delete region content result")

  new_buffer({ [["text"]] }, { 1, 0 })
  assert_falsy(softpair.delete_region(0, 1), "delete region refuses string open quote")
  assert_equal(current_text(), [["text"]], "delete region keeps string open quote")
  assert_falsy(softpair.delete_region(5, 6), "delete region refuses string close quote")
  assert_equal(current_text(), [["text"]], "delete region keeps string close quote")
  assert_truthy(softpair.delete_region(1, 5), "delete region allows string content")
  assert_equal(current_text(), [[""]], "delete region string content result")

  new_buffer({ [[\(x]] }, { 1, 0 })
  assert_falsy(softpair.delete_region(0, 1), "delete region refuses exposing escaped open")
  assert_equal(current_text(), [[\(x]], "delete region keeps escaped open prefix")

  new_buffer({ [[\\\(x]] }, { 1, 0 })
  assert_falsy(softpair.delete_region(0, 1), "delete region refuses deeply exposing escaped open")
  assert_equal(current_text(), [[\\\(x]], "delete region keeps deep escaped open prefix")

  new_buffer({ [[\"x]] }, { 1, 0 })
  assert_falsy(softpair.delete_region(0, 1), "delete region refuses exposing escaped quote")
  assert_equal(current_text(), [[\"x]], "delete region keeps escaped quote prefix")

  new_buffer({ "(text)" }, { 1, 0 })
  vim.fn.setpos("'<", { 0, 1, 1, 0 })
  vim.fn.setpos("'>", { 0, 1, 1, 0 })
  assert_falsy(softpair.delete_active_region(), "visual delete refuses pair break")
  assert_equal(current_text(), "(text)", "visual delete keeps content pair")

  new_buffer({ "(text)" }, { 1, 0 })
  vim.fn.setpos("'<", { 0, 1, 1, 0 })
  vim.fn.setpos("'>", { 0, 1, 1, 0 })
  assert_falsy(softpair.kill_active_region(), "visual kill refuses pair break")
  assert_equal(current_text(), "(text)", "visual kill keeps content pair")

  new_buffer({ "(text)" }, { 1, 0 })
  vim.fn.setpos("'<", { 0, 1, 2, 0 })
  vim.fn.setpos("'>", { 0, 1, 5, 0 })
  assert_truthy(softpair.delete_active_region(), "visual delete allows content")
  assert_equal(current_text(), "()", "visual delete content result")

  new_buffer({ "(text)" }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.backward_kill_line(), "backward kill line refuses pair break")
  assert_equal(current_text(), "(text)", "backward kill line keeps content pair")

  new_buffer({ [[\)x]] }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.backward_kill_line(), "backward kill line refuses exposing escaped close")
  assert_equal(current_text(), [[\)x]], "backward kill line keeps escaped close prefix")

  new_buffer({ [[a\)b]] }, { 1, 2 })
  set_point(2)
  assert_truthy(softpair.kill_line(), "kill line allows escaped close")
  assert_equal(current_text(), [[a\]], "kill line escaped close result")

  new_buffer({ "foo bar" }, { 1, 3 })
  set_point(3)
  assert_truthy(softpair.backward_kill_word(), "backward kill word")
  assert_equal(current_text(), " bar", "backward kill word result")

  new_buffer({ [[\(x]] }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.backward_kill_word(), "backward kill word refuses exposing escaped open")
  assert_equal(current_text(), [[\(x]], "backward kill word keeps escaped open prefix")

  new_buffer({ [[\"x]] }, { 1, 1 })
  set_point(1)
  assert_falsy(softpair.backward_kill_word(), "backward kill word refuses exposing escaped quote")
  assert_equal(current_text(), [[\"x]], "backward kill word keeps escaped quote prefix")

  new_buffer({ [[\(x]] }, { 1, 0 })
  set_point(0)
  assert_truthy(softpair.forward_kill_word(), "forward kill word removes escaped literal")
  assert_equal(current_text(), "", "forward kill word escaped literal result")

  for _, name in ipairs(puni_public_names) do
    assert_equal(type(softpair[name]), "function", name .. " alias")
  end

  require("softpair.commands").create()
  assert_equal(vim.fn.exists(":PuniForwardSexp"), 2, "PuniForwardSexp command exists")

  new_buffer({ "(a b)" }, { 1, 1 })
  set_point(1)
  vim.cmd("PuniChangeInner (")
  assert_equal(current_text(), "()", "PuniChangeInner command result")

  print("softpair.nvim tests passed")
end

return M
