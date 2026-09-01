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
-- Guarded so the escape sequence is not printed as literal garbage in a
-- terminal that would not understand it.
--
-- Both halves of the guard matter. KITTY_WINDOW_ID only exists when kitty
-- started the process directly; ssh does not forward it, so on this box --
-- which is mostly reached over ssh from the laptop -- that check alone
-- silently disables the whole thing, and kitty goes on eating shift+arrows
-- in the ssh window. TERM *is* forwarded by ssh, so it is what identifies
-- kitty on the far end.
if vim.env.KITTY_WINDOW_ID or vim.env.TERM == "xterm-kitty" then
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
end
