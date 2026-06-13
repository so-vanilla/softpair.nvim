-- SPDX-License-Identifier: GPL-3.0-or-later

if vim.g.loaded_softpair_nvim == 1 then
  return
end

vim.g.loaded_softpair_nvim = 1
require("softpair.commands").create()
