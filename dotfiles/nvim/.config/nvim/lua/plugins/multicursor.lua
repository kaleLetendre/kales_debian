-- plugins/multicursor.lua - ctrl+d multiple cursors.
--
-- The one thing in the standard-keys layer (lua/config/standard-keys.lua)
-- that cannot be done with a keymap: vim has no multiple cursors. `:s` and
-- macros cover the same ground and are strictly more powerful, but "select
-- the word, hit ctrl+d four times, type" is the reflex worth keeping.
--
-- Why this plugin over vim-visual-multi, the older and better-known one:
-- vim-visual-multi claims a pile of keys globally (ctrl+n, ctrl+up/down,
-- the shifted arrows while it is active) and would fight the selection keys
-- this config just set up. multicursor.nvim binds nothing on its own -- every
-- key below is one we chose -- so there is nothing to collide with.
return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "VeryLazy",
    -- Loaded after startup rather than on the first keypress, so the press
    -- that would have triggered the load is not also the one being handled.
    --
    -- Known upstream wart, unrelated to loading: matchAddCursor drives some
    -- of its work through feedkeys, so if the *next* keystrokes are already
    -- sitting in the same input packet as ctrl+d, its internal `"_yiw` can
    -- land in the buffer as literal text. Reproducing it takes ctrl+d and
    -- the following command arriving in one read -- a paste, a macro, or
    -- typing faster than one ssh round trip. Ordinary typing, local or
    -- remote, never hits it; measured clean down to a 0ms gap between
    -- separate keystrokes.
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      -- The plugin already defines MultiCursorCursor as reverse video, so an
      -- extra cursor renders as an inverted block -- that *is* what it is
      -- meant to look like, and the character under it stays readable. The
      -- one distinction it does not make is live versus parked: both use
      -- reverse. Link the parked ones to Visual so a glance tells you whether
      -- escape has already stood them down.
      local function cursor_highlights()
        vim.api.nvim_set_hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
      end
      cursor_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("MultiCursorParkedHl", { clear = true }),
        callback = cursor_highlights,
      })

      -- Turn completion off while extra cursors exist.
      --
      -- This is the bug that made multi-cursor look broken. blink.cmp and
      -- multicursor both instrument the insert session and blink wins: with
      -- the completion engine live, text typed at the main cursor never
      -- reaches the others. It is timing-dependent, which is what made it so
      -- confusing -- blink debounces, so typing fast enough that it never
      -- fires works, while pausing between keystrokes (i.e. typing like a
      -- person) silently drops every cursor but one.
      --
      -- Suppression has to happen when a cursor is *created*, before the next
      -- insert session begins. onSafeState alone is not enough: it only fires
      -- in normal mode, so by the time you are typing blink has long since
      -- attached. It is still the right place to *restore* the setting, which
      -- is why it is used for that half.
      local function suppress_completion()
        vim.b.completion = false
      end
      -- And enforced again at every insert entry, not just at creation: the
      -- cursors outlive the mapping that made them, so `i`, `a`, `o`, `ciw`
      -- and friends all start sessions that must have completion off too.
      vim.api.nvim_create_autocmd("InsertEnter", {
        group = vim.api.nvim_create_augroup("MultiCursorNoCompletion", { clear = true }),
        callback = function()
          if mc.hasCursors() then
            suppress_completion()
          end
        end,
      })

      mc.onSafeState(function()
        if not mc.hasCursors() and vim.b.completion == false then
          -- Back to nil, not true: nil means "whatever the buffer's default
          -- is", which is what it was before we touched it.
          vim.b.completion = nil
        end
      end)

      local set = vim.keymap.set

      -- ctrl+d: put a cursor on the next occurrence of the word under the
      -- cursor (or of the current selection). Exactly VS Code's ctrl+d.
      -- This takes ctrl+d away from scroll-half-page-down; PageDown and
      -- ctrl+e still scroll.
      set({ "n", "x" }, "<C-d>", function()
        mc.matchAddCursor(1)
      end, { desc = "Add cursor at next match" })

      -- ctrl+shift+d skips this occurrence and takes the one after, for when
      -- one hit in the middle should be left alone. (VS Code spells this
      -- ctrl+k ctrl+d; a two-key chord is not worth the trouble here.)
      set({ "n", "x" }, "<C-S-d>", function()
        mc.matchSkipCursor(1)
      end, { desc = "Skip to next match" })

      -- ctrl+alt+up / ctrl+alt+down: a column of cursors, same as VS Code.
      set({ "n", "x" }, "<C-A-Up>", function()
        mc.lineAddCursor(-1)
      end, { desc = "Add cursor above" })
      set({ "n", "x" }, "<C-A-Down>", function()
        mc.lineAddCursor(1)
      end, { desc = "Add cursor below" })

      -- alt+click adds or removes a cursor, and alt+drag adds a column of
      -- them. VS Code uses alt+click for this too. Deliberately not
      -- ctrl+click: kitty.conf gives that to "open the link under the
      -- pointer", and kitty would eat it before nvim saw it.
      set("n", "<M-LeftMouse>", mc.handleMouse, { desc = "Add cursor at click" })
      set("n", "<M-LeftDrag>", mc.handleMouseDrag, { desc = "Add cursors by drag" })
      set("n", "<M-LeftRelease>", mc.handleMouseRelease, { desc = "Add cursors by drag" })

      -- All of the above are normal/visual mode only, and in a config built
      -- around normal editor conventions you spend most of your time in
      -- insert mode -- where ctrl+d silently fell through to vim's "outdent
      -- one shiftwidth" and ctrl+alt+arrow did nothing at all. Give them an
      -- insert-mode entry point.
      --
      -- stopinsert first, then do the work on the next tick: adding a cursor
      -- while nvim is still in insert mode leaves the plugin's own state and
      -- the mode disagreeing.
      local function from_insert(fn)
        return function()
          vim.cmd("stopinsert")
          vim.schedule(function()
            suppress_completion()
            fn()
          end)
        end
      end

      -- ctrl+d from insert leaves you in normal mode with the cursors placed,
      -- because that is where the operator you are about to use (ciw, A, x)
      -- has to run from anyway.
      set("i", "<C-d>", from_insert(function()
        mc.matchAddCursor(1)
      end), { desc = "Add cursor at next match" })

      -- A column of cursors, on the other hand, is nearly always followed by
      -- typing, so these hand insert mode straight back with every cursor
      -- live.
      -- Deliberately nvim's feedkeys and not the plugin's mc.feedkeys, even
      -- though the docs steer you to the latter inside multicursor mappings:
      -- mc.feedkeys routes the `i` through the plugin's own input path, which
      -- here re-enters insert in a state where nothing replicates. Measured
      -- both ways.
      set("i", "<C-A-Up>", from_insert(function()
        mc.lineAddCursor(-1)
        vim.api.nvim_feedkeys("i", "m", false)
      end), { desc = "Add cursor above" })
      set("i", "<C-A-Down>", from_insert(function()
        mc.lineAddCursor(1)
        vim.api.nvim_feedkeys("i", "m", false)
      end), { desc = "Add cursor below" })

      -- While more than one cursor exists the plugin installs a keymap layer,
      -- which is where escape gets its two-step meaning: first press parks
      -- the extra cursors (so you can move the real one), second press
      -- discards them. Same as pressing escape twice in VS Code.
      mc.addKeymapLayer(function(layer)
        layer("n", "<Esc>", function()
          if mc.cursorsEnabled() then
            mc.clearCursors()
          else
            mc.enableCursors()
          end
        end, { desc = "Clear extra cursors" })
      end)
    end,
  },
}
