# CONTEXT.md

Scratch/working doc for what's in flight. Not a spec — a place to pick up
cold. Once a thread is finished and captured in scripts + README, prune it
from here.

## Current focus: building up a custom terminal, one brick at a time

Goal: grow a personal interactive terminal incrementally — compose small,
well-understood primitives, add one feature ("brick") at a time, and track
every brick in this repo. The opposite of installing a batteries-included
framework and inheriting config nobody understands.

### Guiding philosophy (how to choose what to add)

These are the rules a candidate tool has to pass before it goes in:

1. **Augment the current workflow, don't replace it.** The point is making
   the commands I already type easier to find and use — not learning a new
   way to work.
2. **No tool that just adds a new set of commands to memorize.** If its
   whole value is a new verb I have to remember, it probably fails. (This
   is why zoxide's `z` was rejected — see backlog.)
3. **Only bundle things that genuinely work together.** Don't add several
   tools at once if they overlap / do the same job. Complementary, not
   redundant.

### Decisions made

- **Shell: zsh** (over bash and fish). Reason: zsh's line editor (ZLE) is
  programmable — you define a "widget" (a function bound to a key that can
  read/rewrite the command line via `$LBUFFER`/`$RBUFFER`/`$CURSOR`). That
  makes it the right foundation for hand-building interactive features.
  bash reflexes carry over unchanged at the prompt; **scripts stay bash**
  (`#!/usr/bin/env bash`) — zsh is interactive-only. Known cost: remote
  boxes won't have this setup (bash is the fallback there).
- **Fuzzy engine: fzf.** The Unix fuzzy-finder primitive (reads candidates
  on stdin, writes the pick to stdout). We compose with it and write our
  own glue widgets rather than reimplementing fuzzy matching or sourcing
  fzf's bundled key bindings.
- **No frameworks (oh-my-zsh / prezto / zinit).** They pull toward bloat
  and slow, opaque config. Hand-built rc instead.
- **zoxide is in** (reversal of the earlier rejection). The rule-2 concern
  ("no new verbs to memorize") was real but too strict: `z` is *one* verb,
  three chars, learned in a day, and once learned it kills the bulk of
  `cd ../../some/long/path` typing. Rule 1 (augment the current workflow)
  wins here — plain cd is untouched, zoxide just adds a smarter sibling.

### How it's tracked in this repo

- `setup/84-zsh.sh` — installs `zsh` + `fzf` + `zoxide`, sets zsh as the
  login shell (idempotent; chsh effective next login).
- `dotfiles/zsh/.zshrc` — lean hand-written rc. Sets history/completion/
  auto_cd, then sources `~/.zshrc.d/*.zsh` in lexical order.
- `dotfiles/zsh/.zshrc.d/NN-name.zsh` — one brick per file, numbered like
  `setup/`. Adding a feature = dropping a new file here. Stowed into $HOME.

### Status (as of 2026-05-21, on `thinkpad`)

- zsh + fzf + zoxide installed; zsh is the active login shell.
- `dotfiles/zsh` stowed (`~/.zshrc`, `~/.zshrc.d` are symlinks into repo).
- Three bricks live and verified:
  - `10-fzf-file.zsh` — **Ctrl+T** fuzzy-picks a file from the current
    dir and inserts it at the cursor (runs nothing).
  - `20-zoxide.zsh` — `z <fragment>` frecency-based directory jumps via
    `eval "$(zoxide init zsh)"`.
  - `30-prompt.zsh` — `HH:MM|~/path: ` via zsh's native `%D{%H:%M}` and
    `%~` tokens (no PROMPT_SUBST needed).
- All zsh work committed. Tag `v1` planned as the rollback point before
  i3 work begins.

## In flight: i3 as an opt-in window manager (Phase 1)

Goal: a fully keyboard-driven window-management workflow without giving
up XFCE's panel/notifications/session-manager/ulauncher/etc. xfwm4
already handles half-tile via `setup/77-window-tiling.sh`, but everything
else (move, resize, send to workspace, focus) still wants a mouse.

### Decisions made

- **i3 over staying with xfwm4 + more chords.** Worth memorizing ~15
  chords as a coherent *system* in exchange for never needing the mouse
  for windows. Closer to vimium's discoverable-pattern shape than to
  "yet another new verb to remember in isolation".
- **NOT sway.** NVIDIA pins us to X11.
- **NOT a full DE swap.** We replace only xfwm4 as the WM; the rest of
  XFCE (panel, notifications, session, ulauncher, theme, power-manager)
  survives untouched.
- **Phase 1 = low impact, opt-in toggle.** No xfconf/session changes.
  Use `i3 --replace` to swap WMs live; `xfwm4 --replace` to swap back.
  Bind a single chord — **Super+Shift+W** — on both sides to invoke a
  `/usr/local/bin/toggle-wm` script that detects which WM is running and
  replaces with the other. Logging out resets to xfwm4 by default, so
  there is no commitment.
- **Phase 2** (lightdm session picker) and **Phase 3** (i3 as default
  session) are deferred until Phase 1 has bedded in.

### How it'll be tracked in this repo

- `setup/87-i3.sh` — installs `i3` + `i3status`, drops
  `/usr/local/bin/toggle-wm`, binds Super+Shift+W in xfwm4's keyboard-
  shortcuts channel. Does NOT change the active WM or xfce4-session
  config — that's deliberate, Phase 1 stays opt-in.
- `dotfiles/i3/.config/i3/config` — hand-written, stowed in. ~15
  bindings: `Super+arrow` focus, `Super+Shift+arrow` move,
  `Super+1..9`/`Super+Shift+1..9` workspace, `Super+R` resize mode,
  `Super+F` fullscreen, `Super+space` toggle floating, `Super+D`
  ulauncher, `Super+Shift+W` → toggle-wm.

### Status (as of 2026-05-21)

- Not yet written — `v1` tag pending as the rollback point.

## Backlog: candidate next bricks

Roughly in priority order. Each still has to pass the philosophy rules above.

- **zsh-autosuggestions** — ghost text completing the line from history as
  you type; → to accept. Highest-value "find the command I forgot" piece.
  Passive, adds no new vocabulary. (The original reason for choosing zsh.)
- **zsh-syntax-highlighting** — commands turn red before you run them if
  invalid/mistyped. Complements autosuggestions, no overlap.
- **fzf on Ctrl+R** — fuzzy history search; augments a reflex I already
  have (Ctrl+R), doesn't add a verb.
- **completion tuning** — compsys is on with menu-select; refine as needed
  (descriptions, grouping, ssh-host/git-branch completion).

### Bigger idea, parked: an on-demand LLM command copilot

Separate *layer* from the local instant tools above. Local tools recall
what I've already done; this would generate commands I've *never* run from
intent + context. Sketch: a keybind running `claude -p --model
claude-haiku-4-5 "..."` (reuses Claude Code subscription auth, no API key),
gathers light context (cwd, recent history, git status), drops the
suggested command **into the buffer for review — never auto-executes**.
Complements (doesn't overlap) the history-recall tools. Caveats to respect:
explicit-trigger only (latency rules out per-keystroke), dead offline,
scope context tight on the Caracal/work box (history can carry secrets),
and never blind-accept a generated command.

### Rejected / deferred (don't re-litigate)

- **atuin** — deferred: overlaps fzf's Ctrl+R (both are history search);
  pick one, fzf is lighter (fails rule 3 if added alongside fzf).
- **tealdeer / tldr** — maybe later: it *is* a new command, but its whole
  job is recalling command usage, so it's the one new-verb tool that might
  earn its place.
- **fish** — not chosen: better out-of-box but breaks more reflexes and is
  worse for scripting than zsh.
