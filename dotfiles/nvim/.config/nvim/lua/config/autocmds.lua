-- config/autocmds.lua - event hooks, loaded by LazyVim after its own.
-- LazyVim's defaults already cover the usual ones (highlight on yank,
-- restore cursor position, auto-create missing parent dirs on save, strip
-- trailing whitespace notifications, close scratch buffers with q).
-- See: https://lazyvim.org/configuration/general
--
-- Add hooks here rather than in a plugin file, e.g.:
--
--   vim.api.nvim_create_autocmd("FileType", {
--     pattern = { "gitcommit", "markdown" },
--     callback = function() vim.opt_local.spell = true end,
--   })

-- --- tell kitty when nvim has focus ------------------------------------
-- kitty shortcuts win over the program running inside it, so kitty's
-- shift+up/down (scroll by line) and ctrl+shift+arrows (scroll, switch tab)
-- would swallow exactly the keys config/standard-keys.lua needs for
-- shift-selection. kitty's answer is a per-window user variable: set one
-- here, and kitty.conf unmaps those keys while it is set. See
-- `map --when-focus-on` in dotfiles/kitty/.config/kitty/kitty.conf.
--
-- The payload is OSC 1337 SetUserVar with a base64 value ("MQo" = "1").
--
-- Sent unconditionally, on purpose. This used to be gated on KITTY_WINDOW_ID
-- or TERM=="xterm-kitty", and the gate was the bug: ssh does not forward
-- KITTY_WINDOW_ID, and TERM is not reliably preserved either -- plenty of
-- ssh setups rewrite it -- so on the machine this config is mostly used from,
-- the variable was silently never set and kitty went on eating the keys.
--
-- The cost of being wrong the other way is nil: OSC is a self-terminating
-- escape sequence, and a terminal that does not know 1337 consumes it and
-- moves on. Guessing whether the far end is kitty is not worth a broken
-- editor when the guess is wrong.
vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
  group = vim.api.nvim_create_augroup("KittyInEditorSet", { clear = true }),
  callback = function()
    io.stdout:write("\x1b]1337;SetUserVar=in_editor=MQo\a")
  end,
})
-- Unset on the way out, or kitty keeps handing those keys to a shell that
-- has no use for them. VimSuspend covers ctrl+z-ing out to the shell.
vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
  group = vim.api.nvim_create_augroup("KittyInEditorUnset", { clear = true }),
  callback = function()
    io.stdout:write("\x1b]1337;SetUserVar=in_editor\a")
  end,
})
