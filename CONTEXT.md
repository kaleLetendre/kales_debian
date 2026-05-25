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

## Done: i3 as an opt-in "Xfce with i3" login session

Goal: a fully keyboard-driven window-management workflow without giving
up XFCE's panel/notifications/ulauncher/etc. xfwm4 already handles
half-tile via `setup/77-window-tiling.sh`, but everything else (move,
resize, send to workspace, focus) still wants a mouse.

### Decisions made

- **i3 over staying with xfwm4 + more chords.** Worth memorizing ~15
  chords as a coherent *system* in exchange for never needing the mouse
  for windows. Closer to vimium's discoverable-pattern shape than to
  "yet another new verb to remember in isolation".
- **NOT sway.** NVIDIA pins us to X11.
- **NOT a full DE swap.** We replace only the window manager; the rest of
  XFCE (panel, notifications, ulauncher, theme, power-manager) survives.
- **Phase 1 (live `--replace` toggle) was abandoned — don't revisit.**
  The idea was a Super+Shift+W chord running `/usr/local/bin/toggle-wm`
  to swap xfwm4 ↔ i3 in place. It broke badly: under dual-monitor, an
  `i3 --replace` of a running XFCE session scatters adopted windows
  across per-output i3 workspaces, the panel's `_NET_WORKAREA` goes
  wrong, and swapping back leaves xfwm4 decorations/work-area corrupted.
  Mid-session WM swaps just aren't reliable on this setup.
- **Phase 2 (separate login session) shipped.** A dedicated
  "Xfce with i3" entry in LightDM. Each login is a clean start — the
  monitor layout is known at i3 startup instead of mid-swap. Round-trip
  cost is a logout/login (~5s) instead of a chord.

### Known trade-off (accepted)

The session is **pure i3** (no `xfce4-session`), so there is **no app
save/restore** on logout — terminals don't reopen. Stateful apps that
persist themselves (Vivaldi tabs, VS Code buffers) are fine. If this
becomes annoying, the heavier fix is wiring i3 *under* xfce4-session
(via `--name`), which keeps save/restore. Not done; pure-i3 first.

### How it's tracked in this repo

- `setup/87-i3.sh` — installs `i3` + `i3status` + `dex`; writes
  `/usr/local/bin/start-xfce-i3` (the session launcher) and
  `/usr/share/xsessions/xfce-i3.desktop` (the LightDM entry). Does NOT
  touch the default Xfce session.
- The launcher starts `xfsettingsd` + `xfce4-panel` explicitly, then runs
  `dex --autostart --environment XFCE` to replay every XDG autostart
  entry exactly as xfce4-session would (gnome-keyring/ssh-agent, polkit
  agent, light-locker, notifyd, clipman, blueman, nm-applet, ulauncher,
  **xcape** for tap-Super, power-manager), then `exec i3`. Using dex
  instead of a hand-list is what keeps this from silently dropping
  services — we missed xcape on the first hand-written pass.
- `dotfiles/i3/.config/i3/config` — hand-written, stowed in. Mirrors the
  XFCE app chords (Super+C/E/V/F/P), tap-Super→ulauncher (via xcape's
  synthesized Super+F12), `Super+?` → cheatsheet, `Super+Shift+E` →
  confirmed exit. No F-key bindings (flaky on the BT keyboard).
- `dotfiles/i3/.config/i3/CHEATSHEET.md` — the keybinding reference,
  opened in-session with Super+?.

### Status (as of 2026-05-22)

- Live and working on `thinkpad`. Logged into "Xfce with i3", panel +
  tray + tap-Super launcher all confirmed. Committed.

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
