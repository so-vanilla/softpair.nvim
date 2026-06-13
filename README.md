# softpair.nvim

Soft pair editing for Neovim.

This repository is a porting-oriented GPL project. It starts with the parts
needed for an insert-mode-heavy workflow:

- paired insertion for delimiters and quotes
- paired backspace
- paired forward delete
- line kill that refuses to remove an unbalanced delimiter fragment
- Puni-style sexp movement, bounds, soft deletion, wrapping, textobject, and
  structural editing APIs
- `:Puni...` user commands plus Lua aliases such as
  `require("softpair")["puni-forward-sexp"]()`

The implementation is intentionally conservative. The current behavior protects
plain `()`, `[]`, and `{}` pairs first; language-aware sexp behavior should be
added behind explicit tests.

## Scanner Scope

By default, softpair treats only these characters as structural candidates:

- pair delimiters: `()`, `[]`, and `{}`
- string delimiters: `"` only

Escaped candidates are ignored. For example, `\(` and `\)` are treated as
literal text, while `\\)` is an unescaped close delimiter because the backslash
count is even. Delimiters inside a configured string are also treated as literal
text, so `"("` does not expose `(` as a list opener.

Deleting only the escape prefix is protected when it would turn the following
literal into a structural delimiter or string boundary. For example, deleting
the backslash from `\(` is refused by normal delete paths because the result
would expose an unmatched `(`. `force_delete` keeps the escape hatch: it warns
and performs the deletion.

`<>` is not a structural pair by default because angle brackets are often
literal text or language syntax. `wrap_angle` / `:PuniWrapAngle` only insert
angle characters around a selected sexp; they do not make `<` and `>` scanner
delimiters unless you add them to `pairs` yourself.

The scanner is byte based and intentionally smaller than Emacs syntax tables.
Comments, heredocs, raw strings, Lisp reader syntax, multichar delimiters, and
filetype-local parsing are not recognized yet.

## Status

Early implementation with broad Puni API coverage.

The public API is not stable yet. The current target is practical Puni-like
coverage over Neovim buffers with a conservative delimiter scanner. Exact Emacs
syntax-table, comment, string, indentation, and mode-local parity is still a
work in progress.

## Installation

With a conventional plugin manager:

```lua
{
  "so-vanilla/softpair.nvim",
  config = function()
    require("softpair").setup()
  end,
}
```

With Nix, package this repository as a Vim plugin and call
`require("softpair").setup()` from the Neovim config.

This flake exposes the plugin directly:

```nix
inputs.softpair-nvim.url = "github:so-vanilla/softpair.nvim";
```

Home Manager:

```nix
{ inputs, pkgs, ... }:
{
  programs.neovim.plugins = [
    inputs.softpair-nvim.packages.${pkgs.system}.default
  ];
}
```

nixvim:

```nix
{ inputs, pkgs, ... }:
{
  extraPlugins = [
    inputs.softpair-nvim.packages.${pkgs.system}.default
  ];

  extraConfigLua = ''
    require("softpair").setup()
  '';
}
```

## Usage

Install default insert-mode mappings:

```lua
require("softpair").setup({
  mappings = true,
})
```

Or bind only the pieces you want:

```lua
vim.keymap.set("i", "(", function()
  return require("softpair").insert_open("(")
end, { expr = true, desc = "Insert soft pair" })

vim.keymap.set("i", "<BS>", function()
  return require("softpair").backspace()
end, { expr = true, desc = "Soft pair backspace" })

vim.keymap.set("i", "<Del>", function()
  return require("softpair").delete_forward()
end, { expr = true, desc = "Soft pair delete" })

vim.keymap.set({ "i", "n" }, "<C-k>", function()
  require("softpair").kill_line()
end, { desc = "Soft kill line" })
```

## References

This is not a clean-room implementation. The project is intended to be a
license-compatible Lua/Neovim port of behavior and APIs from existing GPL
software.

- [Puni](https://github.com/AmaiKinono/puni): primary behavioral reference for
  soft structural editing, pair protection, slurp/barf/splice-style operations,
  and the user-facing editing model.
- [GNU Emacs](https://www.gnu.org/software/emacs/): reference for editing APIs
  that Puni builds on, including sexp navigation, syntax parsing, electric pair
  behavior, region handling, kill/yank conventions, and visual feedback.
- GNU Emacs Lisp libraries: `cl-lib`, `rx`, `subr-x`, `pulse`, `syntax`,
  `lisp`, `elec-pair`, and related built-in editing functions are relevant
  references when translating behavior.
- [Neovim API](https://neovim.io/doc/user/api.html): host editor API used for
  buffer edits, mappings, registers, and notifications.
- [Tree-sitter](https://tree-sitter.github.io/tree-sitter/): planned parsing
  backend for language-aware behavior where Neovim exposes a parser.

Translated or closely derived code should keep a local SPDX header and mention
the source file or API that informed it. See `NOTICE.md` for the repository
notice.

## Porting Coverage

See `PORTING.md`.

## License

GPL-3.0-or-later. See `LICENSE`.
