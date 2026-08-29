-- 69-neovim-provision.lua - headless provisioning pass for setup/69-neovim.sh.
--
-- NOT part of the nvim config. It lives in setup/ next to the module that
-- runs it and never loads during normal editing. bootstrap.sh iterates
-- setup/*.sh, so the .lua extension keeps it out of the module sequence.
--
-- Purpose: after bootstrap.sh finishes, `nvim` should open ready. Without
-- this pass the first interactive launch spends a minute cloning plugins,
-- compiling treesitter parsers and downloading language servers, and the
-- editor is half-broken until it finishes.
--
-- Three things make headless provisioning different from just opening nvim:
--
--   1. LazyVim hangs nearly all of its own setup off lazy.nvim's VeryLazy
--      event, which fires from UIEnter. `--headless` has no UI, so VeryLazy
--      never fires and none of LazyVim's LSP or Mason wiring runs. Firing it
--      by hand is what makes this equivalent to opening the editor.
--   2. nvim-treesitter's automatic install is asynchronous AND announces
--      "Installed N/N languages" before the compiled parsers are on disk.
--      Watching for that message, or polling its installed-language count,
--      quits while parsers are still compiling and they never land. The only
--      reliable approach is to drive the install ourselves and await the
--      handle it returns.
--   3. Mason also installs asynchronously. nvim exiting mid-download kills it
--      ("Neovim is exiting while packages are still installing") and leaves
--      partial packages behind, so it needs a wait too.

local TIMEOUT_MS = 10 * 60 * 1000

-- How long Mason's install state must hold still before we call it finished.
local STABLE_FOR_MS = 8 * 1000
-- Never finish before this. At t=0 nothing has started, so "nothing is
-- installing" is trivially true and would end the wait before the first
-- download begins.
local MIN_WAIT_MS = 15 * 1000

-- Flush every line: this script ends in `qa!`, and a buffered final write
-- would be lost on exit when stderr is a pipe rather than a terminal.
local function say(msg)
  io.stderr:write("  -> " .. msg .. "\n")
  io.stderr:flush()
end

vim.cmd("doautocmd User VeryLazy")

-- Nothing queues installs until something needs them: LazyVim resolves the
-- language servers, formatters and linters it wants the first time
-- nvim-lspconfig loads, which happens on BufNewFile/BufReadPre. Opening one
-- file is enough -- lspconfig installs its whole set in one pass, not just
-- the tools for this filetype. The file is never written.
vim.cmd("edit " .. vim.fn.tempname() .. ".go")

-- --- treesitter ------------------------------------------------------------
-- The language list is whatever the config actually asks for, read back from
-- the merged plugin spec rather than duplicated here, so enabling another
-- LazyVim lang extra automatically widens this too.
local ok_ts, ts = pcall(require, "nvim-treesitter")
if ok_ts then
  local plugin = require("lazy.core.config").plugins["nvim-treesitter"]
  local opts = plugin and require("lazy.core.plugin").values(plugin, "opts", false)
  local want = opts and opts.ensure_installed or {}

  if #want > 0 then
    local cfg = require("nvim-treesitter.config")
    local parser_dir = cfg.get_install_dir("parser")

    -- Check the compiled parsers on disk, not the plugin's own
    -- get_installed() list: that list is populated from cached state and
    -- reports languages as present while they are still compiling.
    local function missing()
      local miss = {}
      for _, lang in ipairs(want) do
        if vim.fn.filereadable(parser_dir .. "/" .. lang .. ".so") == 0 then
          miss[#miss + 1] = lang
        end
      end
      return miss
    end

    local miss = missing()
    if #miss == 0 then
      say(("treesitter: all %d parsers already installed"):format(#want))
    else
      say(("treesitter: compiling %d of %d parsers"):format(#miss, #want))
      -- force = true matters. Without it the call collides with the
      -- automatic install VeryLazy just kicked off, returns a handle that
      -- resolves immediately, and nothing is actually built. Only the
      -- parsers genuinely absent from disk are passed, so this stays cheap
      -- on a re-run instead of recompiling all 30 every bootstrap.
      local handle = ts.install(miss, { force = true })
      if handle and handle.wait then
        handle:wait(TIMEOUT_MS)
      end

      miss = missing()
      if #miss > 0 then
        say("treesitter: still missing " .. table.concat(miss, ", "))
        say("treesitter: open nvim and run :TSInstall on those")
      else
        say(("treesitter: all %d parsers installed"):format(#want))
      end
    end
  end
end

-- --- mason -----------------------------------------------------------------
-- Mason has no "requested set" we can read back the way treesitter does: the
-- list is assembled from mason.nvim's own ensure_installed plus whatever the
-- LSP, formatter and linter specs ask for as buffers open. So instead of
-- driving it, watch it: wait until no package is mid-install and that has
-- been true for a while.
local ok_mason, registry = pcall(require, "mason-registry")
if ok_mason then
  local function installing()
    local n = 0
    for _, pkg in ipairs(registry.get_all_packages()) do
      if pkg:is_installing() then
        n = n + 1
      end
    end
    return n
  end

  -- Track elapsed milliseconds rather than counting polls: vim.wait treats
  -- its interval argument as a floor and re-runs the predicate on every
  -- event loop wakeup, so a poll counter ticks over in milliseconds.
  local started_at = vim.uv.now()
  local last, changed_at = nil, started_at

  local settled = vim.wait(TIMEOUT_MS, function()
    local now = installing()
    if now ~= last then
      last, changed_at = now, vim.uv.now()
      return false
    end
    local elapsed = vim.uv.now()
    return now == 0
      and (elapsed - changed_at) >= STABLE_FOR_MS
      and (elapsed - started_at) >= MIN_WAIT_MS
  end, 250)

  if not settled then
    say("mason: did not settle in 10 minutes; open nvim and check :Mason")
  end

  -- Waiting is not enough on its own. Mason raises "Package is already
  -- installing" when two things request the same package at once -- which
  -- happens on a cold machine, where LazyVim's treesitter build hook and its
  -- LSP setup both want tree-sitter-cli -- and that error aborts the rest of
  -- the batch. So check the requested set against what actually landed and
  -- install the difference explicitly.
  local plugin = require("lazy.core.config").plugins["mason.nvim"]
  local opts = plugin and require("lazy.core.plugin").values(plugin, "opts", false)
  local want = opts and opts.ensure_installed or {}

  local missing = {}
  for _, name in ipairs(want) do
    if not vim.tbl_contains(missing, name) and not registry.is_installed(name) then
      missing[#missing + 1] = name
    end
  end

  if #missing > 0 then
    say(("mason: retrying %s"):format(table.concat(missing, ", ")))
    for _, name in ipairs(missing) do
      local ok_pkg, pkg = pcall(registry.get_package, name)
      if ok_pkg then
        pkg:install()
      end
    end
    -- Same quiescence wait as above, minus the start-up floor: these
    -- installs are already in flight by the time we get here.
    local retry_last, retry_changed = nil, vim.uv.now()
    vim.wait(TIMEOUT_MS, function()
      local now = installing()
      if now ~= retry_last then
        retry_last, retry_changed = now, vim.uv.now()
        return false
      end
      return now == 0 and (vim.uv.now() - retry_changed) >= STABLE_FOR_MS
    end, 250)
  end

  local still = {}
  for _, name in ipairs(want) do
    if not registry.is_installed(name) then
      still[#still + 1] = name
    end
  end
  if #still > 0 then
    say("mason: still missing " .. table.concat(still, ", "))
    say("mason: open nvim and run :Mason to finish")
  else
    say(("mason: all %d requested packages installed"):format(#want))
  end
end

vim.cmd("qa!")
