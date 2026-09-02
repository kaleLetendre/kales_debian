-- plugins/overrides.lua - tweaks to plugins LazyVim already installs.
--
-- Every file in this directory is merged into the plugin spec. To change a
-- plugin, name it and pass only the keys you want different; lazy.nvim deep
-- merges the rest from LazyVim's version. To add a new plugin, add a file.

return {
  -- which-key is the discoverability layer: hold <leader> (space) and it
  -- lists every key that can follow, with a label. LazyVim waits 200ms
  -- before showing it; drop that so the menu is effectively the default
  -- behaviour rather than something you have to hesitate for.
  {
    "folke/which-key.nvim",
    opts = {
      delay = 100,
    },
  },

  -- <leader>fp lists projects. Out of the box snacks scans ~/dev and
  -- ~/projects for directories containing a .git (or Makefile, package.json,
  -- ...), and neither of those exists on this machine -- repos live at the
  -- top level of $HOME and grouped under the workspace dirs that
  -- setup/80-home-dirs.sh creates. Point it at the real layout. max_depth 2
  -- from $HOME reaches both ~/wiregraph and ~/personal/argus.
  --
  -- Picking a project loads its saved session, so you land back on the files
  -- and splits you left open, not an empty buffer.
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            dev = { "~", "~/personal", "~/caracal" },
            max_depth = 2,
          },

          -- The explorer ships with preview off. Turn it on as "main",
          -- which paints the file under the cursor into the main editor
          -- window rather than a cramped pane inside the 40-column sidebar.
          -- Moving down the tree previews; Enter (or l) confirms and really
          -- opens it. Same shape as VS Code's single-click preview versus
          -- double-click open. P still toggles it off for a session.
          explorer = {
            layout = { preset = "sidebar", preview = "main" },
          },
        },
      },

      -- The start screen you get from a bare `nvim` has Find File, Recent
      -- Files and Restore Session but no way to jump to another project,
      -- which is the one thing you actually want from a start screen. Add
      -- Projects as `p`. Listing every key because lazy.nvim replaces list
      -- options wholesale rather than merging them -- naming only the new
      -- entry would drop the other six.
      dashboard = {
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.dashboard.pick('projects')" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
      },
    },
  },

  -- Diagnostics render below the line, not off the edge of it.
  --
  -- LazyVim shows the message as virtual text on the same line. Anything
  -- longer than the remaining width is simply cut off at the window edge, and
  -- virtual text cannot be scrolled to -- it is not real buffer text, so
  -- there is nothing to scroll horizontally *to*. Rust diagnostics in
  -- particular are routinely a paragraph long, so the useful half is the half
  -- you cannot see.
  --
  -- virtual_lines puts the message on its own lines underneath instead, where
  -- it wraps. current_line = true limits that to the line the cursor is on,
  -- so a file with twenty warnings is not permanently pushed apart -- the
  -- others still show their sign in the gutter and their underline.
  --
  -- <leader>cd still opens the same text in a float, and <leader>xX lists
  -- every diagnostic in the buffer.
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        virtual_text = false,
        virtual_lines = { current_line = true },
      },
    },
  },

  -- gopls is the Go language server. LazyVim's go extra expects it but only
  -- has Mason fetch it the first time a real Go file is opened, which means
  -- a freshly bootstrapped machine has no Go LSP until you happen to open
  -- one and wait. C and Rust do not have this problem -- clangd comes from
  -- apt and rust-analyzer from rustup, both in setup/69-neovim.sh. Naming
  -- gopls here puts it in mason's ensure_installed, so the headless
  -- provisioning pass installs it with everything else.
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "gopls" } },
  },

  -- Colorscheme. tokyonight ships with LazyVim and is what the install
  -- fallback expects. Swapping it is a one-word change here -- see
  -- THEMES.md in the repo root for how the rest of the desktop is themed.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
