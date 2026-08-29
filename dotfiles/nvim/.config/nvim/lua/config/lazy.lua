-- config/lazy.lua - bootstrap lazy.nvim, then declare the whole plugin set.
--
-- lazy.nvim is cloned on first launch into ~/.local/share/nvim/lazy (state,
-- not config, so it is not in this repo). Every plugin it then installs gets
-- pinned to an exact commit in lazy-lock.json, which lands back in this repo
-- via the stow symlink. Commit that file to make the setup reproducible.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim itself, plus its default plugin set.
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- LazyVim "extras": opt-in bundles, each wiring up an LSP, a formatter,
    -- a treesitter parser and (where it exists) a debug adapter for one
    -- language. Listed explicitly here rather than left to lazyvim.json so
    -- the enabled set is readable in the repo without launching the editor.
    --
    -- `:LazyExtras` browses the full catalogue and can toggle others; it
    -- writes its choices to lazyvim.json in this directory, which is inside
    -- the repo, so anything enabled that way is tracked too.
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.clangd" },

    -- Debugging (breakpoints, stepping, variable inspection). The Go and
    -- Rust extras above only register their debug adapters if this is on.
    { import = "lazyvim.plugins.extras.dap.core" },

    -- Local overrides. Loaded last so they win over everything above.
    { import = "plugins" },
  },
  defaults = {
    -- LazyVim's own plugins lazy-load; ours load at startup unless a spec
    -- says otherwise. Keeps surprises out of local overrides.
    lazy = false,
    -- Track git HEAD rather than plugin release tags: a lot of plugins tag
    -- rarely and their newest release can be months behind a fix. The
    -- lockfile is what pins us, not the tag.
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  -- A handful of plugins declare luarocks dependencies. None we use do, and
  -- leaving this on makes lazy.nvim try to bootstrap its own lua+luarocks
  -- into ~/.local/share/nvim/lazy-rocks, which then shows up as a permanent
  -- :checkhealth ERROR. If a future plugin genuinely needs rocks, flip this
  -- back on and `apt-get install luarocks` in setup/69-neovim.sh.
  rocks = { enabled = false },
  checker = {
    enabled = true, -- poll for plugin updates
    notify = false, -- but do not interrupt; :Lazy shows what's pending
  },
  performance = {
    rtp = {
      -- Built-in vim plugins superseded by better ones or simply unused.
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
