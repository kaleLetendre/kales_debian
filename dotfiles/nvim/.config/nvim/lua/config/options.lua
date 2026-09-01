-- config/options.lua - loaded by LazyVim *before* lazy.nvim starts, so
-- anything here is in effect while plugins load.
-- LazyVim's own defaults: https://lazyvim.org/configuration/general

-- LazyVim defaults to relative line numbers, which pay off once you think
-- in `5j` / `3dd`. Coming from VS Code that mostly makes it hard to find
-- the line a stack trace named. Absolute for now; flip to true when the
-- counted motions start feeling natural.
vim.opt.relativenumber = false

-- Do not fold anything on open. LazyVim enables treesitter folding, and a
-- file that opens half-collapsed is disorienting if you did not ask for it.
-- `zc` / `zo` still fold and unfold by hand.
vim.opt.foldlevel = 99

-- Keep some context above and below the cursor instead of letting it sit
-- on the very first or last visible line.
vim.opt.scrolloff = 8

-- Neovim can host plugins written in perl and ruby. Nothing here does, and
-- leaving the providers enabled means two permanent :checkhealth warnings
-- about interpreters we will never install. Turn them off so checkhealth
-- output stays worth reading.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Clipboard: pick the provider from what the session can actually reach.
--
-- Local (a display, and xclip to talk to it): say nothing and let nvim
-- autodetect. xclip reads and writes the X selection directly.
--
-- Over ssh there is no display, and the clipboard that matters lives on the
-- laptop, reachable only through the terminal by OSC 52 escape sequence. Both
-- directions go that way, so ctrl+c and ctrl+v are the same pair of keys here
-- as everywhere else -- no ctrl+shift+v special case for pasting.
--
-- Reading the clipboard over OSC 52 means asking the terminal to hand its
-- contents back, which kitty refuses by default (it prompts, every time, so a
-- program on a remote box cannot silently scrape what you copied). That is
-- granted once, on the laptop, by `clipboard_control ... read-clipboard` in
-- dotfiles/kitty/.config/kitty/kitty.conf. Without that line on the machine
-- kitty actually runs on, paste here will prompt on every use.
--
-- `:checkhealth vim.provider` reports which provider a session picked.
if not (vim.env.DISPLAY and vim.fn.executable("xclip") == 1) then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "osc52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end
