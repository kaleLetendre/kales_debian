-- config/keymaps.lua - keys on top of LazyVim's defaults.
-- LazyVim's full default list: https://lazyvim.org/keymaps
-- Loaded automatically by LazyVim after plugins, so it can override them.

local cheatsheet = require("config.cheatsheet")

-- <leader>? opens the cheatsheet, mirroring Super+? in i3. Same chord, same
-- job, so there is one "what were the keys again" reflex instead of two.
--
-- This overrides a LazyVim default: <leader>? normally pops which-key's
-- buffer-local keymap list. That moves to <leader>bk (buffer > keymaps) so
-- it is still one chord away.
-- Context-sensitive: in the explorer, a picker, lazygit or any other window
-- that rebinds most of the keyboard, this lists *that window's* keys rather
-- than the full reference, which would be almost entirely wrong there.
vim.keymap.set("n", "<leader>?", cheatsheet.contextual, { desc = "Cheatsheet (this window)" })

vim.keymap.set("n", "<leader>bk", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer Keymaps (which-key)" })

-- The cheatsheet is the reference; the tutorial is the path through it, in
-- the order worth learning. Read it start to finish once.
vim.keymap.set("n", "<leader>H", function()
  cheatsheet.open("TUTORIAL")
end, { desc = "Tutorial" })

-- Same two by name, for when the chord is the part you forgot.
vim.api.nvim_create_user_command("Cheatsheet", function()
  cheatsheet.open("CHEATSHEET")
end, { desc = "Open the keybinding cheatsheet" })

vim.api.nvim_create_user_command("Tutorial", function()
  cheatsheet.open("TUTORIAL")
end, { desc = "Open the Neovim tutorial" })
