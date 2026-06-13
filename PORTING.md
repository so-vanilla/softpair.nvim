# Porting Coverage

This file tracks the migration surface from Puni and the relevant GNU Emacs
editing APIs.

## Implemented

| Area | softpair.nvim module | Notes |
| --- | --- | --- |
| Basic pair insertion | `softpair.pair` | Inserts `()`, `[]`, `{}`, and configured quote pairs. |
| Close delimiter skip | `softpair.pair` | Skips over an existing close delimiter at point. |
| Same-quote skip | `softpair.pair` | Skips over an existing quote unless escaped. |
| Pair backspace | `softpair.pair` | Deletes an adjacent pair in one operation. |
| Pair forward delete | `softpair.pair` | Deletes an opening delimiter and its adjacent close delimiter together. |
| Soft line kill | `softpair.soft_delete` | Refuses deletion of an unbalanced delimiter fragment. |
| Register integration | `softpair.buffer` | Stores killed text in the unnamed register and `+` when enabled. |
| Simple syntax balance | `softpair.syntax` | Stack-based scanner for `()`, `[]`, `{}`; escaped candidates and configured strings are ignored. |
| Sexp movement and bounds | `softpair.sexp` | Puni public movement and bounds APIs are exposed with a conservative scanner. |
| Structural editing | `softpair.struct` | Slurp/barf/splice/squeeze/split/raise/transpose/convolute/wrap/textobject APIs are present. |
| Puni command surface | `softpair.commands` | `:Puni...` user commands and hyphenated Lua aliases are generated for public `puni-*` names. |
| Undo and visual feedback | `softpair.feedback` | Structural edits try `undojoin` and temporary `IncSearch` highlights as a lightweight `pulse` equivalent. |

## Partial

| Area | Current boundary |
| --- | --- |
| String handling | Only double quotes are treated as string delimiters by default; configured string delimiters are honored by the byte scanner. |
| Normal-mode point semantics | Vim cannot place the normal cursor after the last character. softpair treats the last character position, including a single-character line, as an end-of-line point for `kill_line`. |
| Language syntax | No Tree-sitter integration yet. Comments, heredocs, raw strings, Lisp reader syntax, and language-specific forms are not fully recognized. |
| Deletion safety | Pair backspace, pair forward delete, `kill_line`, region delete/kill, active-region delete/kill, char delete, force delete, and broad `soft_delete` APIs share the conservative scanner. Deleting an escape prefix is refused when it would expose a protected candidate. Force delete warns before breaking a pair. |
| Angle brackets | `wrap_angle` can insert `<...>`, but `<` and `>` are not structural delimiters unless configured in `pairs`. |

## Public Puni API Coverage

| Puni command / Emacs area | Main primitive dependency | Planned softpair API | Tests |
| --- | --- | --- | --- |
| strict string/comment sexp helpers | string/comment syntax state | aliases to scanner movement | alias only |
| `puni-forward-sexp` / `puni-backward-sexp` | `forward-sexp`, `syntax-ppss` | `softpair.sexp.forward()` / `backward()` | covered |
| strict sexp variants | strict syntax-aware sexp movement | scanner movement aliases | covered |
| beginning/end/list/bounds APIs | sexp bounds | `softpair.sexp` | covered |
| before/after/dangling/balance predicates | syntax parser | `softpair.sexp` and `softpair.syntax` | partial |
| active region APIs | region state | `softpair.region`, visual commands | partial |
| delete/kill/soft-delete APIs | soft delete region selection | `softpair.soft_delete` | partial |
| char and word delete/kill APIs | movement plus soft delete | `softpair.soft_delete` | covered |
| `puni-kill-line` / backward | soft delete and kill ring | `softpair.soft_delete` | covered |
| `puni-squeeze` | list bounds and deletion | `softpair.struct.squeeze()` | covered |
| slurp/barf forward/backward | list and sexp bounds | `softpair.struct` | covered |
| splice and killing variants | list bounds and soft deletion | `softpair.struct` | partial |
| split / raise / transpose / convolute | structural rewriting | `softpair.struct` | partial |
| change/copy inner/outer | inner bounds and registers | `softpair.struct` | covered |
| wrap next/round/square/curly/angle | sexp bounds and delimiters | `softpair.struct` | covered |
| `puni-disable-puni-mode` | Emacs minor mode | no-op compatibility shim | alias only |
| Electric-pair mode parity | mode-local pair tables and inhibit predicates | `softpair.pair` config predicates | partial |
| Undo boundaries and visual feedback | undo markers and `pulse` | `softpair.feedback` | partial |

All non-private `puni-*` function names from the reference revision are exposed
as hyphenated Lua aliases. Private `puni--*` helpers are intentionally mapped to
internal module boundaries instead of being exported.

## Porting Rule

When a feature is translated from Puni or GNU Emacs source-level behavior, add:

- an SPDX header in the Lua file
- a short source-reference comment near the translated code
- focused tests that describe the expected behavior before adding broader filetype support
