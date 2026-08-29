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
