# i3 keybindings — cheatsheet

All chords use **Super** (the Windows / Mod4 key) unless noted.

Open this anytime inside i3 with **Super+?** (Super+Shift+/).

## Focus + move windows

| Chord | Action |
| --- | --- |
| `Super+Arrow` | focus window in that direction |
| `Super+Shift+Arrow` | move focused window in that direction |

## Workspaces

| Chord | Action |
| --- | --- |
| `Super+1`..`9` | switch to workspace N |
| `Super+Shift+1`..`9` | send focused window to workspace N |

## Resize

Enter resize mode, then arrows resize, then `Enter`/`Esc` to exit.

| Chord | Action |
| --- | --- |
| `Super+R` | enter resize mode |
| (in mode) `Left/Right` | shrink/grow width by 10px |
| (in mode) `Up/Down` | shrink/grow height by 10px |
| (in mode) `Enter` or `Esc` | exit resize mode |

## Splits + layouts

| Chord | Action |
| --- | --- |
| `Super+H` | split horizontal (next window opens to the right) |
| `Super+Shift+V` | split vertical (next window opens below) |
| `Super+S` | stacking layout |
| `Super+T` | tabbed layout |
| `Super+Shift+F` | toggle fullscreen for focused window |
| `Super+Shift+Space` | toggle focused window floating |
| `Super+Space` | move focus between floating and tiling windows |

## Window + session actions

| Chord | Action |
| --- | --- |
| `Super+Q` | kill focused window |
| `Super+Shift+R` | restart i3 (preserves layout) |
| `Super+Shift+C` | reload i3 config |
| `Super+Shift+E` | log out — exit i3, end the X session, back to LightDM (asks to confirm) |
| `Super+Shift+S` | suspend the machine (no confirm — waking is one keypress) |
| `Super+Shift+P` | **p**ower off the machine (asks to confirm) |
| `Super+Shift+B` | re**b**oot the machine (asks to confirm; `b` because `Super+Shift+R` is taken) |

## App launches (mirrored from your XFCE bindings)

| Chord | Action |
| --- | --- |
| `Super+Enter` | open terminal (XFCE default) |
| `Super+C` | galculator |
| `Super+E` | VS Code |
| `Super+V` | Vivaldi |
| `Super+F` | Thunar (home dir) |
| `Super+P` | CopyQ clipboard history (floating, centered on focused output) |
| tap `Super` | ulauncher (via xcape; Super+F12 is the internal trigger) |
| `Super+?` | open this cheatsheet (Super+Shift+/) |

## Mouse

| Action | Result |
| --- | --- |
| `Super` + drag a floating window | move it |
| `Super` + right-drag a floating window | resize it |

## Emergency exit

If i3 wedges, drop to a TTY with **Ctrl+Alt+F2** (return with Ctrl+Alt+F7),
log in there, and run `i3-msg exit` to end the X session. LightDM comes
back and you can pick the regular "Xfce Session".
