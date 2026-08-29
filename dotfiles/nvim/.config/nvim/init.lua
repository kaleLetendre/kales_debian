-- init.lua - entry point, stowed to ~/.config/nvim/init.lua.
--
-- Deliberately one line. Everything real lives under lua/:
--   config/lazy.lua       bootstrap + which LazyVim extras are on
--   config/options.lua    editor settings
--   config/keymaps.lua    keys on top of LazyVim's defaults
--   config/autocmds.lua   event hooks
--   config/cheatsheet.lua the <leader>? popup
--   plugins/*.lua         plugin overrides, merged into the LazyVim spec
require("config.lazy")
