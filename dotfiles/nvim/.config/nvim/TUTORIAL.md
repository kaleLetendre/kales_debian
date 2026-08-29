# Neovim, starting from VS Code

Open this anytime with **`<leader>H`** or `:Tutorial`. The companion
reference is `<leader>?` — that one lists *everything*. This one is the
order to learn it in.

Read this once, top to bottom. Then ignore most of it and use section 3.

---

## 0. The one idea that makes vim make sense

In VS Code, typing letters always inserts letters. In vim it doesn't,
because vim has **modes**:

- **Normal mode** — letters are *commands*. `d` deletes, `w` jumps a word.
  This is where you start, and where you spend most of your time.
- **Insert mode** — letters are letters, like every other editor.
- **Visual mode** — you're selecting.

Every confusing thing that will happen to you in week one is a mode
problem. You'll type `hello` expecting text and the file will rearrange
itself, because you were in normal mode.

**The fix is always the same: press `Esc`.** That returns you to normal
mode from anywhere. When in doubt, press it twice and start over.

`i` enters insert mode. `Esc` leaves it. That's the whole loop.

---

## 1. Your first five minutes

Do this literally, right now, in a scratch directory:

```
mkdir ~/nvim-practice
cd ~/nvim-practice
nvim hello.txt
```

You're in normal mode looking at an empty file.

| Do this | What happens |
| --- | --- |
| press `i` | bottom-left says `-- INSERT --` |
| type `hello world` | it types, like a normal editor |
| press `Esc` | back to normal mode |
| type `:w` and Enter | file saved |
| type `:q` and Enter | quit |

That's the entire survival kit: `i`, `Esc`, `:w`, `:q`. If you learn
nothing else today, you can still edit a file and get out.

One more, because you will need it: `:q!` quits and **throws away**
unsaved changes. That's your escape hatch when a file is in a state you
don't understand.

---

## 2. Projects — the LazyVim "root dir" idea

There is no "Open Folder". You `cd` to a directory and run `nvim`:

```
cd ~/wiregraph
nvim
```

But that's only half the story, and the other half is the thing that makes
LazyVim confusing until someone explains it.

### Two different directories, always

LazyVim tracks **two** locations at once, and every search command comes in
both flavors:

- **cwd** — the directory you launched nvim from. Normal shell stuff.
- **root dir** — LazyVim's guess at which *project* the current file
  belongs to.

That's why the menus look redundant:

| Key | Searches |
| --- | --- |
| `<leader>ff` | Find Files (**Root Dir**) |
| `<leader>fF` | Find Files (**cwd**) |
| `<leader>sg` | Grep (**Root Dir**) |
| `<leader>sG` | Grep (**cwd**) |

Lowercase is the project. Uppercase is literally where you are. Ninety
percent of the time you want lowercase and never think about it.

### How it guesses

`vim.g.root_spec = { "lsp", { ".git", "lua" }, "cwd" }` — in order:

1. Ask the language server what it considers the workspace root.
2. Failing that, walk up from the current file until a `.git` or `lua`
   directory appears.
3. Failing that, use the cwd.

**Run `:LazyRoot` to see what it picked and why.** It prints the candidates
as a checklist with the winner ticked. When a search returns results from
the wrong project, that's the command that tells you what happened.

### The part that surprises people

The root is computed **per file**, not per session. Open a file from a
different repo and the root changes for that buffer, while your cwd stays
put:

```
cwd:  /home/kl/kales_debian     (unchanged)
root: /home/kl/wiregraph        (follows the file you're looking at)
```

So `<leader>ff` after opening that file searches wiregraph, not the repo you
started in. That's usually what you want, but it looks like a bug the first
time it happens.

### Getting between projects

| Where | Key |
| --- | --- |
| start screen (bare `nvim`) | `p` — Projects |
| anywhere | `<leader>fp` |

It scans `~`, `~/personal` and `~/caracal` for directories containing a
`.git`. Picking one loads that project's saved session, so it's the closest
thing to VS Code's Recent Folders.

### Sessions

When you quit, nvim saves which files and splits you had open — per
directory **and per git branch**. Next time you `cd` there and run `nvim`,
press `<leader>qs` to restore it, or `s` on the start screen. Switching
branches gets you a different session, which is usually what you want.

### Two projects at once

Don't. Run two terminals, one nvim in each. One nvim holding two repos means
the root keeps changing under you every time you switch buffers.

---

## 3. Week one: eight keys

Ignore everything else in the cheatsheet until these are automatic. This
is the entire list.

| Key | Does |
| --- | --- |
| `<leader>ff` | find a file by name (your `Ctrl+P`) |
| `<leader>/` | search text across the project (your `Ctrl+Shift+F`) |
| `<leader>e` | toggle the file tree sidebar |
| `<S-h>` / `<S-l>` | previous / next open file |
| `<leader>bd` | close the current file |
| `i` / `Esc` | enter / leave insert mode |
| `:w` | save |
| `<leader>qq` | quit everything |

`<leader>` is the **Space** bar. So `<leader>ff` is: Space, f, f.

Use arrow keys to move around. Yes, `hjkl` is the vim way, and yes you'll
switch eventually. Not this week — you have enough to think about.

---

## 4. LazyVim's keys are guessable

Every leader key is filed under a letter that stands for a category. You
don't memorize keys, you memorize **nine letters** and then let the menu
show you the rest.

| Press | Group |
| --- | --- |
| `<leader>f` | **f**ile / find |
| `<leader>s` | **s**earch |
| `<leader>g` | **g**it |
| `<leader>c` | **c**ode (LSP: rename, format, actions) |
| `<leader>b` | **b**uffers (open files) |
| `<leader>w` | **w**indows (splits) |
| `<leader>x` | diagnostics / quickfi**x** |
| `<leader>u` | **u**i toggles (wrap, spell, format-on-save) |
| `<leader>q` | **q**uit / session |
| `<leader>d` | **d**ebug |

So "I want to find a file" is `<leader>f` and then read the menu. "I want to
change something about how the UI looks" is `<leader>u` and then read. You
almost never need to know the second letter in advance.

Two more that aren't leader keys but follow the same idea:

- `g` is **goto** — `gd` definition, `gr` references, `gg` top of file.
- `]` and `[` are **next** and **previous** — `]d` next diagnostic, `]b`
  next buffer, `]h` next git hunk. Same letter, opposite directions.

---

## 5. You do not have to remember any of this

This is the part that matters most, so it gets its own section.

**Press Space and wait.** A menu appears listing every key that can come
next, with a plain-English label for each. Press `f` and it shows you
everything under `f`. You can navigate the entire editor this way without
knowing a single shortcut in advance.

That's a plugin called which-key, and it's why this setup is survivable.

Three more escape hatches:

| Key | For when |
| --- | --- |
| Space, then wait | "what can I press right now?" |
| `<leader>sk` | "I half-remember a command" — fuzzy-search every keybinding |
| `<leader>?` | the full cheatsheet, organized by topic |

If you find yourself trying to *recall* a shortcut, stop and press Space
instead. That habit is worth more than memorizing the list.

---

## 6. Week two: how editing actually works

Once files and navigation are automatic, learn this — it's the thing that
makes vim worth the trouble.

Vim commands are a little grammar: **verb + noun.**

Verbs: `d` delete, `c` change (delete then insert), `y` yank (copy).

Nouns are movements: `w` a word, `$` to end of line, `}` to the next blank
line.

They combine freely:

| Command | Reads as |
| --- | --- |
| `dw` | delete word |
| `d$` | delete to end of line |
| `cw` | change word |
| `dd` | delete whole line (doubling the verb = the whole line) |
| `3dd` | delete 3 lines |

Then there's a second kind of noun, **text objects**, which are what you'll
actually use all day. `i` means "inner":

| Command | Does |
| --- | --- |
| `ci"` | change everything inside the quotes |
| `ci(` | change everything inside the parens |
| `di{` | delete the contents of the block |
| `caw` | change a word *and* its trailing space |

Put your cursor anywhere inside a string and press `ci"`. The string
empties and you're in insert mode. That's the moment vim starts to feel
worth it.

Two more that pay for themselves immediately:

- `u` undoes. `Ctrl+r` redoes.
- `.` repeats your last change. Make an edit, move somewhere else, press
  `.` — it happens again.

---

## 7. Week three: the IDE parts

These work the same as VS Code, just different keys. Learn them when you
need them, not before.

| Key | VS Code equivalent |
| --- | --- |
| `gd` | F12, go to definition |
| `gr` | Shift+F12, find references |
| `K` | hover for docs |
| `<leader>ca` | Ctrl+. quick fix |
| `<leader>cr` | F2 rename symbol |
| `]d` / `[d` | next / previous error |
| `<leader>gg` | full git UI (lazygit) |
| `<C-/>` | terminal |

`<leader>gg` deserves its own note: it opens lazygit, a proper git
interface. Stage hunks, write commits, browse branches, rebase. Press `?`
inside it for its own keys. Most people end up doing all their git work
there.

---

## 8. Changing things

LazyVim is a config *on top of* Neovim, and yours is a thin config on top of
LazyVim. Three layers, and you only ever edit the thin one.

| Command | What it manages |
| --- | --- |
| `:Lazy` (or `<leader>l`) | plugins. `U` updates, `S` syncs to the lockfile, `X` removes unused |
| `:LazyExtras` | LazyVim's language packs — a whole toolchain per language, toggled with `x` |
| `:Mason` (or `<leader>cm`) | the language servers, formatters and debuggers themselves |

`:LazyExtras` is the one worth knowing. Want Python? Open it, find
`lang.python`, press `x`, restart. That installs the language server, the
formatter, the linter, the debugger and the treesitter parser as a set. Go,
Rust and C are already enabled that way.

Your own config lives in the repo and is symlinked into place, so editing it
is a normal git-tracked change:

| File | For |
| --- | --- |
| `lua/config/lazy.lua` | which extras are on |
| `lua/config/keymaps.lua` | your own keybindings |
| `lua/config/options.lua` | editor settings |
| `lua/plugins/overrides.lua` | changing how a plugin behaves |

`<leader>fc` jumps straight into any of them.

One warning: after `:Lazy` updates plugins, `lazy-lock.json` changes. That
file pins every plugin to an exact version and lives in the kales_debian
repo — commit it, and any other machine gets the identical setup. If an
update breaks something, `:Lazy restore` rolls everything back to it.

---

## 9. Things that will scare you

| What you see | What happened | Fix |
| --- | --- | --- |
| typing rearranges the file | you're in normal mode | `Esc`, then `u` a few times to undo |
| `E37: No write since last change` | you tried to quit with unsaved edits | `:w` to save, or `:q!` to discard |
| stuck in something with no obvious exit | a plugin window or a partial command | `Esc`, then `q` |
| a file opened read-only or blank | you opened a directory or a swap file exists | `:q` and try again |
| everything is frozen | you pressed `Ctrl+s` (old terminal flow control) | `Ctrl+q` unfreezes it |
| genuinely wedged | — | `:qa!` force-quits, losing unsaved work |

---

## 10. You can still use VS Code

It's still installed and `Super+E` still opens it. Nothing here is a
one-way door.

The honest version: you will be slower for about two weeks. That's not a
sign it isn't working, it's the cost. The useful test isn't "is this
faster yet" — it's "when I reach for a key, does my hand know it." When
that starts happening for the eight keys in section 3, add more.

A reasonable pace: week one, use nvim only for quick edits and config
files. Week two, one real feature. Week three, default to it and fall
back to VS Code when you're in a hurry.

---

## Where to go next

- `<leader>?` — the cheatsheet, every key organized by topic
- `:Tutorial` — this file
- `:checkhealth` — what's broken, if something feels off
- `:h <topic>` — vim's own docs, e.g. `:h text-objects`
- `vimtutor` in a terminal — the classic 30-minute hands-on drill, and
  genuinely the fastest way to get the motions into your fingers
