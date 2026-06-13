# Notices

softpair.nvim is a GPL-3.0-or-later Neovim plugin.

This project is a porting-oriented implementation and is not clean-room work.
Behavior, names of editing concepts, and future algorithmic structure may be
translated from or compared against:

- Puni, licensed GPL-3.0-or-later
  - upstream: https://github.com/AmaiKinono/puni
  - reference revision: `fe132f803868f325cf6f162139e327b76df9e4c1`
  - primary reference file: `puni.el`
- GNU Emacs and GNU Emacs Lisp libraries, licensed GPL-3.0-or-later
  - upstream: https://www.gnu.org/software/emacs/
  - reference version: GNU Emacs 30.2
  - relevant reference files: `syntax.el`, `lisp.el`, `elec-pair.el`,
    `subr.el`, `subr-x.el`, `simple.el`, `indent.el`, and `pulse.el`

Files that translate substantial source-level logic should keep an SPDX header
and a short source note near the top of the file.

The current implementation is intentionally small. It ports behavior by building
Neovim-native Lua modules around buffer edits, mappings, and registers rather
than embedding Emacs Lisp.
