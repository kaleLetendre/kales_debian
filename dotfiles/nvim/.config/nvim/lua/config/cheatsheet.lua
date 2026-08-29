-- config/cheatsheet.lua - the <leader>? popup.
--
-- Same shape as the i3 cheatsheet (Super+? opens CHEATSHEET.md in a floating
-- kitty window): plain markdown, readable with or without the editor, shown
-- centered in a scratch float.
--
-- Two modes:
--
--   * In an ordinary file, <leader>? shows CHEATSHEET.md -- the hand-kept
--     reference. Hand-kept because the things that are genuinely hard to
--     remember in vim are motions, text objects and : commands, none of
--     which are keymaps, so nothing could scrape them.
--
--   * In a "special" window -- the explorer, any picker, lazygit, Trouble,
--     a debug pane -- the whole reference is noise. Those windows rebind
--     nearly every letter for their own purposes, so <leader>? lists *their*
--     keys instead, read live from the buffer. Generated, so it covers
--     windows nobody has documented and can never drift.
--
-- :Cheatsheet always shows the full reference regardless of focus.

local M = {}

-- What counts as a "special" window: one whose buffer is not a file on disk.
-- `buftype` is empty for real files and set for everything else -- nofile
-- for the explorer, pickers and Trouble, terminal for lazygit, prompt for
-- input boxes. That is the actual distinction.
--
-- Counting keymaps instead does not work: a plain markdown buffer already
-- carries ~30 buffer-local maps once LSP, comments and surround attach, so
-- any threshold low enough to catch a sparse special window also catches
-- ordinary files.
local MIN_KEYMAPS = 5

-- Nicer labels for snacks' action names, which are what ends up in `desc`.
-- Anything missing falls back to humanizing the action name itself, so an
-- action added upstream tomorrow still renders sensibly.
local LABELS = {
  confirm = "Open / expand",
  explorer_close = "Collapse folder",
  explorer_close_all = "Collapse everything",
  explorer_up = "Go up a directory",
  explorer_focus = "Make this folder the root",
  explorer_add = "New file (end with / for a folder)",
  explorer_del = "DELETE from disk",
  explorer_rename = "Rename",
  explorer_copy = "Copy",
  explorer_move = "Move",
  explorer_yank = "Yank path",
  explorer_paste = "Paste",
  explorer_open = "Open in system app",
  explorer_update = "Refresh from disk",
  toggle_hidden = "Show/hide dotfiles",
  toggle_ignored = "Show/hide gitignored",
  toggle_preview = "Toggle preview",
  toggle_help_list = "Built-in help",
  toggle_focus = "Jump to the filter box",
  focus_input = "Jump to the filter box",
  cycle_win = "Cycle window (list/input/preview)",
  cancel = "Close",
  picker_grep = "Grep inside this folder",
  edit_split = "Open in a horizontal split",
  edit_vsplit = "Open in a vertical split",
  tcd = "cd here",
  terminal = "Terminal here",
  qflist = "Send to quickfix",
  print_path = "Print the path",
}

-- Keys that are just cursor movement or scrolling. True everywhere, and
-- listing twenty of them buries the handful that matter.
local NOISE = {
  list_down = true,
  list_up = true,
  list_top = true,
  list_bottom = true,
  list_scroll_up = true,
  list_scroll_down = true,
  list_scroll_top = true,
  list_scroll_bottom = true,
  list_scroll_center = true,
  preview_scroll_up = true,
  preview_scroll_down = true,
  select_and_next = true,
  select_and_prev = true,
}

local function humanize(action)
  return (action:gsub("_", " "):gsub("^%l", string.upper))
end

--- Read the focused window's own keymaps and render them as markdown.
---@param buf integer
---@return string[]
local function window_keys(buf)
  local rows = {}
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    local action = map.desc or ""
    -- Skip mouse bindings and pure navigation; neither is worth reading.
    if action ~= "" and not NOISE[action] and not map.lhs:match("Mouse") then
      rows[#rows + 1] = { lhs = map.lhs, label = LABELS[action] or humanize(action) }
    end
  end

  table.sort(rows, function(a, b)
    -- Plain letters first, then everything in <brackets>; both alphabetical.
    local a_special, b_special = a.lhs:sub(1, 1) == "<", b.lhs:sub(1, 1) == "<"
    if a_special ~= b_special then
      return b_special
    end
    return a.lhs:lower() < b.lhs:lower()
  end)

  local out = {
    "# Keys for this window",
    "",
    ("`%s` — %d keys are bound here, replacing the usual ones."):format(
      vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "scratch",
      #rows
    ),
    "",
    "| Key | Action |",
    "| --- | --- |",
  }
  for _, row in ipairs(rows) do
    out[#out + 1] = ("| `%s` | %s |"):format(row.lhs, row.label)
  end

  vim.list_extend(out, {
    "",
    "---",
    "",
    "`:Cheatsheet` shows the full reference instead of just this window.",
    "`<leader>H` opens the tutorial.",
  })
  return out
end

--- Read one of the markdown docs that sit next to init.lua.
---@param name string CHEATSHEET or TUTORIAL
---@return string[]|nil
local function doc_lines(name)
  local file = vim.fn.stdpath("config") .. "/" .. name .. ".md"
  if vim.fn.filereadable(file) == 0 then
    vim.notify("No " .. name .. ".md at " .. file, vim.log.levels.WARN)
    return nil
  end
  return vim.fn.readfile(file)
end

--- Show lines in a centered scratch float.
---@param lines string[]
---@param title string
local function float(lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false

  local width = math.min(100, math.floor(vim.o.columns * 0.9))
  local height = math.floor(vim.o.lines * 0.85)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " - q to close ",
    title_pos = "center",
  })
  -- Tables read badly when wrapped; scroll sideways instead.
  vim.wo[win].wrap = false

  -- q and Esc close it, matching every other transient window in LazyVim.
  -- nowait so q does not sit waiting for a longer mapping to disambiguate.
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true, desc = "Close cheatsheet" })
  end
end

--- Always the full document.
---@param name string|nil defaults to CHEATSHEET
function M.open(name)
  name = name or "CHEATSHEET"
  local lines = doc_lines(name)
  if lines then
    float(lines, name:lower())
  end
end

--- Whatever is relevant to the focused window.
function M.contextual()
  local buf = vim.api.nvim_get_current_buf()
  local special = vim.bo[buf].buftype ~= ""
  local count = #vim.api.nvim_buf_get_keymap(buf, "n")

  -- The keymap floor keeps this from firing on a bare scratch buffer, which
  -- is technically a nofile but has nothing worth listing.
  if special and count >= MIN_KEYMAPS then
    -- Render before opening the float, since opening it moves focus.
    float(window_keys(buf), "this window")
  else
    M.open("CHEATSHEET")
  end
end

return M
