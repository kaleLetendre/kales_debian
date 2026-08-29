# Neovim keybindings — cheatsheet

`<leader>` is **Space**. So `<leader>ff` means: press Space, then f, then f.

Open this anytime with **`<leader>?`** (or `:Cheatsheet`). `q` closes it.

## Reading the notation

Angle brackets are never typed — they're how vim writes a key that isn't a
single character.

| Written | Means |
| --- | --- |
| `<S-h>` | **S**hift+h — same keystroke as plain `H` |
| `<C-o>` | **C**trl+o |
| `<A-j>` or `<M-j>` | **A**lt+j (**M** for "meta", same key) |
| `<leader>` | Space |
| `<CR>` | Enter (carriage return) |
| `<Esc>` `<BS>` `<Tab>` | Escape, Backspace, Tab |

For letters, `<S-h>` and `H` are interchangeable and you'll see both. But
`<C-h>` is a genuinely different key from `h` — Ctrl is a separate modifier,
not a shifted letter.

## When you can't remember a key

| Key | What it does |
| --- | --- |
| `<leader>` | wait a beat — which-key lists every key that can follow, with labels |
| `<leader>sk` | fuzzy-search **every** keymap that's currently bound |
| `<leader>?` | this sheet |
| `<leader>H` | the tutorial — what to learn first, and in what order |
| `<leader>sh` | search Neovim's built-in help pages |
| `:h <thing>` | help for a specific thing, e.g. `:h text-objects` |

which-key is the one to lean on: press Space and read. This sheet is for the
things which-key can't show you — motions, text objects and `:` commands,
which aren't keymaps.

## Coming from VS Code

| VS Code | Here |
| --- | --- |
| `Ctrl+P` quick open | `<leader><space>` or `<leader>ff` |
| `Ctrl+Shift+F` find in files | `<leader>/` or `<leader>sg` |
| `Ctrl+Shift+H` replace in files | `<leader>sr` |
| `Ctrl+Shift+E` explorer | `<leader>e` |
| `Ctrl+Shift+P` command palette | `<leader>sC` (commands) — or just type `:` |
| `Ctrl+B` toggle sidebar | `<leader>e` again |
| `` Ctrl+` `` terminal | `<Ctrl-/>` |
| `F12` go to definition | `gd` |
| `Shift+F12` find references | `gr` |
| `F2` rename symbol | `<leader>cr` |
| `Ctrl+.` quick fix | `<leader>ca` |
| `Ctrl+Space` hover / docs | `K` |
| `Shift+Alt+F` format | `<leader>cf` |
| `Ctrl+Tab` switch tab | `<S-h>` / `<S-l>`, or `<leader>,` to pick |
| `Ctrl+W` close tab | `<leader>bd` |
| `Ctrl+\` split | `<leader>|` (right) / `<leader>-` (below) |
| `F5` start debugging | `<leader>dc` |
| `F9` toggle breakpoint | `<leader>db` |

## Modes

| Key | Mode |
| --- | --- |
| `Esc` or `Ctrl+[` | back to **normal** mode — where every command below works |
| `i` / `a` | **insert** before / after the cursor |
| `I` / `A` | insert at start / end of the line |
| `o` / `O` | open a new line below / above and insert |
| `v` / `V` / `Ctrl+v` | **visual** by character / line / block |
| `:` | **command** line |

If a key does something bizarre, you're probably in the wrong mode. Press `Esc`.

## Files, buffers, windows

| Key | Action |
| --- | --- |
| `<leader><space>` | find files in the project root |
| `<leader>ff` | same thing, explicitly |
| `<leader>fF` | find files under the current working dir instead |
| `<leader>fr` | recent files |
| `<leader>fc` | jump to a file in *this* nvim config |
| `<leader>fn` | new file |
| `<leader>e` / `<leader>E` | file explorer, project root / cwd — the indented tree; type in it to filter |
| `<leader>-` / `<leader>|` | split below / right |
| `Ctrl+h/j/k/l` | move to the window left/down/up/right |
| `<leader>wd` | close this window |
| `Ctrl+arrows` | resize the current window |
| `<leader>uz` | zen mode (hide everything else) |
| `:w` / `:q` / `:wq` | write / quit / both |
| `<leader>qq` | quit everything |

## Open files (the tab bar)

Everything here is under `<leader>b` — press that and read the menu if you
forget the second letter. Browsing the explorer does **not** open files; only
`Enter` does, so you can scroll the whole tree without collecting tabs.

### Moving between them

| Key | Action |
| --- | --- |
| `<S-h>` / `<S-l>` | previous / next |
| `<leader>bb` or `` <leader>` `` | flip back to the last one |
| `<leader>bj` | label every tab with a letter and jump straight to one |
| `<leader>,` or `<leader>fb` | pick from a searchable list |

### Closing them

| Key | Closes |
| --- | --- |
| `<leader>bd` | this file, keeping the window layout — the everyday one |
| `<leader>bo` | every file **except** this one — the tab-bar reset |
| `<leader>bl` / `<leader>br` | everything to the left / right of this one |
| `<leader>bi` | files not visible in any window |
| `<leader>bD` | this file **and** its window |
| `<leader>bp` | pin this file, so bulk closes skip it |
| `<leader>bP` | close everything unpinned |

Closing a file is **not** deleting it. Inside the explorer, `d` deletes from
disk — a different key for a very different thing.

## Projects + sessions

A project is just the directory you started nvim in — `cd ~/wiregraph && nvim`.
There is no "open folder". LazyVim then walks up to the nearest `.git` and
uses that as the root, so `<leader>ff` searches the whole repo regardless of
which subdirectory you launched from.

Sessions are saved automatically per directory **and per git branch**, so
switching branches gets you a different set of open files.

| Key | Action |
| --- | --- |
| `<leader>fp` | pick a project (scans `~`, `~/personal`, `~/caracal`) and load its session |
| `<leader>qs` | restore the session for this directory |
| `<leader>ql` | restore the most recent session anywhere |
| `<leader>qS` | pick from all saved sessions |
| `<leader>qd` | stop saving a session for this directory |

Two projects at once: run two terminals with one nvim each. One nvim holding
two repos fights the root detection.

## File explorer (`<leader>e`)

The sidebar tree — indented, expandable, closest thing to VS Code's explorer.
It stays open while you work, follows the file you're editing, and shows git
status and diagnostics inline. `<leader><space>` is a *fuzzy finder* over a
flat list and is a different tool: use it when you know the name, use this
when you want to see the shape.

These keys work inside the explorer window.

| Key | Action |
| --- | --- |
| `j` / `k` | move — the file under the cursor previews in the editor area |
| `l` or `Enter` | expand a folder / **actually open** the previewed file |
| `h` | collapse the folder |
| `Z` | collapse everything |
| `<BS>` | go up a directory (make the parent the new root) |
| `.` | make the folder under the cursor the new root |
| `a` | add a file — end the name with `/` to make a directory |
| `d` | delete |
| `r` | rename |
| `c` / `m` | copy / move |
| `y` / `p` | yank / paste (works on a visual selection too) |
| `H` | toggle hidden files (dotfiles) |
| `I` | toggle gitignored files |
| `P` | toggle the preview pane |
| `<leader>/` | grep inside the folder under the cursor |
| `]g` / `[g` | next / previous file with git changes |
| `]d` / `[d` | next / previous file with a diagnostic |
| `u` | refresh, if something changed on disk |
| `Esc` or `q` | close the explorer |

Typing filters the tree while keeping the nesting.

Opening a file moves your cursor into it and leaves the sidebar open. To get
back and forth: `Ctrl+h` focuses the sidebar (it's the window on the left),
`Ctrl+l` returns to the file.

## Searching

| Key | Action |
| --- | --- |
| `/` then text | search forward in this file (`?` searches backward) |
| `n` / `N` | next / previous match |
| `*` | search for the word under the cursor |
| `<leader>ur` | clear the search highlight |
| `<leader>/` or `<leader>sg` | live grep across the project |
| `<leader>sw` | grep for the word under the cursor (or the visual selection) |
| `<leader>sb` | search within this buffer |
| `<leader>sr` | search **and replace** across files (grug-far) |
| `<leader>sR` | reopen the last picker where you left it |
| `s` then two chars | flash-jump anywhere on screen |
| `:%s/old/new/g` | replace in this file (`gc` on the end to confirm each) |

## Editing

Vim edits are **operator + motion**. `d` (delete) + `w` (word) = `dw`. The same
operators take the same motions, so learning one row multiplies with the other.

| Operator | Does |
| --- | --- |
| `d` | delete (cut) |
| `c` | change — delete and drop into insert mode |
| `y` | yank (copy) |
| `p` / `P` | paste after / before |
| `gc` | toggle comment |
| `>` / `<` | indent / dedent |
| `=` | auto-indent |

| Motion | Moves to |
| --- | --- |
| `w` / `b` | start of next / previous word |
| `e` | end of word |
| `0` / `^` / `$` | start of line / first non-blank / end of line |
| `gg` / `G` | top / bottom of file |
| `{` / `}` | previous / next blank line |
| `%` | matching bracket |
| `f<char>` / `t<char>` | forward to / just before the next `<char>` on this line |
| `Ctrl+d` / `Ctrl+u` | half a page down / up |
| `Ctrl+o` / `Ctrl+i` | jump back / forward in the jump list |

**Text objects** replace the motion with a region. `i` = inner (contents),
`a` = around (contents plus delimiters).

| Object | Example |
| --- | --- |
| `iw` / `aw` | word — `daw` deletes a word and its space |
| `i"` `i'` `` i` `` | inside quotes — `ci"` replaces a string's contents |
| `i(` `i[` `i{` | inside brackets — `di{` empties a block |
| `it` / `at` | inside / around an HTML or JSX tag |
| `ip` / `ap` | paragraph |
| `if` / `af` | inside / around a function (treesitter) |

| Key | Action |
| --- | --- |
| `u` / `Ctrl+r` | undo / redo |
| `.` | repeat the last change |
| `<A-j>` / `<A-k>` | move the current line (or selection) down / up |
| `gco` / `gcO` | add a comment line below / above |
| `<leader>.` | scratch buffer — a throwaway pad that persists per project |

Counts multiply: `3dd` deletes 3 lines, `d2w` deletes 2 words, `5j` moves down 5.

## Code (LSP)

| Key | Action |
| --- | --- |
| `gd` | go to definition |
| `gD` | go to declaration |
| `gr` | find references |
| `gI` | go to implementation |
| `gy` | go to type definition |
| `K` | hover docs |
| `gK` | signature help |
| `<leader>ca` | code action (the fix-it menu) |
| `<leader>cr` | rename symbol |
| `<leader>cR` | rename the *file* and fix imports |
| `<leader>cf` | format buffer |
| `<leader>cs` | symbol outline for this file |
| `<leader>ss` | jump to a symbol by name |
| `<leader>cl` | LSP info — which servers attached to this buffer |
| `<leader>ch` | switch between source and header (C/C++) |

Completion appears as you type: `Tab` / `S-Tab` cycle, `Enter` accepts,
`Ctrl+e` dismisses.

## Diagnostics (errors + warnings)

| Key | Action |
| --- | --- |
| `<leader>cd` | show the diagnostic on this line |
| `]d` / `[d` | next / previous diagnostic |
| `]e` / `[e` | next / previous **error** |
| `]w` / `[w` | next / previous **warning** |
| `<leader>xx` | all project diagnostics in a list (Trouble) |
| `<leader>xX` | just this buffer |
| `<leader>sd` | fuzzy-search diagnostics |
| `<leader>xt` | every TODO / FIXME comment in the project |

## Git

`<leader>gg` opens lazygit, which is where most git work actually happens —
stage, commit, branch, rebase, all in its own UI (`?` inside it for its keys).

| Key | Action |
| --- | --- |
| `<leader>gg` | lazygit |
| `<leader>gb` | blame this line |
| `<leader>gf` | history of the current file |
| `<leader>gl` | git log |
| `<leader>gs` | git status picker |
| `<leader>gd` | diff hunks |
| `]h` / `[h` | next / previous changed hunk |

## Debugging

| Key | Action |
| --- | --- |
| `<leader>db` | toggle breakpoint |
| `<leader>dB` | conditional breakpoint |
| `<leader>dc` | start / continue |
| `<leader>di` | step into |
| `<leader>dO` | step over |
| `<leader>do` | step out |
| `<leader>dC` | run to cursor |
| `<leader>du` | toggle the debugger UI |
| `<leader>de` | evaluate the expression under the cursor |
| `<leader>dt` | terminate the session |

Works for Go (delve), Rust (codelldb) and C/C++ (gdb) — the setup module
installs the toolchains, the adapters install themselves on first use.

## Terminal

| Key | Action |
| --- | --- |
| `Ctrl+/` | floating terminal at the project root (same key hides it) |
| `<leader>ft` / `<leader>fT` | terminal at project root / cwd |
| `Ctrl+h/j/k/l` | leave the terminal for another window |
| `:!cmd` | run one shell command without leaving nvim |

## Toggles

All under `<leader>u`. Press `<leader>u` and read the menu; the common ones:

| Key | Toggles |
| --- | --- |
| `<leader>uf` | auto-format on save |
| `<leader>ud` | diagnostics |
| `<leader>ul` | line numbers |
| `<leader>uL` | relative line numbers |
| `<leader>uw` | line wrap |
| `<leader>us` | spell check |
| `<leader>uh` | inlay hints |
| `<leader>ub` | dark / light background |
| `<leader>uC` | pick a colorscheme |
| `<leader>un` | dismiss all notifications |

## Plugins + health

| Command | What |
| --- | --- |
| `<leader>l` or `:Lazy` | plugin manager — `U` updates, `X` cleans, `S` syncs to the lockfile |
| `<leader>cm` or `:Mason` | language servers, formatters and debug adapters |
| `:checkhealth` | what's broken and why |
| `:LazyExtras` | browse and toggle LazyVim's language/tool bundles |
| `:LazyHealth` | plugin-specific health checks |

After `:Lazy` updates anything, `lazy-lock.json` in `~/.config/nvim/` changes —
that file is inside the kales_debian repo, so commit it to keep the plugin
versions reproducible.

## Where this config lives

Everything is a symlink into the repo, so edit in place and commit:

| Path | What |
| --- | --- |
| `~/.config/nvim/lua/config/lazy.lua` | which LazyVim extras are enabled |
| `~/.config/nvim/lua/config/keymaps.lua` | your own keys |
| `~/.config/nvim/lua/config/options.lua` | editor settings |
| `~/.config/nvim/lua/plugins/` | plugin overrides — one file per concern |
| `~/.config/nvim/CHEATSHEET.md` | this file — keep it honest |
| `~/.config/nvim/TUTORIAL.md` | the learning path (`<leader>H`) |

`<leader>fc` jumps straight into any of them.

## Getting unstuck

| Situation | Fix |
| --- | --- |
| keys doing nothing sensible | `Esc` — you're in insert or visual mode |
| stuck in a weird sub-mode | `Esc` twice, then `:` should give a command line |
| "E37: No write since last change" | `:w` to save, or `:q!` to discard |
| a plugin window won't close | `q` usually; `<leader>wd` closes the window |
| completely wedged | `:qa!` force-quits everything, losing unsaved changes |
| broken after a plugin update | `:Lazy restore` rolls every plugin back to `lazy-lock.json` |
