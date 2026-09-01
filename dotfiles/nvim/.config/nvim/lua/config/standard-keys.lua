-- config/standard-keys.lua - the normal-text-editor layer, required by
-- config/keymaps.lua.
--
-- Modal editing is not the part worth fighting. The part worth fighting is
-- that vim also discards forty years of shared convention: ctrl+s to save,
-- ctrl+c/x/v, ctrl+z, ctrl+a, shift+arrows to select. None of that conflicts
-- with having modes, so this file puts it back.
--
-- Vim shipped this idea as mswin.vim (`:h mswin`); Neovim dropped that file
-- from its runtime. It is spelled out here instead of sourced so every
-- choice is visible, and so the vim meanings we displace get relocated
-- rather than deleted. CHEATSHEET.md has the "where did that key go" table.

-- --- 1. what a selection is --------------------------------------------
-- These three options are what make shift+arrow work at all; the keymaps
-- below are useless without them.
--
-- keymodel=startsel  a shifted cursor key (arrows, Home/End, PageUp/Down)
--                    starts a selection instead of being ignored
--         ,stopsel   an unshifted cursor key ends it, rather than leaving
--                    the selection hanging around like `v` does
-- selectmode=key,mouse  shift-keys and mouse drags enter *Select* mode, not
--                    Visual mode. The difference is the whole point: in
--                    Select mode typing a character replaces the selection,
--                    exactly like every other editor. Visual mode is still
--                    one `v` away and behaves as it always did.
-- selection=exclusive  the character under the cursor is not part of the
--                    selection, so shift+right selects one character, not
--                    two. This is what mswin.vim sets, for the same reason.
vim.opt.keymodel = "startsel,stopsel"
vim.opt.selectmode = "key,mouse"
vim.opt.selection = "exclusive"

-- 'whichwrap' is the one that makes left-arrow at column 1 jump to the end
-- of the previous line instead of doing nothing. vim ships with b,s
-- (backspace and space wrap); the rest are opt-in for historical reasons
-- nobody remembers:
--   <  >  left/right arrow in normal and visual mode
--   [  ]  left/right arrow in insert mode
--   h  l  the h and l motions
-- With this set, every horizontal movement treats the buffer as one stream
-- of text, which is what every other editor does.
vim.opt.whichwrap:append("<,>,[,],h,l")

-- Mouse: 'mousemodel' already defaults to popup_setpos, whose shifted left
-- click extends the selection -- so shift+click works with no mapping. Left
-- drag selects, and because 'selectmode' contains "mouse" it lands in Select
-- mode, so typing replaces what you dragged over.

-- Local aliases. Mode letters: n normal, i insert, x visual, s select,
-- c command-line. Note "v" means x+s together, which is rarely what you
-- want here, so the tables below are always explicit.
local function map(modes, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { silent = true, desc = desc }, opts or {})
  vim.keymap.set(modes, lhs, rhs, opts)
end

-- A Select-mode mapping runs its right-hand side *in Select mode*, where
-- `y` would type the letter y rather than yank. <C-g> flips Select -> Visual
-- first, so every select-mode binding below starts with it.
local sel = "<C-g>"

-- --- 2. save ------------------------------------------------------------
-- `update` rather than `write`: it is a no-op on an unmodified buffer, so
-- reflexive ctrl+s does not churn mtimes and retrigger file watchers.
-- <Cmd> does not leave the current mode, so ctrl+s mid-sentence in insert
-- mode saves and leaves you typing.
--
-- Requires `stty -ixon` (set in dotfiles/zsh/.zshrc): ctrl+s is XOFF at the
-- terminal driver by default and would freeze the screen instead.
map({ "n", "i", "x", "s" }, "<C-s>", "<Cmd>update<CR>", "Save")

-- --- 3. clipboard -------------------------------------------------------
-- Explicitly the "+ register (the X11 CLIPBOARD selection, what other apps
-- paste from). LazyVim already sets clipboard=unnamedplus so plain y/p also
-- reach it, but naming the register keeps these keys correct regardless.
--
-- With no selection, ctrl+c and ctrl+x act on the current line, which is
-- what VS Code does.
map("n", "<C-c>", '"+yy', "Copy line")
map("x", "<C-c>", '"+y', "Copy")
map("s", "<C-c>", sel .. '"+y', "Copy")

map("n", "<C-x>", '"+dd', "Cut line")
map("x", "<C-x>", '"+d', "Cut")
map("s", "<C-x>", sel .. '"+d', "Cut")

-- Paste. In visual/select mode the selection goes to the black-hole
-- register ("_) first, so replacing text does not blow away the clipboard
-- you are pasting from -- the default `p`-over-a-selection swaps them.
map("n", "<C-v>", '"+p', "Paste")
map("x", "<C-v>", '"_d"+P', "Paste over selection")
map("s", "<C-v>", sel .. '"_d"+P', "Paste over selection")
-- <C-g>u first so one ctrl+z undoes the paste and not the whole insertion.
-- <C-r><C-o> inserts the register literally: no reindenting, no abbreviation
-- expansion, no comment-leader duplication.
map("i", "<C-v>", "<C-g>u<C-r><C-o>+", "Paste")
-- Command-line mode: pasting a path or a search string into `:` and `/`.
map("c", "<C-v>", "<C-r>+", "Paste", { silent = false })

-- The X11-era spellings of the same three, free of any vim meaning.
map({ "x", "s" }, "<C-Insert>", "<C-c>", "Copy", { remap = true })
map({ "x", "s" }, "<S-Del>", "<C-x>", "Cut", { remap = true })
map({ "n", "i" }, "<S-Insert>", "<C-v>", "Paste", { remap = true })

-- --- 4. select all ------------------------------------------------------
map("n", "<C-a>", "ggVG", "Select all")
map("i", "<C-a>", "<Esc>ggVG", "Select all")

-- --- 5. undo / redo -----------------------------------------------------
-- ctrl+z, and ctrl+y or ctrl+shift+z for redo (kitty reports ctrl+shift+z
-- as a distinct key via the kitty keyboard protocol; on a terminal that
-- cannot, ctrl+y is the one that works).
--
-- This gives up ctrl+z suspending nvim to the shell. `:sus` still does it,
-- and with kitty tabs there is little reason to.
map({ "n", "i", "x", "s" }, "<C-z>", "<Cmd>undo<CR>", "Undo")
map({ "n", "i", "x", "s" }, "<C-y>", "<Cmd>redo<CR>", "Redo")
map({ "n", "i", "x", "s" }, "<C-S-z>", "<Cmd>redo<CR>", "Redo")

-- --- 6. find ------------------------------------------------------------
-- Opens vim's own search prompt, so `n`/`N` still step through the hits.
-- silent=false or the prompt does not echo what you type.
-- Find-in-files stays on <leader>sg, replace-in-files on <leader>sr.
map("n", "<C-f>", "/", "Find in buffer", { silent = false })
map("i", "<C-f>", "<Esc>/", "Find in buffer", { silent = false })

-- --- 7. where the displaced vim keys went -------------------------------
-- ctrl+v was blockwise Visual (and insert-literal-character); ctrl+q is the
-- traditional mswin.vim home for both. ctrl+q is XON at the terminal driver
-- for the same reason ctrl+s is XOFF, so it also needs `stty -ixon`.
map({ "n", "x" }, "<C-q>", "<C-v>", "Blockwise visual")
map("i", "<C-q>", "<C-v>", "Insert literal character")

-- ctrl+a / ctrl+x were increment / decrement the number under the cursor.
-- Moved to + and - (whose defaults -- first non-blank of the next/previous
-- line -- are already covered by j/k and rarely used deliberately).
map({ "n", "x" }, "+", "<C-a>", "Increment number")
map({ "n", "x" }, "-", "<C-x>", "Decrement number")

-- ctrl+f was page-forward and ctrl+y was scroll-up-one-line. PageDown and
-- ctrl+e / ctrl+d cover both.

-- --- 8. editing keys other editors have ---------------------------------
-- Delete the word before/after the cursor while inserting.
map("i", "<C-BS>", "<C-w>", "Delete word before cursor")
map("i", "<C-Del>", "<C-o>dw", "Delete word after cursor")

-- In Select mode a printable character replaces the selection natively, but
-- backspace and delete need saying. Black-hole register: deleting a
-- selection should not overwrite what is on the clipboard.
map("s", "<BS>", sel .. '"_d', "Delete selection")
map("s", "<Del>", sel .. '"_d', "Delete selection")

-- --- 9. moving and duplicating lines -----------------------------------
-- LazyVim already binds alt+j / alt+k to move the current line (or the
-- selection) down and up. VS Code puts that on alt+down / alt+up, so alias
-- the arrows onto the same commands rather than reimplementing them.
map({ "n", "i", "x" }, "<A-Down>", "<A-j>", "Move line down", { remap = true })
map({ "n", "i", "x" }, "<A-Up>", "<A-k>", "Move line up", { remap = true })

-- shift+alt+down / shift+alt+up duplicate instead of moving. `:t` is copy;
-- `.` is here and `.-1` is the line above, and the cursor lands on the new
-- copy either way, as it does in VS Code.
map("n", "<A-S-Down>", "<Cmd>t.<CR>", "Duplicate line down")
map("n", "<A-S-Up>", "<Cmd>t.-1<CR>", "Duplicate line up")
-- gv reselects afterwards so the duplicate stays selected and can be moved
-- or duplicated again without re-dragging.
map("x", "<A-S-Down>", ":t'><CR>gv", "Duplicate selection down")
map("x", "<A-S-Up>", ":t'<-1<CR>gv", "Duplicate selection up")

-- ctrl+shift+k deletes the line, as in VS Code.
map("n", "<C-S-k>", "dd", "Delete line")

-- --- 10. indent a selection with tab ------------------------------------
-- gv reselects after the shift, so tab-tab-tab indents repeatedly instead of
-- indenting once and dropping the selection (vim's default `>` behaviour).
--
-- Only in visual and select mode. Normal-mode <Tab> is <C-i>, "forward in
-- the jump list", and insert-mode <Tab> is completion -- both stay.
map("x", "<Tab>", ">gv", "Indent")
map("x", "<S-Tab>", "<gv", "Outdent")
map("s", "<Tab>", sel .. ">gv", "Indent")
map("s", "<S-Tab>", sel .. "<gv", "Outdent")

-- --- 11. new lines without splitting the current one --------------------
-- ctrl+enter opens a line below, shift+enter above, from anywhere on the
-- line. kitty reports both as distinct keys via the kitty keyboard protocol;
-- a terminal that cannot will simply never send them.
map("n", "<C-CR>", "o", "New line below")
map("n", "<S-CR>", "O", "New line above")
map("i", "<C-CR>", "<Esc>o", "New line below")
map("i", "<S-CR>", "<Esc>O", "New line above")

-- --- 12. comment with ctrl+/ --------------------------------------------
-- The most universal shortcut there is, and LazyVim spends it on "focus the
-- terminal". The terminal moves to ctrl+` -- which is what VS Code uses for
-- it anyway -- so both keys end up more conventional, not less.
--
-- <C-_> is what a terminal without the kitty keyboard protocol sends for
-- ctrl+/; bind both so this survives outside kitty. remap=true because gcc
-- and gc are themselves mappings (mini.comment), not builtins.
map({ "n" }, "<C-/>", "gcc", "Toggle comment", { remap = true })
map({ "n" }, "<C-_>", "gcc", "Toggle comment", { remap = true })
map("x", "<C-/>", "gc", "Toggle comment", { remap = true })
map("x", "<C-_>", "gc", "Toggle comment", { remap = true })
map("s", "<C-/>", sel .. "gc", "Toggle comment", { remap = true })
map("s", "<C-_>", sel .. "gc", "Toggle comment", { remap = true })
map("n", "<C-`>", "<leader>ft", "Terminal", { remap = true })

-- Insert mode needs its own version. Without one, ctrl+/ falls through to
-- nvim's "unknown ctrl+key" handling and types a bare / into the buffer.
--
-- `:normal gcc` runs the same toggle, and <Cmd>-style execution returns to
-- insert afterwards -- but it leaves the cursor at column 0, so keep the
-- column and shift it by however much the comment leader grew or shrank the
-- line. The result is that ctrl+/ mid-sentence comments the line and leaves
-- you typing exactly where you were.
local function toggle_comment_in_insert()
  local pos = vim.api.nvim_win_get_cursor(0)
  local before = #vim.api.nvim_get_current_line()
  vim.cmd("normal gcc")
  local line = vim.api.nvim_get_current_line()
  local col = math.max(0, math.min(pos[2] + (#line - before), #line))
  vim.api.nvim_win_set_cursor(0, { pos[1], col })
end
map("i", "<C-/>", toggle_comment_in_insert, "Toggle comment")
map("i", "<C-_>", toggle_comment_in_insert, "Toggle comment")

-- --- 13. the pickers, on the keys other editors use them from -----------
-- These forward to LazyVim's own mappings (remap=true) rather than calling a
-- picker directly, so they keep working if the picker behind them changes.
map("n", "<C-p>", "<leader>ff", "Find file", { remap = true })
map("n", "<C-S-p>", "<leader>sC", "Command palette", { remap = true })
map("n", "<C-S-f>", "<leader>sg", "Find in files", { remap = true })
map("n", "<C-S-e>", "<leader>e", "File explorer", { remap = true })

-- Function keys, matching VS Code. gd and gr are LazyVim's LSP mappings when
-- a language server is attached, and fall back to Neovim's own definition /
-- references handling when one is not.
map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
map("n", "<F12>", "gd", "Go to definition", { remap = true })
map("n", "<S-F12>", "gr", "Find references", { remap = true })
map("n", "<F3>", "n", "Next search match")
map("n", "<S-F3>", "N", "Previous search match")
